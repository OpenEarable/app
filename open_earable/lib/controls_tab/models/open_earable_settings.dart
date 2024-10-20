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
    "62500",
  ];
  final Map<String, int> jingleMap = {
    'IDLE': 0,
    'NOTIFICATION': 1,
    'SUCCESS': 2,
    'ERROR': 3,
    'ALARM': 4,
    'PING': 5,
    'OPEN': 6,
    'CLOSE': 7,
    'CLICK': 8,
  };
  final Map<String, int> waveFormMap = {
    'SINE': 0,
    'SQUARE': 1,
    'TRIANGLE': 2,
    'SAW': 3,
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
    selectedJingle = jingleMap.keys.first;
    selectedWaveForm = waveFormMap.keys.first;
    selectedFilename = "filename.wav";
    selectedFrequency = "440";
    selectedFrequencyVolume = "50";

    selectedColor = Colors.deepPurple;
    rainbowModeActive = false;
  }

  int getWaveFormIndex(String value) {
    return waveFormMap[value] ?? 0;
  }

  int getJingleIndex(String value) {
    return jingleMap[value] ?? 0;
  }
}
