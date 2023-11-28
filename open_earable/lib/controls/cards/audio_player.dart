import 'package:flutter/material.dart';
import 'package:open_earable_flutter/src/open_earable_flutter.dart';

class AudioPlayerCard extends StatefulWidget {
  final OpenEarable _openEarable;
  AudioPlayerCard(this._openEarable);

  @override
  _AudioPlayerCardState createState() => _AudioPlayerCardState(_openEarable);
}

class _AudioPlayerCardState extends State<AudioPlayerCard> {
  final OpenEarable _openEarable;
  _AudioPlayerCardState(this._openEarable);
  int _selectedRadio = 0;
  late TextEditingController _filenameTextController;
  late TextEditingController _jingleTextController;
  late TextEditingController _audioFrequencyTextController;
  late TextEditingController _audioPercentageTextController;
  late TextEditingController _audioWaveFormTextController;

  final Map<int, String> _jingleMap = {
    0: 'IDLE',
    1: 'NOTIFICATION',
    2: 'SUCCESS',
    3: 'ERROR',
    4: 'ALARM',
    5: 'PING',
    6: 'OPEN',
    7: 'CLOSE',
    8: 'CLICK',
  };
  final Map<int, String> _waveFormMap = {
    1: 'SINE',
    2: 'SQUARE',
    3: 'TRIANGLE',
    4: 'SAW',
  };

