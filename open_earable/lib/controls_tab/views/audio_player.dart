import 'package:flutter/material.dart';
import 'package:open_earable/ble/ble_controller.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart';
import 'package:provider/provider.dart';
import '../models/open_earable_settings.dart';
import '../../shared/dynamic_value_picker.dart';

class AudioPlayerCard extends StatelessWidget {
  const AudioPlayerCard({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<BluetoothController>(
      builder: (context, bleController, child) {
        return _InternalAudioPlayerCard(
          openEarable: bleController.currentOpenEarable,
          connected: bleController.currentOpenEarable.bleManager.connected,
        );
      },
    );
  }
}

class _InternalAudioPlayerCard extends StatefulWidget {
  final OpenEarable openEarable;
  final bool connected;

  const _InternalAudioPlayerCard({
    required this.openEarable,
    required this.connected,
  });

  @override
  State<_InternalAudioPlayerCard> createState() =>
      _InternalAudioPlayerCardState();
}

class _InternalAudioPlayerCardState extends State<_InternalAudioPlayerCard> {
  late TextEditingController _filenameTextController;

  late TextEditingController _frequencyTextController;
  late TextEditingController _frequencyVolumeTextController;
  late TextEditingController _waveFormTextController;

  @override
  void initState() {
    super.initState();
    _filenameTextController = TextEditingController(
      text: OpenEarableSettings().selectedFilename,
    );
    _frequencyTextController = TextEditingController(
      text: OpenEarableSettings().selectedFrequency,
    );
    _frequencyVolumeTextController = TextEditingController(
      text: OpenEarableSettings().selectedFrequencyVolume,
    );
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
    widget.openEarable.audioPlayer.setState(AudioPlayerState.start);
  }

  void _pauseButtonPressed() {
    widget.openEarable.audioPlayer.setState(AudioPlayerState.pause);
  }

  void _stopButtonPressed() {
    widget.openEarable.audioPlayer.setState(AudioPlayerState.stop);
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
    String jingleName = OpenEarableSettings().selectedJingle;
    int jingleIndex = OpenEarableSettings().jingleMap[jingleName]!;
    print("Setting source to jingle '$jingleName' with index $jingleIndex");
    widget.openEarable.audioPlayer.jingle(jingleIndex);
  }

  void _setWAV() {
    String fileName = _filenameTextController.text;

    if (fileName == "") {
      _showAlert("Empty file name", "WAV file name is empty!", "Dismiss");
      return;
    } else if (!fileName.endsWith('.wav')) {
      _showAlert(
        "Missing '.wav' ending",
        "WAV file name is missing the '.wav' ending!",
        "Dismiss",
      );
      return;
    }
    print("Setting source to wav file with file name '$fileName'");
    widget.openEarable.audioPlayer.wavFile(_filenameTextController.text);
  }

