import 'package:flutter/material.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart';
import 'package:open_wearable/view_models/wearables_provider.dart';
import 'package:provider/provider.dart';

enum AudioModeApplyScope {
  userSelectable,
  individualOnly,
  pairOnly,
}

class AudioModeWidget extends StatefulWidget {
  final Wearable device;
  final AudioModeApplyScope applyScope;

  const AudioModeWidget({
    super.key,
    required this.device,
    this.applyScope = AudioModeApplyScope.userSelectable,
  });

  @override
  State<AudioModeWidget> createState() => _AudioModeWidgetState();
}

class _AudioModeWidgetState extends State<AudioModeWidget> {
  AudioMode? _selectedAudioMode;
  AudioMode? _primaryAudioMode;
  AudioMode? _pairedAudioMode;
  AudioModeManager? _pairedAudioModeManager;
  Wearable? _pairedWearable;
  String _primarySideLabel = 'This device';
  String _pairedSideLabel = 'Paired device';
  bool _pairModesDiffer = false;
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
      AudioMode? pairedMode;
      if (pairedWearable != null &&
          pairedWearable.hasCapability<AudioModeManager>()) {
        pairedAudioModeManager =
            pairedWearable.requireCapability<AudioModeManager>();
        pairedMode = await pairedAudioModeManager.getAudioMode();
      }
      final positions = await Future.wait<DevicePosition?>([
        _readStereoPosition(widget.device),
        if (pairedWearable != null) _readStereoPosition(pairedWearable),
      ]);
      final primaryPosition = positions.isNotEmpty ? positions.first : null;
      final pairedPosition = positions.length > 1 ? positions[1] : null;

      final primarySideLabel = _sideLabelForPosition(
        primaryPosition,
        fallback: 'This device',
      );
      final pairedSideLabel = _sideLabelForPosition(
        pairedPosition,
        fallback: 'Paired device',
      );

      final pairModesDiffer =
          pairedMode != null && !_modesEqualByKey(selectedMode, pairedMode);

      if (!mounted) {
        return;
      }

