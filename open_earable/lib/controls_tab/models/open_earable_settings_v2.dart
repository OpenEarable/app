import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class OpenEarableSettingsV2 {
  static final OpenEarableSettingsV2 _instance =
      OpenEarableSettingsV2._internal();
  factory OpenEarableSettingsV2() {
    return _instance;
  }
  OpenEarableSettingsV2._internal() {
    resetState();
  }

  List<List<String>> _imuOptions = [
    ["0", "10", "20", "30", "40", "50", "60", "70", "80"],
    ["90", "100", "200", "300", "400", "500", "600", "700", "800"]
  ];

  List<List<String>> _barometerOptions = [
    ["0", "10", "20", "30", "40", "50", "60", "70", "80"],
    ["90", "100", "200", "300"]
  ];

  List<List<String>> _microphoneOptions = [
    // BLE Options
    [
      "0",
      "8000",
      "11025",
      "16000",
      "22050",
      "44100",
      "48000",
    ],
    // additional SD options
    ["62500"]
  ];

  List<List<String>> _pulseOximeterOptions = [
    [
      "0",
      "30",
      "40",
      "50",
      "60",
      "70",
      "80",
    ],
    [
      "90",
      "100",
      "200",
      "300",
      "400",
      "500",
      "600",
      "700",
      "800",
    ]
  ];

  List<List<String>> _vitalsOptions = [
    [
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
    ],
    []
  ];

  List<List<String>> _opticalTemperatureOptions = [
    [
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
    ],
    ["20", "30", "40", "50", "60"]
  ];

  late SensorSettings microphone1Settings;
  late SensorSettings microphone2Settings;
  late SensorSettings imuSettings;
  late SensorSettings pulseOximeterSettings;
  late SensorSettings vitalsSettings;
  late SensorSettings opticalTemperatureSettings;
  late SensorSettings barometerSettings;

  late Color selectedColor;
  late bool rainbowModeActive;
  void resetState() {
    microphone1Settings = SensorSettings(
        frequencyOptionsBLE: _microphoneOptions[0],
        additionalOptionsSD: _microphoneOptions[1]);

    microphone2Settings = SensorSettings(
        frequencyOptionsBLE: _microphoneOptions[0],
        additionalOptionsSD: _microphoneOptions[1]);

    imuSettings = SensorSettings(
        frequencyOptionsBLE: _imuOptions[0],
        additionalOptionsSD: _imuOptions[1]);

    pulseOximeterSettings = SensorSettings(
        frequencyOptionsBLE: _pulseOximeterOptions[0],
        additionalOptionsSD: _pulseOximeterOptions[1]);

    vitalsSettings = SensorSettings(
        frequencyOptionsBLE: _vitalsOptions[0],
        additionalOptionsSD: _vitalsOptions[1]);

    opticalTemperatureSettings = SensorSettings(
        frequencyOptionsBLE: _opticalTemperatureOptions[0],
        additionalOptionsSD: _opticalTemperatureOptions[1]);

    barometerSettings = SensorSettings(
        frequencyOptionsBLE: _barometerOptions[0],
        additionalOptionsSD: _barometerOptions[1]);

    selectedColor = Colors.deepPurple;
    rainbowModeActive = false;
  }
}

class SensorSettings extends ChangeNotifier {
  late List<String> frequencyOptionsBLE;
  late List<String> frequencyOptionsSD;
  late bool sensorSelected;
  late String selectedOptionBLE;
  late String selectedOptionSD;

  SensorSettings(
      {required frequencyOptionsBLE,
      required additionalOptionsSD,
      sensorSelected = false,
      selectedOptionBLE = "0",
      selectedOptionSD = "0"}) {
    this.frequencyOptionsBLE = frequencyOptionsBLE;
    this.frequencyOptionsSD = frequencyOptionsBLE + additionalOptionsSD;
    this.sensorSelected = sensorSelected;
    this.selectedOptionBLE = selectedOptionBLE;
    this.selectedOptionSD = selectedOptionSD;
  }
  void updateSensorSelected(bool? selected) {
    if (selected == null) {
      return;
    }
    this.sensorSelected = selected;
    notifyListeners();
  }

  void updateSelectedBLEOption(String option) {
    this.selectedOptionBLE = option;
    _onValueChanged();
    notifyListeners();
  }

  void updateSelectedSDOption(String option) {
    this.selectedOptionSD = option;
    _onValueChanged();
    notifyListeners();
  }

  void _onValueChanged() {
    if (this.sensorSelected) {
      if (this.selectedOptionBLE == "0" && this.selectedOptionSD == "0") {
        updateSensorSelected(false);
      }
    } else {
      if (this.selectedOptionBLE != "0" || this.selectedOptionSD != "0") {
        updateSensorSelected(true);
      }
    }
  }
}
