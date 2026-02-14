import 'package:flutter/material.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart';

class MicrophoneSelectionWidget extends StatefulWidget {
  final MicrophoneManager device;

  const MicrophoneSelectionWidget({
    super.key,
    required this.device,
  });

  @override
  State<MicrophoneSelectionWidget> createState() =>
      _MicrophoneSelectionWidgetState();
}

class _MicrophoneSelectionWidgetState extends State<MicrophoneSelectionWidget> {
  Microphone? _selectedMicrophone;
  bool _isLoading = true;
  bool _isApplying = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _loadSelectedMicrophone();
  }

  @override
  void didUpdateWidget(covariant MicrophoneSelectionWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.device != widget.device) {
      _loadSelectedMicrophone();
    }
  }

  Future<void> _loadSelectedMicrophone() async {
    setState(() {
      _isLoading = true;
      _isApplying = false;
      _errorText = null;
    });

    try {
      final microphone = await widget.device.getMicrophone();
      if (!mounted) {
        return;
      }
      setState(() {
        _selectedMicrophone = microphone;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorText =
            'Failed to read LE Audio stream source: ${_describeError(error)}';
        _isLoading = false;
      });
    }
  }

  Future<void> _onMicrophoneSelected(Microphone microphone) async {
    if (_isApplying || _isLoading) {
      return;
    }

    final previousMicrophone = _selectedMicrophone;
    setState(() {
      _selectedMicrophone = microphone;
      _isApplying = true;
      _errorText = null;
    });

    try {
      await Future.sync(() => widget.device.setMicrophone(microphone));
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _selectedMicrophone = previousMicrophone;
        _errorText =
            'Failed to apply LE Audio stream source: ${_describeError(error)}';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isApplying = false;
        });
      }
    }
  }

  String _normalizedMicrophoneKey(Microphone microphone) {
    return microphone.key.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  bool _microphonesEqualByKey(Microphone? a, Microphone b) {
    if (a == null) {
      return false;
    }
    return _normalizedMicrophoneKey(a) == _normalizedMicrophoneKey(b);
  }

  String _labelForMicrophone(Microphone microphone) {
    final normalized = _normalizedMicrophoneKey(microphone);
    if (normalized.contains('inner') || normalized.contains('internal')) {
      return 'Inner';
    }
    if (normalized.contains('outer') || normalized.contains('external')) {
      return 'Outer';
    }
    return _toTitleCase(microphone.key);
  }

  String _subtitleForMicrophone(Microphone microphone) {
    final normalized = _normalizedMicrophoneKey(microphone);
    if (normalized.contains('inner') || normalized.contains('internal')) {
      return 'Stream the inner mic over LE Audio';
    }
    if (normalized.contains('outer') || normalized.contains('external')) {
      return 'Stream the outer mic over LE Audio';
    }
    return 'Microphone source for LE Audio stream';
  }

  IconData _iconForMicrophone(Microphone microphone) {
    final normalized = _normalizedMicrophoneKey(microphone);
    if (normalized.contains('inner') || normalized.contains('internal')) {
      return Icons.hearing_rounded;
    }
    if (normalized.contains('outer') || normalized.contains('external')) {
      return Icons.surround_sound_rounded;
    }
    return Icons.mic_rounded;
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
    return text;
  }

  Widget _buildMicrophoneOptions(List<Microphone> microphones) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 8.0;
        final columns = constraints.maxWidth >= 420 ? 2 : 1;
        final itemWidth = columns == 1
            ? constraints.maxWidth
            : (constraints.maxWidth - spacing) / 2;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: microphones.map((microphone) {
            final selected = _microphonesEqualByKey(
              _selectedMicrophone,
              microphone,
            );
            return SizedBox(
              width: itemWidth,
              child: _MicrophoneOptionButton(
                label: _labelForMicrophone(microphone),
                subtitle: _subtitleForMicrophone(microphone),
                icon: _iconForMicrophone(microphone),
                selected: selected,
                enabled: !_isApplying && !_isLoading,
                onTap: () => _onMicrophoneSelected(microphone),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final microphones = widget.device.availableMicrophones.toList();
    if (microphones.isEmpty) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'LE Audio Microphone Stream',
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
            'Choose which microphone is streamed via LE Audio.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 6),
          _buildMicrophoneOptions(microphones),
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

class _MicrophoneOptionButton extends StatelessWidget {
  final String label;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  const _MicrophoneOptionButton({
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
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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
