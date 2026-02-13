import 'package:flutter/material.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart';
import 'package:open_wearable/view_models/wearables_provider.dart';
import 'package:provider/provider.dart';

class AudioModeWidget extends StatefulWidget {
  final Wearable device;

  const AudioModeWidget({
    super.key,
    required this.device,
  });

  @override
  State<AudioModeWidget> createState() => _AudioModeWidgetState();
}

class _AudioModeWidgetState extends State<AudioModeWidget> {
  AudioMode? _selectedAudioMode;
  AudioModeManager? _pairedAudioModeManager;
  Wearable? _pairedWearable;
  bool _isLoading = true;
  bool _isApplying = false;
  bool _applyToStereoPair = false;
  String? _errorText;

  AudioModeManager get _audioModeManager =>
      widget.device.requireCapability<AudioModeManager>();

  @override
  void initState() {
    super.initState();
    _loadState();
  }

  @override
  void didUpdateWidget(covariant AudioModeWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.device != widget.device) {
      _loadState();
    }
  }

  Future<void> _loadState() async {
    setState(() {
      _isLoading = true;
      _isApplying = false;
      _errorText = null;
    });

    final wearables = context.read<WearablesProvider>().wearables;

    try {
      final selectedMode = await _audioModeManager.getAudioMode();
      final pairedWearable = await _findPairedWearable(wearables: wearables);

      AudioModeManager? pairedAudioModeManager;
      if (pairedWearable != null &&
          pairedWearable.hasCapability<AudioModeManager>()) {
        pairedAudioModeManager =
            pairedWearable.requireCapability<AudioModeManager>();
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _selectedAudioMode = selectedMode;
        _pairedWearable = pairedWearable;
        _pairedAudioModeManager = pairedAudioModeManager;
        _applyToStereoPair = pairedAudioModeManager != null;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorText = 'Failed to load listening mode: ${_describeError(error)}';
        _isLoading = false;
      });
    }
  }

  Future<Wearable?> _findPairedWearable({
    required List<Wearable> wearables,
  }) async {
    if (!widget.device.hasCapability<StereoDevice>()) {
      return null;
    }

    final pairedStereo =
        await widget.device.requireCapability<StereoDevice>().pairedDevice;
    if (pairedStereo == null) {
      return null;
    }

    for (final candidate in wearables) {
      if (candidate.deviceId == widget.device.deviceId) {
        continue;
      }
      if (!candidate.hasCapability<StereoDevice>()) {
        continue;
      }
      if (identical(
        candidate.requireCapability<StereoDevice>(),
        pairedStereo,
      )) {
        return candidate;
      }
    }

    return null;
  }

  Future<void> _onModeSelected(AudioMode mode) async {
    if (_isApplying) {
      return;
    }

    final previousMode = _selectedAudioMode;
    final pairedManager = _applyToStereoPair ? _pairedAudioModeManager : null;

    setState(() {
      _selectedAudioMode = mode;
      _isApplying = true;
      _errorText = null;
    });

    bool primaryApplied = false;
    try {
      await Future.sync(() => _audioModeManager.setAudioMode(mode));
      primaryApplied = true;

      if (pairedManager != null) {
        if (!pairedManager.availableAudioModes.contains(mode)) {
          throw StateError(
            'Paired device does not support ${_labelForMode(mode)}.',
          );
        }
        await Future.sync(() => pairedManager.setAudioMode(mode));
      }
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        if (!primaryApplied || pairedManager == null) {
          _selectedAudioMode = previousMode;
        }
        _errorText = _buildApplyError(
          error: error,
          primaryApplied: primaryApplied,
          appliedToPair: pairedManager != null,
        );
      });
    } finally {
      if (mounted) {
        setState(() {
          _isApplying = false;
        });
      }
    }
  }

  String _buildApplyError({
    required Object error,
    required bool primaryApplied,
    required bool appliedToPair,
  }) {
    final detail = _describeError(error);
    if (primaryApplied && appliedToPair) {
      return 'Applied to this device, but failed on paired device: $detail';
    }
    return 'Failed to apply listening mode: $detail';
  }

  String _labelForMode(AudioMode mode) {
    final normalized = _normalizedModeKey(mode);
    if (normalized.contains('noise') || normalized.contains('anc')) {
      return 'Noise Cancellation';
    }
    if (normalized.contains('transparen') ||
        normalized.contains('ambient') ||
        normalized.contains('passthrough')) {
      return 'Transparency';
    }
    if (normalized.contains('normal') ||
        normalized.contains('off') ||
        normalized.contains('default')) {
      return 'Normal';
    }
    return _toTitleCase(mode.key);
  }

  String _subtitleForMode(AudioMode mode) {
    final normalized = _normalizedModeKey(mode);
    if (normalized.contains('noise') || normalized.contains('anc')) {
      return 'Reduce background sound';
    }
    if (normalized.contains('transparen') ||
        normalized.contains('ambient') ||
        normalized.contains('passthrough')) {
      return 'Let surrounding sound in';
    }
    if (normalized.contains('normal') ||
        normalized.contains('off') ||
        normalized.contains('default')) {
      return 'Balanced everyday listening';
    }
    return 'Custom listening profile';
  }

  IconData _iconForMode(AudioMode mode) {
    final normalized = _normalizedModeKey(mode);
    if (normalized.contains('noise') || normalized.contains('anc')) {
      return Icons.volume_off_rounded;
    }
    if (normalized.contains('transparen') ||
        normalized.contains('ambient') ||
        normalized.contains('passthrough')) {
      return Icons.hearing_rounded;
    }
    if (normalized.contains('normal') ||
        normalized.contains('off') ||
        normalized.contains('default')) {
      return Icons.equalizer_rounded;
    }
    return Icons.graphic_eq_rounded;
  }

  String _normalizedModeKey(AudioMode mode) {
    return mode.key.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  String _toTitleCase(String value) {
    final spaced = value
        .replaceAllMapped(
          RegExp(r'([a-z])([A-Z])'),
          (match) => '${match.group(1)} ${match.group(2)}',
        )
        .replaceAll(RegExp(r'[_-]+'), ' ')
        .trim();

    if (spaced.isEmpty) {
      return value;
    }

    return spaced.split(RegExp(r'\s+')).map((word) {
      if (word.isEmpty) {
        return word;
      }
      if (word.length == 1) {
        return word.toUpperCase();
      }
      return '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}';
    }).join(' ');
  }

  String _describeError(Object error) {
    final text = error.toString().trim();
    if (text.startsWith('Exception: ')) {
      return text.substring('Exception: '.length);
    }
    if (text.startsWith('StateError: ')) {
      return text.substring('StateError: '.length);
    }
    return text;
  }

  Widget _buildModeOptions(List<AudioMode> modes) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 8.0;
        final columns = constraints.maxWidth >= 520 ? 3 : 1;
        final itemWidth = columns == 1
            ? constraints.maxWidth
            : (constraints.maxWidth - (spacing * (columns - 1))) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: modes.map((mode) {
            final selected = _selectedAudioMode == mode;

            return SizedBox(
              width: itemWidth,
              child: _AudioModeOptionButton(
                label: _labelForMode(mode),
                subtitle: _subtitleForMode(mode),
                icon: _iconForMode(mode),
                selected: selected,
                enabled: !_isApplying,
                onTap: () => _onModeSelected(mode),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final modes = _audioModeManager.availableAudioModes.toList();
    if (modes.isEmpty) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final pairName = _pairedWearable?.name;

    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Listening Mode',
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: 6),
          Text(
            'Select how each earable handles surrounding sound.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (_pairedAudioModeManager != null) ...[
            const SizedBox(height: 4),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              dense: true,
              value: _applyToStereoPair,
              onChanged: _isApplying
                  ? null
                  : (value) {
                      setState(() {
                        _applyToStereoPair = value;
                      });
                    },
              title: const Text('Apply to stereo pair'),
              subtitle: Text(
                _applyToStereoPair
                    ? pairName == null
                        ? 'Left and right devices change together.'
                        : 'Also update $pairName.'
                    : 'Only update this device.',
              ),
            ),
          ],
          const SizedBox(height: 6),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            _buildModeOptions(modes),
          if (_isApplying) ...[
            const SizedBox(height: 8),
            const LinearProgressIndicator(minHeight: 2),
          ],
          if (_errorText != null) ...[
            const SizedBox(height: 8),
            Text(
              _errorText!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AudioModeOptionButton extends StatelessWidget {
  final String label;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  const _AudioModeOptionButton({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final foregroundColor =
        selected ? colorScheme.primary : colorScheme.onSurfaceVariant;
    final iconColor =
        enabled ? foregroundColor : foregroundColor.withValues(alpha: 0.55);
    final titleColor = enabled
        ? (selected ? colorScheme.primary : colorScheme.onSurface)
        : colorScheme.onSurface.withValues(alpha: 0.55);
    final subtitleColor = enabled
        ? colorScheme.onSurfaceVariant
        : colorScheme.onSurfaceVariant.withValues(alpha: 0.55);

    final backgroundColor = selected
        ? colorScheme.primaryContainer.withValues(alpha: 0.44)
        : colorScheme.surface;
    final borderColor = selected
        ? colorScheme.primary.withValues(alpha: 0.7)
        : colorScheme.outlineVariant.withValues(alpha: 0.7);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: enabled ? onTap : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 18,
                color: iconColor,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: titleColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: subtitleColor,
                      ),
                    ),
                  ],
                ),
              ),
              if (selected)
                Icon(
                  Icons.check_circle_rounded,
                  size: 18,
                  color: colorScheme.primary,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
