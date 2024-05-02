import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:open_earable/ble/ble_controller.dart';
import 'package:open_earable_flutter/src/open_earable_flutter.dart';
import 'package:provider/provider.dart';
import '../models/open_earable_settings.dart';
import '../../shared/dynamic_value_picker.dart';

class AudioPlayerCard extends StatefulWidget {
  final OpenEarable _openEarable;
  AudioPlayerCard(this._openEarable);

  @override
  _AudioPlayerCardState createState() => _AudioPlayerCardState(_openEarable);
}

class _AudioPlayerCardState extends State<AudioPlayerCard> {
  final OpenEarable _openEarable;
  _AudioPlayerCardState(this._openEarable);

  late TextEditingController _filenameTextController;
  late TextEditingController _jingleTextController;

  late TextEditingController _frequencyTextController;
  late TextEditingController _frequencyVolumeTextController;
  late TextEditingController _waveFormTextController;

  @override
  void initState() {
    super.initState();
    _filenameTextController = TextEditingController(
        text: "${OpenEarableSettings().selectedFilename}");
    _frequencyTextController = TextEditingController(
        text: "${OpenEarableSettings().selectedFrequency}");
    _frequencyVolumeTextController = TextEditingController(
        text: "${OpenEarableSettings().selectedFrequencyVolume}");
    _waveFormTextController =
        TextEditingController(text: OpenEarableSettings().selectedWaveForm);
  }

  void updateText(bool connected) {
    if (connected) {
      OpenEarableSettings().selectedFilename = _filenameTextController.text;
      OpenEarableSettings().selectedFrequency = _frequencyTextController.text;
      OpenEarableSettings().selectedFrequencyVolume =
          _frequencyVolumeTextController.text;
    } else {
      _filenameTextController.text = OpenEarableSettings().selectedFilename;
      _frequencyTextController.text = OpenEarableSettings().selectedFrequency;
      _frequencyVolumeTextController.text =
          OpenEarableSettings().selectedFrequencyVolume;
    }
  }

  void _playButtonPressed() {
    _openEarable.audioPlayer.setState(AudioPlayerState.start);
  }

  void _pauseButtonPressed() {
    _openEarable.audioPlayer.setState(AudioPlayerState.pause);
  }

  void _stopButtonPressed() {
    _openEarable.audioPlayer.setState(AudioPlayerState.stop);
  }

  void _setSourceButtonPressed() {
    switch (OpenEarableSettings().selectedAudioPlayerRadio) {
      case 0:
        _setWAV();
        break;
      case 1:
        _setJingle();
        break;
      case 2:
        _setFrequencySound();
    }
  }

  void _setJingle() {
    int jingleIndex =
        OpenEarableSettings().getJingleIndex(_jingleTextController.text);
    print("Setting source to jingle '" +
        _jingleTextController.text +
        "' with index $jingleIndex");
    _openEarable.audioPlayer.jingle(jingleIndex);
  }

  void _setWAV() {
    String fileName = _filenameTextController.text;

    if (fileName == "") {
      _showAlert("Empty file name", "WAV file name is empty!", "Dismiss");
      return;
    } else if (!fileName.endsWith('.wav')) {
      _showAlert("Missing '.wav' ending",
          "WAV file name is missing the '.wav' ending!", "Dismiss");
      return;
    }
    print("Setting source to wav file with file name '" + fileName + "'");
    _openEarable.audioPlayer.wavFile(_filenameTextController.text);
  }

  void _setFrequencySound() {
    double frequency = double.tryParse(_frequencyTextController.text) ?? 440.0;
    int waveForm =
        OpenEarableSettings().getWaveFormIndex(_waveFormTextController.text);
    double loudness =
        (double.tryParse(_frequencyVolumeTextController.text) ?? 100.0) / 100.0;

    if ((frequency < 0 || frequency > 30000) ||
        (loudness < 0 || loudness > 100)) {
      _showAlert("Invalid value(s)", "Invalid frequency range or loudness!",
          "Dismiss");
      return;
    }

    print("Setting source with frequency value " +
        frequency.toString() +
        "' Hz, wave type '" +
        waveForm.toString() +
        "', and loudness '" +
        loudness.toString() +
        "'.");
    _openEarable.audioPlayer.frequency(waveForm, frequency, loudness);
  }

