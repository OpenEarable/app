import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
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
          title: const Text('Pick a color for the RGB LED'),
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
            TextButton(
              child: const Text('Done'),
              onPressed: () {
                widget.rgbLed.writeLedColor(
                  r: (255 *_currentColor.r).round(),
                  g: (255 *_currentColor.g).round(),
                  b: (255 *_currentColor.b).round(),
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
    return ElevatedButton(
      onPressed: _showColorPickerDialog,
      style: ElevatedButton.styleFrom(
        backgroundColor: _currentColor,
        foregroundColor: _currentColor.computeLuminance() > 0.5
            ? Colors.black
            : Colors.white,
      ),
      child: const Text('Color'),
    );
  }
}