  void _setFrequencySound() {
    double frequency = double.tryParse(_frequencyTextController.text) ?? 440.0;
    int waveForm =
        OpenEarableSettings().getWaveFormIndex(_waveFormTextController.text);
    double loudness =
        (double.tryParse(_frequencyVolumeTextController.text) ?? 100.0) / 100.0;

    if ((frequency < 0 || frequency > 30000) ||
        (loudness < 0 || loudness > 100)) {
      _showAlert(
        "Invalid value(s)",
        "Invalid frequency range or loudness!",
        "Dismiss",
      );
      return;
    }

    print(
      "Setting source with frequency value $frequency' Hz, wave type '$waveForm', and loudness '$loudness'.",
    );
    widget.openEarable.audioPlayer.frequency(waveForm, frequency, loudness);
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

  @override
  Widget build(BuildContext context) {
    updateText(widget.connected);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 5.0),
      child: Card(
        //Audio Player Card
        color: Theme.of(context).colorScheme.primary,
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
              _getMaterialButtonRow(widget.connected),
            ],
          ),
        ),
      ),
    );
  }

  Widget _getAudioPlayerRadio(int index) {
    return SizedBox(
      height: 38,
      width: 44,
      child: Radio(
        value: index,
        groupValue: OpenEarableSettings().selectedAudioPlayerRadio,
        onChanged: !widget.connected
            ? null
            : (int? value) {
                setState(() {
                  OpenEarableSettings().selectedAudioPlayerRadio = value ?? 0;
                });
              },
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return Theme.of(context).colorScheme.secondary;
          }
          return Colors.grey;
        }),
      ),
    );
  }

  Widget _getFileNameRow() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(44, 0, 0, 0),
          child: Text(
            "Audio File",
            style: TextStyle(
              color: Color.fromRGBO(168, 168, 172, 1.0),
            ),
          ),
        ),
        Row(
          children: [
            _getAudioPlayerRadio(0),
            Expanded(
              child: SizedBox(
                height: 38.0,
                child: _fileNameTextField(
                  _filenameTextController,
                  TextInputType.text,
                  null,
                  null,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _fileNameTextField(
    TextEditingController textController,
    TextInputType keyboardType,
    String? placeholder,
    int? maxLength,
  ) {
    return TextField(
      controller: textController,
      obscureText: false,
      enabled: widget.connected,
      style:
          TextStyle(color: widget.connected ? Colors.black : Colors.grey[700]),
      decoration: InputDecoration(
        labelText: placeholder,
        contentPadding: EdgeInsets.fromLTRB(8, 0, 0, 0),
        border: OutlineInputBorder(),
        floatingLabelBehavior: FloatingLabelBehavior.never,
        labelStyle: TextStyle(
          color: widget.connected ? Colors.black : Colors.grey[700],
        ),
        filled: true,
        fillColor: widget.connected ? Colors.white : Colors.grey,
      ),
      keyboardType: keyboardType,
      maxLength: maxLength,
      maxLines: 1,
    );
  }

  Widget _getJingleRow() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(44, 8, 0, 0),
          child: Text(
            "Jingle",
            style: TextStyle(
              color: Color.fromRGBO(168, 168, 172, 1.0),
            ),
          ),
        ),
        Row(
          children: [
            _getAudioPlayerRadio(1),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: widget.connected ? Colors.white : Colors.grey,
                  borderRadius: BorderRadius.circular(4.0),
                ),
                child: SizedBox(
                  height: 40,
                  child: DynamicValuePicker(
                    context,
                    OpenEarableSettings().jingleMap.keys.toList(),
                    OpenEarableSettings().selectedJingle,
                    (newValue) {
                      setState(() {
                        OpenEarableSettings().selectedJingle = newValue;
                      });
                    },
                    widget.connected,
                    false,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _getFrequencyRow() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(44, 8, 0, 0),
          child: Text(
            "Frequency",
            style: TextStyle(
              color: Color.fromRGBO(168, 168, 172, 1.0),
            ),
          ),
        ),
        Row(
          children: [
            _getAudioPlayerRadio(2),
            SizedBox(
              height: 38.0,
              width: 75,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 0),
                child: _fileNameTextField(
                  _frequencyTextController,
                  TextInputType.number,
                  "440",
                  null,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 5),
              child: Text(
                'Hz',
                style: TextStyle(
                  color: widget.connected ? Colors.white : Colors.grey,
                ), // Set text color to white
              ),
            ),
            Spacer(),
            SizedBox(
              height: 38.0,
              width: 52,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 0),
                child: _fileNameTextField(
                  _frequencyVolumeTextController,
                  TextInputType.number,
                  "50",
                  null,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 5),
              child: Text(
                '%',
                style: TextStyle(
                  color: widget.connected ? Colors.white : Colors.grey,
                ), // Set text color to white
              ),
            ),
            Spacer(),
            Container(
              decoration: BoxDecoration(
                color: widget.connected ? Colors.white : Colors.grey,
                borderRadius: BorderRadius.circular(4.0),
              ),
              child: SizedBox(
                height: 38.0,
                width: 107,
                child: DynamicValuePicker(
                  context,
                  OpenEarableSettings().waveFormMap.keys.toList(),
                  OpenEarableSettings().selectedWaveForm,
                  (newValue) {
                    setState(
                      () {
                        OpenEarableSettings().selectedWaveForm = newValue;
                      },
                    );
                  },
                  widget.connected,
                  false,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _getMaterialButtonRow(bool connected) {
    return Row(
      mainAxisAlignment:
          MainAxisAlignment.spaceBetween, // Align buttons to the space between
      children: [
        SizedBox(
          width: 120,
          child: ElevatedButton(
            onPressed: connected ? _setSourceButtonPressed : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xff53515b),
              foregroundColor: Colors.white,
            ),
            child: Text('Set Source'),
          ),
        ),
        ElevatedButton(
          onPressed: connected ? _playButtonPressed : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: Color(0xff77F2A1),
            foregroundColor: Colors.black,
          ),
          child: Icon(Icons.play_arrow_outlined),
        ),
        ElevatedButton(
          onPressed: connected ? _pauseButtonPressed : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: Color(0xffe0f277),
            foregroundColor: Colors.black,
          ),
          child: Icon(Icons.pause),
        ),
        ElevatedButton(
          onPressed: connected ? _stopButtonPressed : null,
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
