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

  void togglePlay() {
    //TODO
  }

  void togglePause() {
    //TODO
  }

  void toggleStop() {
    //TODO
  }

  void selectFilename() {
    //TODO
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
    return Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Card(
        //LED Color Picker Card
        color: Colors.black,
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
                  Container(
                    width: 66,
                    height: 36,
                    decoration: BoxDecoration(
                      color: _selectedColor, //TODO: send selection to earable
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                  SizedBox(width: 5),
                  SizedBox(
                    width: 130,
                    child: ElevatedButton(
                      onPressed: _openColorPicker,
                      child: Text('set color'),
                    ),
                  ),
                  Spacer(),
                  ElevatedButton(
                      onPressed: () {}, //TODO
                      child: Text('off'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xfff27777),
                        foregroundColor: Colors.black,
                      ))
                ],
              ),
            ],
          ),
        ),
      ),
      Card(
          //Audio Player Card
          color: Colors.black,
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
                          ElevatedButton(
                            onPressed: togglePlay,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Color(0xff77F2A1),
                              foregroundColor: Colors.black,
                            ),
                            child: Icon(Icons.play_arrow),
                          ),
                          Expanded(
                            child: SizedBox(
                              height: 37.0,
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 5),
                                child: TextField(
                                  obscureText: false,
                                  decoration: InputDecoration(
                                    border: OutlineInputBorder(),
                                    labelText: 'filename.wav',
                                    filled: true,
                                    fillColor: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: 10),
                          ElevatedButton(
                            onPressed: _openColorPicker,
                            child: Text('set color'),
                          ),
                          SizedBox(width: 5),
                          ElevatedButton(
                            onPressed: toggleStop,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Color(0xfff27777),
                              foregroundColor: Colors.black,
                            ),
                            child: Icon(Icons.stop),
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
                            child: Icon(Icons.play_arrow),
                          ),
                          SizedBox(width: 5),
                          Expanded(
                            child: SizedBox(
                              height: 37.0,
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 0),
                                child: TextField(
                                  textAlign: TextAlign.end,
                                  decoration: InputDecoration(
                                    border: OutlineInputBorder(),
                                    labelText: '100',
                                    filled: true,
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
                                  color:
                                      Colors.white), // Set text color to white
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
                            child: Icon(Icons.stop),
                          )
                        ],
                      ),
                    ],
                  ),
                ],
              ))),
      Spacer()
    ]);
  }

  @override
  void dispose() {
    super.dispose();
  }
}