  @override
  void initState() {
    super.initState();
    _filenameTextController = TextEditingController(text: "filename.wav");
    _jingleTextController = TextEditingController(text: _jingleMap[1]);
    _audioFrequencyTextController = TextEditingController(text: "440");
    _audioPercentageTextController = TextEditingController(text: "50");
    _audioWaveFormTextController = TextEditingController(text: _waveFormMap[1]);
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
    switch (_selectedRadio) {
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
    String jingle = _jingleTextController.text;
    print("Setting source to jingle '" + jingle + "'");
    _openEarable.audioPlayer.jingle(_getKeyFromValue(jingle, _jingleMap));
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
    double frequency =
        double.tryParse(_audioFrequencyTextController.text) ?? 440.0;
    int waveForm =
        _getKeyFromValue(_audioWaveFormTextController.text, _waveFormMap);
    double loudness =
        (double.tryParse(_audioPercentageTextController.text) ?? 100.0) / 100.0;

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

  int _getKeyFromValue(String value, Map<int, String> map) {
    for (var entry in map.entries) {
      if (entry.value == value) {
        return entry.key;
      }
    }
    return 1;
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
                onTap: _openEarable.bleManager.connected
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
      child: Card(
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
              _getFileNameRow(),
              _getJingleRow(),
              _getFrequencyRow(),
              _getButtonRow(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _getFileNameRow() {
    return Row(
      children: [
        Radio(
          value: 0,
          groupValue: _selectedRadio,
          onChanged: (int? value) {
            setState(() {
              _selectedRadio = value ?? 0;
            });
          },
        ),
        Expanded(
          child: SizedBox(
            height: 37.0,
            child: TextField(
              controller: _filenameTextController,
              obscureText: false,
              enabled: _openEarable.bleManager.connected,
              style: TextStyle(
                  color: _openEarable.bleManager.connected
                      ? Colors.black
                      : Colors.grey),
              decoration: InputDecoration(
                contentPadding: EdgeInsets.all(10),
                border: OutlineInputBorder(),
                floatingLabelBehavior: FloatingLabelBehavior.never,
                labelStyle: TextStyle(
                    color: _openEarable.bleManager.connected
                        ? Colors.black
                        : Colors.grey),
                filled: true,
                fillColor: _openEarable.bleManager.connected
                    ? Colors.white
                    : Colors.grey[200],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _getJingleRow() {
    return Row(
      children: [
        Radio(
          value: 1,
          groupValue: _selectedRadio,
          onChanged: (int? value) {
            setState(() {
              _selectedRadio = value ?? 0;
            });
          },
        ),
        Expanded(
          child: SizedBox(
            height: 37.0,
            child: InkWell(
              onTap: _openEarable.bleManager.connected
                  ? () {
                      _showSoundPicker(
                          context, _jingleMap, _jingleTextController);
                    }
                  : null,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 12.0),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _jingleTextController.text,
                      style: TextStyle(fontSize: 16.0),
                    ),
                    Icon(Icons.arrow_drop_down),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _getFrequencyRow() {
    return Row(
      children: [
        Radio(
          value: 2,
          groupValue: _selectedRadio,
          onChanged: (int? value) {
            setState(() {
              _selectedRadio = value ?? 0;
            });
          },
        ),
        SizedBox(
          height: 37.0,
          width: 80,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 0),
            child: TextField(
              controller: _audioFrequencyTextController,
              textAlign: TextAlign.end,
              style: TextStyle(
                  color: _openEarable.bleManager.connected
                      ? Colors.black
                      : Colors.grey),
              decoration: InputDecoration(
                contentPadding: EdgeInsets.all(10),
                floatingLabelBehavior: FloatingLabelBehavior.never,
                border: OutlineInputBorder(),
                labelText: '440',
                filled: true,
                labelStyle: TextStyle(
                    color: _openEarable.bleManager.connected
                        ? Colors.black
                        : Colors.grey),
                fillColor: _openEarable.bleManager.connected
                    ? Colors.white
                    : Colors.grey[200],
              ),
              keyboardType: TextInputType.number,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 5),
          child: Text(
            'Hz',
            style: TextStyle(
                color: _openEarable.bleManager.connected
                    ? Colors.white
                    : Colors.grey), // Set text color to white
          ),
        ),
        Spacer(),
        SizedBox(
          height: 37.0,
          width: 52,
          child: TextField(
            controller: _audioPercentageTextController,
            textAlign: TextAlign.end,
            autofocus: false,
            style: TextStyle(
                color: _openEarable.bleManager.connected
                    ? Colors.black
                    : Colors.grey),
            decoration: InputDecoration(
              contentPadding: EdgeInsets.all(10),
              floatingLabelBehavior: FloatingLabelBehavior.never,
              border: OutlineInputBorder(),
              labelText: '50',
              filled: true,
              isDense: true,
              counterText: "",
              labelStyle: TextStyle(
                  color: _openEarable.bleManager.connected
                      ? Colors.black
                      : Colors.grey),
              fillColor: _openEarable.bleManager.connected
                  ? Colors.white
                  : Colors.grey[200],
            ),
            maxLength: 3,
            maxLines: 1,
            keyboardType: TextInputType.number,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 5),
          child: Text(
            '%',
            style: TextStyle(
                color: _openEarable.bleManager.connected
                    ? Colors.white
                    : Colors.grey), // Set text color to white
          ),
        ),
        Spacer(),
        SizedBox(
          height: 37.0,
          width: 107,
          child: InkWell(
            onTap: _openEarable.bleManager.connected
                ? () {
                    _showSoundPicker(
                        context, _waveFormMap, _audioWaveFormTextController);
                  }
                : null,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 12.0),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _audioWaveFormTextController.text,
                    style: TextStyle(fontSize: 16.0),
                  ),
                  Icon(Icons.arrow_drop_down),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _getButtonRow() {
    return Row(
      mainAxisAlignment:
          MainAxisAlignment.spaceBetween, // Align buttons to the space between
      children: [
        SizedBox(
          width: 120,
          child: ElevatedButton(
            onPressed: _openEarable.bleManager.connected
                ? _setSourceButtonPressed
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xff53515b),
              foregroundColor: Colors.white,
            ),
            child: Text('Set Source'),
          ),
        ),
        ElevatedButton(
          onPressed:
              _openEarable.bleManager.connected ? _playButtonPressed : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: Color(0xff77F2A1),
            foregroundColor: Colors.black,
          ),
          child: Icon(Icons.play_arrow_outlined),
        ),
        ElevatedButton(
          onPressed:
              _openEarable.bleManager.connected ? _pauseButtonPressed : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: Color(0xffe0f277),
            foregroundColor: Colors.black,
          ),
          child: Icon(Icons.pause),
        ),
        ElevatedButton(
          onPressed:
              _openEarable.bleManager.connected ? _stopButtonPressed : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: Color(0xfff27777),
            foregroundColor: Colors.black,
          ),
          child: Icon(Icons.stop_outlined),
        ),
      ],
    );
  }
}