      setState(() {
        _selectedAudioMode =
            pairModesDiffer && widget.applyScope == AudioModeApplyScope.pairOnly
                ? null
                : selectedMode;
        _primaryAudioMode = selectedMode;
        _pairedAudioMode = pairedMode;
        _pairedWearable = pairedWearable;
        _pairedAudioModeManager = pairedAudioModeManager;
        _primarySideLabel = primarySideLabel;
        _pairedSideLabel = pairedSideLabel;
        _pairModesDiffer = pairModesDiffer;
        _applyToStereoPair = switch (widget.applyScope) {
          AudioModeApplyScope.pairOnly => pairedAudioModeManager != null,
          AudioModeApplyScope.individualOnly => false,
          AudioModeApplyScope.userSelectable => pairedAudioModeManager != null,
        };
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

  Future<DevicePosition?> _readStereoPosition(Wearable wearable) async {
    if (!wearable.hasCapability<StereoDevice>()) {
      return null;
    }
    try {
      return await wearable.requireCapability<StereoDevice>().position;
    } catch (_) {
      return null;
    }
  }

  Future<void> _onModeSelected(AudioMode mode) async {
    if (_isApplying || _isLoading) {
      return;
    }

    final previousMode = _selectedAudioMode;
    final previousPrimaryMode = _primaryAudioMode;
    final previousPairedMode = _pairedAudioMode;
    final previousPairModesDiffer = _pairModesDiffer;
    final shouldApplyToPair = switch (widget.applyScope) {
      AudioModeApplyScope.pairOnly => true,
      AudioModeApplyScope.individualOnly => false,
      AudioModeApplyScope.userSelectable => _applyToStereoPair,
    };
    final pairedManager = shouldApplyToPair ? _pairedAudioModeManager : null;

    setState(() {
      _selectedAudioMode = mode;
      _primaryAudioMode = mode;
      if (pairedManager != null) {
        _pairedAudioMode = mode;
      }
      _pairModesDiffer = false;
      _isApplying = true;
      _errorText = null;
    });

    bool primaryApplied = false;
    try {
      await Future.sync(() => _audioModeManager.setAudioMode(mode));
      primaryApplied = true;

      if (pairedManager != null) {
        if (!_audioModeManagerSupportsMode(pairedManager, mode)) {
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
          _primaryAudioMode = previousPrimaryMode;
          _pairedAudioMode = previousPairedMode;
          _pairModesDiffer = previousPairModesDiffer;
        } else if (widget.applyScope == AudioModeApplyScope.pairOnly) {
          _selectedAudioMode = null;
          _primaryAudioMode = mode;
          _pairedAudioMode = previousPairedMode;
          _pairModesDiffer = true;
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

  bool _modesEqualByKey(AudioMode? a, AudioMode? b) {
    if (a == null || b == null) {
      return false;
    }
    return _normalizedModeKey(a) == _normalizedModeKey(b);
  }

  bool _audioModeManagerSupportsMode(AudioModeManager manager, AudioMode mode) {
    return manager.availableAudioModes.any(
      (candidate) => _modesEqualByKey(candidate, mode),
    );
  }

  String _sideLabelForPosition(
    DevicePosition? position, {
    required String fallback,
  }) {
    return switch (position) {
      DevicePosition.left => 'Left',
      DevicePosition.right => 'Right',
      _ => fallback,
    };
  }

  String _buildPairMismatchMessage() {
    final primary = _primaryAudioMode;
    final paired = _pairedAudioMode;
    if (primary == null || paired == null) {
      return 'Left and right modes differ. Select one mode to sync both.';
    }
    return '$_primarySideLabel: ${_labelForMode(primary)}. '
        '$_pairedSideLabel: ${_labelForMode(paired)}. '
        'Select one mode to sync both.';
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
      return 'Standard';
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
      return 'No noise cancellation or transparency';
    }
    return 'Custom listening profile';
  }

  bool _isNoiseCancellationMode(AudioMode mode) {
    final normalized = _normalizedModeKey(mode);
    return normalized.contains('noise') || normalized.contains('anc');
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
            final selected = _selectedAudioMode != null &&
                _modesEqualByKey(_selectedAudioMode, mode);

            return SizedBox(
              width: itemWidth,
              child: _AudioModeOptionButton(
                label: _labelForMode(mode),
                subtitle: _subtitleForMode(mode),
                badgeText: _isNoiseCancellationMode(mode) ? 'BETA' : null,
                icon: _iconForMode(mode),
                selected: selected,
                enabled: !_isApplying && !_isLoading,
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
          Row(
            children: [
              Expanded(
                child: Text(
                  'Listening Mode',
                  style: theme.textTheme.titleSmall,
                ),
              ),
              if (_isLoading)
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: theme.colorScheme.primary,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Choose how much surrounding sound to let in.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          if (_pairedAudioModeManager != null &&
              widget.applyScope == AudioModeApplyScope.userSelectable) ...[
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              dense: true,
              value: _applyToStereoPair,
              onChanged: _isApplying || _isLoading
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
          ] else if (_pairedAudioModeManager != null &&
              widget.applyScope == AudioModeApplyScope.pairOnly) ...[
            const SizedBox(height: 4),
            Text(
              'Applied to both paired devices.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (_pairModesDiffer &&
                _primaryAudioMode != null &&
                _pairedAudioMode != null) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer.withValues(
                    alpha: 0.35,
                  ),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: theme.colorScheme.error.withValues(alpha: 0.45),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      size: 18,
                      color: theme.colorScheme.error,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _buildPairMismatchMessage(),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
          const SizedBox(height: 6),
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
  final String? badgeText;
  final IconData icon;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  const _AudioModeOptionButton({
    required this.label,
    required this.subtitle,
    this.badgeText,
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
                    Row(
                      children: [
                        Flexible(
                          fit: FlexFit.loose,
                          child: Text(
                            label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: titleColor,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (badgeText != null) ...[
                          const SizedBox(width: 6),
                          _ModePillBadge(label: badgeText!),
                        ],
                      ],
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
              const SizedBox(width: 8),
              SizedBox(
                width: 18,
                height: 18,
                child: selected
                    ? Icon(
                        Icons.check_circle_rounded,
                        size: 18,
                        color: colorScheme.primary,
                      )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModePillBadge extends StatelessWidget {
  final String label;

  const _ModePillBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: colorScheme.secondary.withValues(alpha: 0.6),
        ),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: colorScheme.onSecondaryContainer,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}
