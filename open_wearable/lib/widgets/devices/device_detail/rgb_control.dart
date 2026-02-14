import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart';

class RgbControlView extends StatefulWidget {
  final RgbLed rgbLed;

  const RgbControlView({super.key, required this.rgbLed});

  @override
  State<RgbControlView> createState() => _RgbControlViewState();
}

class _RgbControlViewState extends State<RgbControlView> {
  Color _currentColor = Colors.black;

  void _showColorPickerDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: PlatformText('Pick a color for the RGB LED'),
          content: SingleChildScrollView(
            child: ColorPicker(
              pickerColor: _currentColor,
              onColorChanged: (color) {
                setState(() {
                  _currentColor = color;
                });
              },
              pickerAreaHeightPercent: 0.8,
              enableAlpha: false,
            ),
          ),
          actions: <Widget>[
            PlatformTextButton(
              child: PlatformText('Done'),
              onPressed: () {
                widget.rgbLed.writeLedColor(
                  r: (255 * _currentColor.r).round(),
                  g: (255 * _currentColor.g).round(),
                  b: (255 * _currentColor.b).round(),
                );
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return OutlinedButton.icon(
      onPressed: _showColorPickerDialog,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        minimumSize: const Size(0, 34),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        side: BorderSide(
          color: colorScheme.outlineVariant.withValues(alpha: 0.65),
        ),
        foregroundColor: colorScheme.onSurface,
      ),
      icon: Container(
        width: 14,
        height: 14,
        decoration: BoxDecoration(
          color: _currentColor,
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.black.withValues(alpha: 0.18),
          ),
        ),
      ),
      label: PlatformText(
        'Color',
        style: theme.textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