  void _showAlert(String title, String message, String dismissButtonText) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text(dismissButtonText),
            ),
          ],
        );
      },
    );
  }

  void _showSoundPicker(BuildContext context, Map<int, String> soundsMap,
      TextEditingController textController) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: soundsMap.values.map((String option) {
              return ListTile(
                onTap: Provider.of<BluetoothController>(context).connected
                    ? () {
                        setState(() {
                          textController.text = option;
                          Navigator.pop(context);
                        });
                      }
                    : null,
                title: Text(option),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 5.0),
        child: Selector<BluetoothController, bool>(
            selector: (_, bleController) => bleController.connected,
            builder: (context, connected, child) {
              updateText(connected);
              return Card(
                //Audio Player Card
                color: Platform.isIOS
                    ? CupertinoTheme.of(context).primaryContrastingColor
                    : Theme.of(context).colorScheme.primary,
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
                      _getFileNameRow(),
                      _getJingleRow(),
                      _getFrequencyRow(),
                      SizedBox(height: 12),
                      Platform.isIOS
                          ? _getCupertinoButtonRow(connected)
                          : _getMaterialButtonRow(connected),
                    ],
                  ),
                ),
              );
            }));
  }

  Widget _getAudioPlayerRadio(int index) {
    return Selector<BluetoothController, bool>(
        selector: (_, bleController) => bleController.connected,
        builder: (context, connected, child) {
          return SizedBox(
              height: 38,
              width: 44,
              child: Platform.isIOS
                  ? CupertinoRadio(
                      value: index,
                      groupValue:
                          OpenEarableSettings().selectedAudioPlayerRadio,
                      onChanged: !connected
                          ? null
                          : (int? value) {
                              setState(() {
                                OpenEarableSettings().selectedAudioPlayerRadio =
                                    value ?? 0;
                              });
                            },
                      activeColor: CupertinoTheme.of(context).primaryColor,
                      fillColor:
                          CupertinoTheme.of(context).primaryContrastingColor,
                      inactiveColor:
                          CupertinoTheme.of(context).primaryContrastingColor,
                    )
                  : Radio(
                      value: index,
                      groupValue:
                          OpenEarableSettings().selectedAudioPlayerRadio,
                      onChanged: !connected
                          ? null
                          : (int? value) {
                              setState(() {
                                OpenEarableSettings().selectedAudioPlayerRadio =
                                    value ?? 0;
                              });
                            },
                      fillColor: MaterialStateProperty.resolveWith((states) {
                        if (states.contains(MaterialState.selected)) {
                          return Theme.of(context).colorScheme.secondary;
                        }
                        return Colors.grey;
                      }),
                    ));
        });
  }

  Widget _getFileNameRow() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
          padding: EdgeInsets.fromLTRB(44, 0, 0, 0),
          child: Text(
            "Audio File",
            style: TextStyle(
              color: Color.fromRGBO(168, 168, 172, 1.0),
            ),
          )),
      Row(
        children: [
          _getAudioPlayerRadio(0),
          Expanded(
            child: SizedBox(
                height: 38.0,
                child: _fileNameTextField(
                    _filenameTextController, TextInputType.text, null, null)),
          ),
        ],
      )
    ]);
  }

  Widget _fileNameTextField(TextEditingController textController,
      TextInputType keyboardType, String? placeholder, int? maxLength) {
    return Selector<BluetoothController, bool>(
        selector: (_, controller) => controller.connected,
        builder: (context, connected, child) {
          if (Platform.isIOS) {
            return CupertinoTextField(
              cursorColor: Colors.blue,
              controller: textController,
              obscureText: false,
              placeholder: placeholder,
              style: TextStyle(
                color: connected ? Colors.black : Colors.grey,
              ),
              padding: EdgeInsets.fromLTRB(8, 0, 0, 0),
              textAlignVertical: TextAlignVertical.center,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) {
                FocusScope.of(context).requestFocus(FocusNode());
              },
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(4.0),
              ),
              placeholderStyle: TextStyle(
                color: connected ? Colors.black : Colors.grey,
              ),
              keyboardType: keyboardType,
              maxLength: maxLength,
              maxLines: 1,
            );
          } else {
            return TextField(
              controller: textController,
              obscureText: false,
              enabled: connected,
              style: TextStyle(color: connected ? Colors.black : Colors.grey),
              decoration: InputDecoration(
                labelText: placeholder,
                contentPadding: EdgeInsets.fromLTRB(8, 0, 0, 0),
                border: OutlineInputBorder(),
                floatingLabelBehavior: FloatingLabelBehavior.never,
                labelStyle:
                    TextStyle(color: connected ? Colors.black : Colors.grey),
                filled: true,
                fillColor: connected ? Colors.white : Colors.grey[200],
              ),
              keyboardType: keyboardType,
              maxLength: maxLength,
              maxLines: 1,
            );
          }
        });
  }

  Widget _getJingleRow() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
          padding: EdgeInsets.fromLTRB(44, 8, 0, 0),
          child: Text(
            "Jingle",
            style: TextStyle(
              color: Color.fromRGBO(168, 168, 172, 1.0),
            ),
          )),
      Row(
        children: [
          _getAudioPlayerRadio(1),
          Container(
              decoration: BoxDecoration(
                color: Provider.of<BluetoothController>(context).connected
                    ? Colors.white
                    : Colors.grey[200],
                borderRadius: BorderRadius.circular(4.0),
              ),
              child: SizedBox(
                  height: 40,
                  child: Container(
                    padding: EdgeInsets.fromLTRB(8, 0, 0, 0),
                    alignment: Alignment.centerRight,
                    child: DynamicValuePicker(
                      context,
                      OpenEarableSettings().jingleMap.keys.toList(),
                      OpenEarableSettings().selectedJingle,
                      (newValue) {
                        setState(() {
                          OpenEarableSettings().selectedJingle = newValue;
                        });
                      },
                      Provider.of<BluetoothController>(context).connected,
                      false,
                    ),
                  ))),
        ],
      )
    ]);
  }

  Widget _getFrequencyRow() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
          padding: EdgeInsets.fromLTRB(44, 8, 0, 0),
          child: Text(
            "Frequency",
            style: TextStyle(
              color: Color.fromRGBO(168, 168, 172, 1.0),
            ),
          )),
      Row(
        children: [
          _getAudioPlayerRadio(2),
          SizedBox(
              height: 38.0,
              width: 75,
              child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 0),
                  child: _fileNameTextField(_frequencyTextController,
                      TextInputType.number, "440", null))),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 5),
            child: Text(
              'Hz',
              style: TextStyle(
                  color: Provider.of<BluetoothController>(context).connected
                      ? Colors.white
                      : Colors.grey), // Set text color to white
            ),
          ),
          Spacer(),
          SizedBox(
              height: 38.0,
              width: 52,
              child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 0),
                  child: _fileNameTextField(_frequencyVolumeTextController,
                      TextInputType.number, "50", null))),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 5),
            child: Text(
              '%',
              style: TextStyle(
                  color: Provider.of<BluetoothController>(context).connected
                      ? Colors.white
                      : Colors.grey), // Set text color to white
            ),
          ),
          Spacer(),
          SizedBox(
            height: 38.0,
            width: 107,
            child: DynamicValuePicker(
                context,
                OpenEarableSettings().waveFormMap.keys.toList(),
                OpenEarableSettings().selectedWaveForm, (newValue) {
              setState(
                () {
                  OpenEarableSettings().selectedWaveForm = newValue;
                },
              );
            }, Provider.of<BluetoothController>(context).connected, false),
          ),
        ],
      )
    ]);
  }

  Widget _getMaterialButtonRow(bool _connected) {
    return Row(
      mainAxisAlignment:
          MainAxisAlignment.spaceBetween, // Align buttons to the space between
      children: [
        SizedBox(
          width: 120,
          child: ElevatedButton(
            onPressed: _connected ? _setSourceButtonPressed : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xff53515b),
              foregroundColor: Colors.white,
            ),
            child: Text('Set Source'),
          ),
        ),
        ElevatedButton(
          onPressed: _connected ? _playButtonPressed : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: Color(0xff77F2A1),
            foregroundColor: Colors.black,
          ),
          child: Icon(Icons.play_arrow_outlined),
        ),
        ElevatedButton(
          onPressed: _connected ? _pauseButtonPressed : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: Color(0xffe0f277),
            foregroundColor: Colors.black,
          ),
          child: Icon(Icons.pause),
        ),
        ElevatedButton(
          onPressed: _connected ? _stopButtonPressed : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: Color(0xfff27777),
            foregroundColor: Colors.black,
          ),
          child: Icon(Icons.stop_outlined),
        ),
      ],
    );
  }

  Widget _getCupertinoButtonRow(bool _connected) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        SizedBox(
          width: 120,
          child: CupertinoButton(
            padding: EdgeInsets.all(0),
            onPressed: _connected ? _setSourceButtonPressed : null,
            color: Color(0xff53515b),
            child: Text(
              'Set\nSource',
              style: TextStyle(
                  color: _connected ? Colors.white : null, fontSize: 15),
            ),
          ),
        ),
        SizedBox(width: 4),
        Expanded(
            child: CupertinoButton(
          padding: EdgeInsets.all(0),
          onPressed: _connected ? _playButtonPressed : null,
          color: CupertinoTheme.of(context).primaryColor,
          child: Icon(CupertinoIcons.play),
        )),
        SizedBox(width: 4),
        Expanded(
            child: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _connected ? _pauseButtonPressed : null,
          color: Color(0xffe0f277),
          child: Icon(CupertinoIcons.pause),
        )),
        SizedBox(width: 4),
        Expanded(
            child: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _connected ? _stopButtonPressed : null,
          color: Color(0xfff27777),
          child: Icon(CupertinoIcons.stop),
        )),
      ],
    );
  }
}
