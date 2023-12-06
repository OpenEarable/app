import 'package:flutter/material.dart';

class OpenEarableSettings {
  static final OpenEarableSettings _instance = OpenEarableSettings._internal();
  factory OpenEarableSettings() {
    return _instance;
  }
  OpenEarableSettings._internal() {
    resetState();
  }

  List<String> imuAndBarometerOptions = ["0", "10", "20", "30"];
  List<String> microphoneOptions = [
    "0",
    "16000",
    "20000",
    "25000",
    "31250",
    "33333",
    "40000",
    "41667",
    "50000",
    "62500"
  ];
  final Map<int, String> jingleMap = {
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
  final Map<int, String> waveFormMap = {
    1: 'SINE',
    2: 'SQUARE',
    3: 'TRIANGLE',
    4: 'SAW',
  };

  late bool imuSettingSelected;
  late bool barometerSettingSelected;
  late bool microphoneSettingSelected;
  late String selectedImuOption;
  late String selectedBarometerOption;
  late String selectedMicrophoneOption;

  late int selectedAudioPlayerRadio;
  late String selectedJingle;
  late String selectedWaveForm;
  late String selectedFilename;
  late String selectedFrequency;
  late String selectedFrequencyVolume;

  late Color selectedColor;
  late bool rainbowModeActive;
  void resetState() {
    imuSettingSelected = false;
    barometerSettingSelected = false;
    microphoneSettingSelected = false;
    selectedImuOption = "0";
    selectedBarometerOption = "0";
    selectedMicrophoneOption = "0";

    selectedAudioPlayerRadio = 0;
    selectedJingle = jingleMap[1]!;
    selectedWaveForm = waveFormMap[1]!;
    selectedFilename = "filename.wav";
    selectedFrequency = "440";
    selectedFrequencyVolume = "50";

    selectedColor = Colors.deepPurple;
    rainbowModeActive = false;
  }

  int getWaveFormIndex(String value) {
    return _getKeyFromValue(value, waveFormMap);
  }

  int getJingleIndex(String value) {
    return _getKeyFromValue(value, jingleMap);
  }

  int _getKeyFromValue(String value, Map<int, String> map) {
    for (var entry in map.entries) {
      if (entry.value == value) {
        return entry.key;
      }
    }
    return 1;
  }
}
