import 'package:flutter/material.dart';
import 'package:open_earable_flutter/src/open_earable_flutter.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'ble.dart';
import 'dart:async';

class ActuatorsTab extends StatefulWidget {
  final OpenEarable _openEarable;
  ActuatorsTab(this._openEarable);
  @override
  _ActuatorsTabState createState() => _ActuatorsTabState(_openEarable);
}

class _ActuatorsTabState extends State<ActuatorsTab> {
  final OpenEarable _openEarable;
  _ActuatorsTabState(this._openEarable);
  bool isPlaying = false;
  bool songStarted = false;
  Color _selectedColor = Colors.deepPurple;

  TextEditingController _filenameTextController = TextEditingController();
  TextEditingController _audioFrequencyTextController = TextEditingController();
  StreamSubscription<bool>? _connectionStateSubscription;
  StreamSubscription<dynamic>? _batteryLevelSubscription;
  bool connected = false;
  String earableDeviceName = "";
  int earableSOC = 0;

  late Timer rainbowTimer;
  late bool rainbowModeActive;

  @override
  void dispose() {
    super.dispose();
    _connectionStateSubscription?.cancel();
    _batteryLevelSubscription?.cancel();
  }

  @override
  void initState() {
    _connectionStateSubscription =
        _openEarable.bleManager.connectionStateStream.listen((connected) {
      setState(() {
        this.connected = connected;

        if (connected) {
          getNameAndSOC();
        }
      });
    });
    setState(() {
      connected = _openEarable.bleManager.connected;

      if (connected) {
        getNameAndSOC();
      }
      super.initState();
    });
  }

  void getNameAndSOC() {
    String? name = _openEarable.bleManager.connectedDevice?.name;
    earableDeviceName = name ?? "";

    _batteryLevelSubscription = _openEarable.sensorManager
        .getBatteryLevelStream()
        .listen((batteryLevel) {
      setState(() {
        earableSOC = batteryLevel[0].toInt();
      });
    });
  }

  void playWAV() {
    _openEarable.audioPlayer.setWavState(AudioPlayerState.start,
        name: _filenameTextController.text);
  }

  void setLEDColor() {
    stopRainbowMode();
    _openEarable.rgbLed.writeLedColor(
        r: _selectedColor.red, g: _selectedColor.green, b: _selectedColor.blue);
  }

  void pauseWAV() {
    _openEarable.audioPlayer.setWavState(AudioPlayerState.pause);
  }

  void stopWAV() {
    _openEarable.audioPlayer.setWavState(AudioPlayerState.stop);
  }

  void playFrequencySound() {
    double frequency =
        double.tryParse(_audioFrequencyTextController.text) ?? 100.0;
    _openEarable.audioPlayer
        .setFrequencyState(AudioPlayerState.start, frequency: frequency, waveForm: 0);
  }

  void stopFrequencySound() {
    _openEarable.audioPlayer.setFrequencyState(AudioPlayerState.stop, frequency: 0.0, waveForm: 0);
  }

  void turnLEDoff() {
    stopRainbowMode();
    _openEarable.rgbLed.writeLedColor(r: 0, g: 0, b: 0);
  }

  void startRainbowMode() {
    if (rainbowModeActive) return;

    rainbowModeActive = true;

    double h = 0;
    const double increment = 0.01;

    rainbowTimer = Timer.periodic(Duration(milliseconds: 300), (Timer timer) {
      Map<String, int> rgbValue = hslToRgb(h, 1, 0.5);
      _openEarable.rgbLed.writeLedColor(
          r: rgbValue['r']!, g: rgbValue['g']!, b: rgbValue['b']!);

      h += increment;
      if (h > 1) h = 0;
    });
  }

  void stopRainbowMode() {
    rainbowModeActive = false;

    if (rainbowTimer.isActive) {
      rainbowTimer.cancel();
    }
  }

  Map<String, int> hexToRgb(String hex) {
    hex = hex.startsWith('#') ? hex.substring(1) : hex;

    int bigint = int.parse(hex, radix: 16);
    int r = (bigint >> 16) & 255;
    int g = (bigint >> 8) & 255;
    int b = bigint & 255;

    return {'r': r, 'g': g, 'b': b};
  }

