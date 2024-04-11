import 'package:flutter/material.dart';

class OpenEarableSettingsV2 {
  static final OpenEarableSettingsV2 _instance =
      OpenEarableSettingsV2._internal();
  factory OpenEarableSettingsV2() {
    return _instance;
  }
  OpenEarableSettingsV2._internal() {
    resetState();
  }

  List<String> imuAndBarometerOptions = ["0", "10", "20", "30"];

  List<String> microphoneOptions = [
    "0",
    "8000",
    "11025",
    "16000",
    "22050",
    "44100",
    "48000",
    "62500"
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
  late bool microphone1SettingSelected;
  late bool microphone2SettingSelected;
  late String selectedImuOptionBLE;
  late String selectedImuOptionSD;
  late String selectedBarometerOptionBLE;
  late String selectedBarometerOptionSD;

  late String selectedMicrophone1OptionBLE;
  late String selectedMicrophone1OptionSD;
  late String selectedMicrophone2OptionBLE;
  late String selectedMicrophone2OptionSD;

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
    microphone1SettingSelected = false;
    microphone2SettingSelected = false;
    selectedImuOptionBLE = "0";
    selectedImuOptionSD = "0";
    selectedBarometerOptionBLE = "0";
    selectedBarometerOptionSD = "0";
    selectedMicrophone1OptionBLE = "0";
    selectedMicrophone1OptionSD = "0";
    selectedMicrophone2OptionBLE = "0";
    selectedMicrophone2OptionSD = "0";

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
