import 'package:flutter/material.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart';
import 'rgb_control.dart';

// MARK: - Status LED Widget
class StatusLEDControlWidget extends StatefulWidget {
  final StatusLed statusLED;
  final RgbLed rgbLed;
  final LedStateReader? stateReader;
  const StatusLEDControlWidget({
    super.key,
    required this.statusLED,
    required this.rgbLed,
    this.stateReader,
  });

  @override
  State<StatusLEDControlWidget> createState() => _StatusLEDControlWidgetState();
}

class _StatusLEDControlWidgetState extends State<StatusLEDControlWidget> {
  bool _overrideColor = false;
  bool _disableLed = false;
  bool _busy = false;
  Color _ledColor = Colors.black;

  @override
  void initState() {
    super.initState();
    if (widget.stateReader != null) {
      _busy = true;
      _loadInitialState();
    }
  }

  Future<void> _loadInitialState() async {
    try {
      await _readState();
    } catch (_) {
      // Keep the existing controls available if readback fails.
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _readState({bool keepColorEditor = false}) async {
    final reader = widget.stateReader;
    if (reader == null) return;
    final state = await reader.readLedState();
    if (!mounted) return;
    setState(() {
      _disableLed = !state.showStatus && state.isBlack && !keepColorEditor;
      _overrideColor = !state.showStatus && !_disableLed;
      _ledColor = Color.fromARGB(255, state.red, state.green, state.blue);
    });
  }

  Future<void> _applyState(
      {required bool disable, required bool override,}) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await widget.statusLED.showStatus(!disable && !override);
      if (disable) await widget.rgbLed.writeLedColor(r: 0, g: 0, b: 0);
      if (!mounted) return;
      setState(() {
        _disableLed = disable;
        _overrideColor = override;
      });
      // A black override also means "disabled" on the device. Keep the color
      // picker available while the user is choosing an override color.
      await _readState(keepColorEditor: override);
    } catch (_) {
      // A partial write may have changed the mode but not the color.
      try {
        await _readState(keepColorEditor: _overrideColor);
      } catch (_) {}
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _onDisableLedChanged(bool value) =>
      _applyState(disable: value, override: false);

  Future<void> _onOverrideChanged(bool value) =>
      _applyState(disable: false, override: value);

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
              onChanged: _busy ? null : _onDisableLedChanged,
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
              onChanged: _busy ? null : _onOverrideChanged,
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
                        RgbControlView(
                          rgbLed: widget.rgbLed,
                          initialColor: _ledColor,
                        ),
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