  Map<String, int> hslToRgb(double h, double s, double l) {
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
      'b': (b * 255).round()
    };
  }

  bool isValidHex(String hex) {
    return RegExp(r'^#[0-9A-Fa-f]{6}$').hasMatch(hex);
  }

  void _openColorPicker() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Pick a color for the RGB LED'),
          content: SingleChildScrollView(
            child: ColorPicker(
              pickerColor: _selectedColor,
              onColorChanged: (color) {
                setState(() {
                  _selectedColor = color;
                });
              },
              showLabel: true,
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
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Card(
          color: Color(0xff161618),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Device Connection',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18.0,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 5),
                Row(
                  children: [
                    Text(
                      !connected
                          ? "OpenEarable not connected."
                          : "$earableDeviceName Battery: $earableSOC%",
                      style: TextStyle(
                        color: Color.fromRGBO(168, 168, 172, 1.0),
                        fontSize: 15.0,
                        fontStyle:
                            !connected ? FontStyle.italic : FontStyle.normal,
                      ),
                    ),
                  ],
                ),
                Visibility(
                  visible: !connected,
                  child: Column(
                    children: [
                      SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 37.0,
                              child: ElevatedButton(
                                onPressed: () {
                                  Navigator.of(context).push(MaterialPageRoute(
                                      builder: (context) =>
                                          BLEPage(_openEarable)));
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: !connected
                                      ? Color(0xff77F2A1)
                                      : Color(0xfff27777),
                                  foregroundColor: Colors.black,
                                ),
                                child: Text("Connect"),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                )
              ],
            ),
          ),
        ),
        Card(
          //LED Color Picker Card
          color: Color(0xff161618),
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
                Row(
                  children: [
                    GestureDetector(
                      onTap: connected
                          ? _openColorPicker
                          : null, // Open color picker
                      child: Container(
                        width: 66,
                        height: 36,
                        decoration: BoxDecoration(
                          color: _selectedColor,
                          borderRadius: BorderRadius.circular(5),
                        ),
                      ),
                    ),
                    SizedBox(width: 5),
                    SizedBox(
                      width: 130,
                      child: ElevatedButton(
                        onPressed: connected ? setLEDColor : null,
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Color(
                                0xff53515b), // Set the background color to grey
                            foregroundColor: Colors.white),
                        child: Text('Set Color'),
                      ),
                    ),
                    SizedBox(width: 5),
                    ElevatedButton(
                      onPressed: connected ? startRainbowMode : null, 
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Color(
                              0xff53515b), // Set the background color to grey
                          foregroundColor: Colors.white),
                          child: Text("🦄"),
                    ),
                    Spacer(),
                    ElevatedButton(
                      onPressed: connected ? turnLEDoff : null,
                      child: Text('Off'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xfff27777),
                        foregroundColor: Colors.black,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        Card(
          //Audio Player Card
          color: Color(0xff161618),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Audio Player',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18.0,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        ElevatedButton(
                          onPressed: connected ? playWAV : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Color(0xff77F2A1),
                            foregroundColor: Colors.black,
                          ),
                          child: Icon(Icons.play_arrow_outlined),
                        ),
                        Expanded(
                          child: SizedBox(
                            height: 37.0,
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 5),
                              child: TextField(
                                controller: _filenameTextController,
                                obscureText: false,
                                enabled: connected,
                                style: TextStyle(
                                    color:
                                        connected ? Colors.black : Colors.grey),
                                decoration: InputDecoration(
                                  border: OutlineInputBorder(),
                                  labelText: 'filename.wav',
                                  labelStyle: TextStyle(
                                      color: connected
                                          ? Colors.black
                                          : Colors.grey),
                                  filled: true,
                                  fillColor: connected
                                      ? Colors.white
                                      : Colors.grey[200],
                                ),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 10),
                        ElevatedButton(
                          onPressed: connected ? pauseWAV : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Color(0xffe0f277),
                            foregroundColor: Colors.black,
                          ),
                          child: Icon(Icons.pause),
                        ),
                        SizedBox(width: 5),
                        ElevatedButton(
                          onPressed: connected ? stopWAV : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Color(0xfff27777),
                            foregroundColor: Colors.black,
                          ),
                          child: Icon(Icons.stop_outlined),
                        ),
                      ],
                    ),
                    Divider(thickness: 1.0, color: Colors.white),
                    Row(
                      children: [
                        SizedBox(height: 10),
                        ElevatedButton(
                          onPressed: connected ? playFrequencySound : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Color(0xff77F2A1),
                            foregroundColor: Colors.black,
                          ),
                          child: Icon(Icons.play_arrow_outlined),
                        ),
                        SizedBox(width: 5),
                        Expanded(
                          child: SizedBox(
                            height: 37.0,
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 0),
                              child: TextField(
                                controller: _audioFrequencyTextController,
                                textAlign: TextAlign.end,
                                style: TextStyle(
                                    color:
                                        connected ? Colors.black : Colors.grey),
                                decoration: InputDecoration(
                                  border: OutlineInputBorder(),
                                  labelText: '100',
                                  filled: true,
                                  labelStyle: TextStyle(
                                      color: connected
                                          ? Colors.black
                                          : Colors.grey),
                                  fillColor: connected
                                      ? Colors.white
                                      : Colors.grey[200],
                                ),
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 5),
                          child: Text(
                            'Hz',
                            style: TextStyle(
                                color: connected
                                    ? Colors.white
                                    : Colors.grey), // Set text color to white
                          ),
                        ),
                        SizedBox(width: 50),
                        SizedBox(width: 5),
                        ElevatedButton(
                          onPressed: connected ? stopFrequencySound : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Color(0xfff27777),
                            foregroundColor: Colors.black,
                          ),
                          child: Icon(Icons.stop_outlined),
                        )
                      ],
                    ),
                  ],
                )
              ],
            ),
          ),
        ),
        Spacer(),
      ],
    );
  }
}
