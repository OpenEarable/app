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

  List<String> pulseOximeterOptions = [
    "0",
    "30",
    "40",
    "50",
    "60",
    "70",
    "80",
    // SD settings from here
    "90",
    "100",
    "200",
    "300",
    "400",
    "500",
    "600",
    "700",
    "800",
  ];

  List<String> vitalsOptions = [
    "0",
    "1",
    "2",
    "3",
    "4",
    "5",
    "6",
    "7",
    "8",
    "9",
    "10",
  ];

  List<String> opticalTemperatureOptions = [
    "0",
    "1",
    "2",
    "3",
    "4",
    "5",
    "6",
    "7",
    "8",
    "9",
    "10",
    // SD Settings
    "20",
    "30",
    "40",
    "50",
    "60"
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

  late bool microphone1SettingSelected;
  late String selectedMicrophone1OptionBLE;
  late String selectedMicrophone1OptionSD;

  late bool microphone2SettingSelected;
  late String selectedMicrophone2OptionBLE;
  late String selectedMicrophone2OptionSD;

  late bool imuSettingSelected;
  late String selectedImuOptionBLE;
  late String selectedImuOptionSD;

  late bool pulseOximeterSettingSelected;
  late String selectedPulseOximeterOptionBLE;
  late String selectedPulseOximeterOptionSD;

  late bool vitalsSettingSelected;
  late String selectedVitalsOptionBLE;
  late String selectedVitalsOptionSD;

  late bool opticalTemperatureSettingSelected;
  late String selectedOpticalTemperatureOptionBLE;
  late String selectedOpticalTemperatureOptionSD;

  late bool barometerSettingSelected;
  late String selectedBarometerOptionBLE;
  late String selectedBarometerOptionSD;

  // Audio Player
  late int selectedAudioPlayerRadio;
  late String selectedJingle;
  late String selectedWaveForm;
  late String selectedFilename;
  late String selectedFrequency;
  late String selectedFrequencyVolume;

  late Color selectedColor;
  late bool rainbowModeActive;
  void resetState() {
    microphone1SettingSelected = false;
    selectedMicrophone1OptionBLE = "0";
    selectedMicrophone1OptionSD = "0";

    microphone2SettingSelected = false;
    selectedMicrophone2OptionBLE = "0";
    selectedMicrophone2OptionSD = "0";

    imuSettingSelected = false;
    selectedImuOptionBLE = "0";
    selectedImuOptionSD = "0";

    pulseOximeterSettingSelected = false;
    selectedPulseOximeterOptionBLE = "0";
    selectedPulseOximeterOptionSD = "0";

    vitalsSettingSelected = false;
    selectedVitalsOptionBLE = "0";
    selectedVitalsOptionSD = "0";

    opticalTemperatureSettingSelected = false;
    selectedOpticalTemperatureOptionBLE = "0";
    selectedOpticalTemperatureOptionSD = "0";

    barometerSettingSelected = false;
    selectedBarometerOptionBLE = "0";
    selectedBarometerOptionSD = "0";

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
