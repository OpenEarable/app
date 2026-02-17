import 'package:flutter/material.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart';
import 'rgb_control.dart';

// MARK: - Status LED Widget
class StatusLEDControlWidget extends StatefulWidget {
  final StatusLed statusLED;
  final RgbLed rgbLed;
  const StatusLEDControlWidget({
    super.key,
    required this.statusLED,
    required this.rgbLed,
  });

  @override
  State<StatusLEDControlWidget> createState() => _StatusLEDControlWidgetState();
}

class _StatusLEDControlWidgetState extends State<StatusLEDControlWidget> {
  bool _overrideColor = false;
  bool _disableLed = false;

  Future<void> _setLedBlack() async {
    try {
      await widget.statusLED.showStatus(false);
      await widget.rgbLed.writeLedColor(r: 0, g: 0, b: 0);
    } catch (_) {
      // LED control is best-effort and should not interrupt UI interactions.
    }
  }

  Future<void> _resetLedOverride() async {
    try {
      await widget.statusLED.showStatus(true);
    } catch (_) {
      // LED control is best-effort and should not interrupt UI interactions.
    }
  }

  Future<void> _onDisableLedChanged(bool value) async {
    setState(() {
      _disableLed = value;
      if (value) {
        _overrideColor = false;
      }
    });

    if (value) {
      await _setLedBlack();
      return;
    }
    await _resetLedOverride();
  }

  Future<void> _onOverrideChanged(bool value) async {
    setState(() {
      _overrideColor = value;
      if (value) {
        _disableLed = false;
      }
    });

    if (value) {
      try {
        await widget.statusLED.showStatus(false);
      } catch (_) {
        // LED control is best-effort and should not interrupt UI interactions.
      }
      return;
    }

    await _resetLedOverride();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Disable LED',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Turn off LED output.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Switch.adaptive(
              value: _disableLed,
              onChanged: _onDisableLedChanged,
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Override status LED color',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Use a fixed color instead of the default status.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Switch.adaptive(
              value: _overrideColor,
              onChanged: _onOverrideChanged,
            ),
          ],
        ),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 170),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          child: _overrideColor
              ? Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest.withValues(
                        alpha: 0.35,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: colorScheme.outlineVariant.withValues(
                          alpha: 0.55,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'LED Color',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        RgbControlView(rgbLed: widget.rgbLed),
                      ],
                    ),
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}
