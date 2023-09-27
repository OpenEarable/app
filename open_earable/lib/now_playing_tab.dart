import 'package:flutter/material.dart';
import 'package:open_earable_flutter/src/open_earable_flutter.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
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

  void togglePlay() {
    _openEarable.audioPlayer.setWavState(AudioPlayerState.start,
        name: _filenameTextController.text);
  }

  void setLEDColor() {
    _openEarable.rgbLed.writeLedColor(
        r: _selectedColor.red, g: _selectedColor.green, b: _selectedColor.blue);
  }

  void togglePause() {
    _openEarable.audioPlayer.setWavState(AudioPlayerState.pause);
  }

  void toggleStop() {
    _openEarable.audioPlayer.setWavState(AudioPlayerState.stop);
  }

  void turnLEDoff() {
    _openEarable.rgbLed.writeLedColor(r: 0, g: 0, b: 0);
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
                      'OpenEarable not connected.',
                      style: TextStyle(
                        color: Color.fromRGBO(168, 168, 172, 1.0),
                        fontSize: 15.0,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),

                SizedBox(height: 5),

                Row(children: [
                  Expanded(
                      child: SizedBox(
                        height: 37.0,
                        child: ElevatedButton(
                          onPressed: () {}, //TODO
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Color(0xfff27777),
                            foregroundColor: Colors.black,
                          ),
                          child: Text('Off'),
                        ),
                      ),
                    ),
                ],
                ),
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
                      onTap: _openColorPicker, // Open color picker
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
                        onPressed: setLEDColor, // Call foo() function
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Color(
                                0xff53515b), // Set the background color to grey
                            foregroundColor: Colors.white),
                        child: Text('Set Color'),
                      ),
                    ),
                    Spacer(),
                    ElevatedButton(
                      onPressed: turnLEDoff,
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
                          onPressed: togglePlay,
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
                                style: TextStyle(color: Colors.black),
                                decoration: InputDecoration(
                                  border: OutlineInputBorder(),
                                  labelText: 'filename.wav',
                                  labelStyle: TextStyle(color: Colors.black),
                                  filled: true,
                                  fillColor: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 10),
                        ElevatedButton(
                          onPressed: togglePause,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Color(0xffe0f277),
                            foregroundColor: Colors.black,
                          ),
                          child: Icon(Icons.pause),
                        ),
                        SizedBox(width: 5),
                        ElevatedButton(
                          onPressed: toggleStop,
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
                          onPressed: () {}, //TODO
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
                                style: TextStyle(color: Colors.black),
                                decoration: InputDecoration(
                                  border: OutlineInputBorder(),
                                  labelText: '100',
                                  filled: true,
                                  labelStyle: TextStyle(color: Colors.black),
                                  fillColor: Colors.white,
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
                                color: Colors.white), // Set text color to white
                          ),
                        ),
                        SizedBox(width: 50),
                        SizedBox(width: 5),
                        ElevatedButton(
                          onPressed: () {}, //TODO
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

  @override
  void dispose() {
    super.dispose();
  }
}
