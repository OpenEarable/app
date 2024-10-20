import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:open_earable/controls_tab/models/open_earable_settings.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart';
import 'dart:async';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'dart:io';
import 'package:provider/provider.dart';
import 'package:open_earable/ble/ble_controller.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:open_earable/shared/global_theme.dart';

class LEDColorCard extends StatefulWidget {
  const LEDColorCard({super.key});

  @override
  State<LEDColorCard> createState() => _LEDColorCardState();
}

class _LEDColorCardState extends State<LEDColorCard> {
  Timer? rainbowTimer;
  late OpenEarable _openEarableLeft;
  late OpenEarable _openEarableRight;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _openEarableLeft =
        Provider.of<BluetoothController>(context).openEarableLeft;
    _openEarableRight =
        Provider.of<BluetoothController>(context).openEarableRight;
  }

  void _setLEDColor() {
    _stopRainbowMode();
    _openEarableLeft.rgbLed.writeLedColor(
      r: OpenEarableSettings().selectedColor.red,
      g: OpenEarableSettings().selectedColor.green,
      b: OpenEarableSettings().selectedColor.blue,
    );
    _openEarableRight.rgbLed.writeLedColor(
      r: OpenEarableSettings().selectedColor.red,
      g: OpenEarableSettings().selectedColor.green,
      b: OpenEarableSettings().selectedColor.blue,
    );
  }

  void _turnLEDoff() {
    _stopRainbowMode();
    _openEarableLeft.rgbLed.writeLedColor(r: 0, g: 0, b: 0);
    _openEarableRight.rgbLed.writeLedColor(r: 0, g: 0, b: 0);
  }

  void _startRainbowMode() {
    if (OpenEarableSettings().rainbowModeActive) return;

    OpenEarableSettings().rainbowModeActive = true;

    double h = 0;
    const double increment = 0.01;

    rainbowTimer = Timer.periodic(Duration(milliseconds: 300), (Timer timer) {
      Map<String, int> rgbValue = _hslToRgb(h, 1, 0.5);
      _openEarableLeft.rgbLed.writeLedColor(
        r: rgbValue['r']!,
        g: rgbValue['g']!,
        b: rgbValue['b']!,
      );
      _openEarableRight.rgbLed.writeLedColor(
        r: rgbValue['r']!,
        g: rgbValue['g']!,
        b: rgbValue['b']!,
      );

      h += increment;
      if (h > 1) h = 0;
    });
  }

  void _stopRainbowMode() {
    OpenEarableSettings().rainbowModeActive = false;
    if (rainbowTimer == null) {
      return;
    }
    if (rainbowTimer!.isActive) {
      rainbowTimer?.cancel();
    }
  }

  /*
  Map<String, int> _hexToRgb(String hex) {
    hex = hex.startsWith('#') ? hex.substring(1) : hex;

    int bigint = int.parse(hex, radix: 16);
    int r = (bigint >> 16) & 255;
    int g = (bigint >> 8) & 255;
    int b = bigint & 255;

    return {'r': r, 'g': g, 'b': b};
  }
  */

  Map<String, int> _hslToRgb(double h, double s, double l) {
    double r, g, b;

    if (s == 0) {
      r = g = b = l;
    } else {
      double hue2rgb(double p, double q, double t) {
        if (t < 0) t += 1;
        if (t > 1) t -= 1;
        if (t < 1 / 6) return p + (q - p) * 6 * t;
        if (t < 1 / 2) return q;
        if (t < 2 / 3) return p + (q - p) * (2 / 3 - t) * 6;
        return p;
      }

      double q = l < 0.5 ? l * (1 + s) : l + s - l * s;
      double p = 2 * l - q;
      r = hue2rgb(p, q, h + 1 / 3);
      g = hue2rgb(p, q, h);
      b = hue2rgb(p, q, h - 1 / 3);
    }

    return {
      'r': (r * 255).round(),
      'g': (g * 255).round(),
      'b': (b * 255).round(),
    };
  }

  /*
  bool _isValidHex(String hex) {
    return RegExp(r'^#[0-9A-Fa-f]{6}$').hasMatch(hex);
  }
  */

  void _openColorPicker() {
    if (Platform.isAndroid) {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return Material(
            child: AlertDialog(
              title: const Text('Pick a color for the RGB LED'),
              content: SingleChildScrollView(
                child: ColorPicker(
                  pickerColor: OpenEarableSettings().selectedColor,
                  onColorChanged: (color) {
                    setState(() {
                      OpenEarableSettings().selectedColor = color;
                    });
                  },
                  pickerAreaHeightPercent: 0.8,
                  enableAlpha: false,
                ),
              ),
              actions: <Widget>[
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text('Done'),
                ),
              ],
            ),
          );
        },
      );
    } else {
      showCupertinoDialog(
        context: context,
        builder: (BuildContext context) {
          return CupertinoAlertDialog(
            title: Text('Pick a color for the RGB LED'),
            content: SingleChildScrollView(
              padding: EdgeInsets.zero,
              child: Theme(
                data: materialTheme,
                child: Material(
                  // Wrap with Material
                  child: Localizations(
                    locale:
                        const Locale('en', 'US'), // Specify the app's locale
                    delegates: [
                      GlobalMaterialLocalizations.delegate,
                      GlobalWidgetsLocalizations.delegate,
                      GlobalCupertinoLocalizations.delegate,
                    ],
                    child: ColorPicker(
                      pickerColor: OpenEarableSettings().selectedColor,
                      onColorChanged: (color) {
                        // Your color change logic
                        setState(() {
                          OpenEarableSettings().selectedColor = color;
                        });
                      },
                      pickerAreaHeightPercent: 0.8,
                      enableAlpha: false,
                    ), // Your widget that contains the DropdownButton
                  ),
                ),
              ),
            ),
            actions: <Widget>[
              CupertinoDialogAction(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: Text('Done'),
              ),
            ],
          );
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 5.0),
      child: Card(
        //LED Color Picker Card
        color: Theme.of(context).colorScheme.primary,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'LED Color',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18.0,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Selector<BluetoothController, bool>(
                selector: (_, bleController) => bleController.connected,
                builder: (context, connected, child) => Row(
                  children: [
                    GestureDetector(
                      onTap: connected
                          ? _openColorPicker
                          : null, // Open color picker
                      child: Container(
                        width: 66,
                        height: 36,
                        decoration: BoxDecoration(
                          color: OpenEarableSettings().selectedColor,
                          borderRadius: BorderRadius.circular(5),
                        ),
                      ),
                    ),
                    SizedBox(width: 5),
                    SizedBox(
                      width: 66,
                      height: 36,
                      child: ElevatedButton(
                        onPressed: connected ? _setLEDColor : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xff53515b),
                          // Set the background color to grey
                          foregroundColor: Colors.white,
                        ),
                        child: Text('Set'),
                      ),
                    ),
                    SizedBox(width: 5),
                    SizedBox(
                      width: 66,
                      height: 36,
                      child: ElevatedButton(
                        onPressed: connected ? _startRainbowMode : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xff53515b),
                          // Set the background color to grey
                          foregroundColor: Colors.white,
                        ),
                        child: Text("🦄"),
                      ),
                    ),
                    Spacer(),
                    SizedBox(
                      width: 66,
                      height: 36,
                      child: ElevatedButton(
                        onPressed: connected ? _turnLEDoff : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xfff27777),
                          foregroundColor: Colors.black,
                        ),
                        child: Text('Off'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
