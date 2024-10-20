import 'package:flutter/material.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart';

class OpenEarableSettingsV2 {
  static final OpenEarableSettingsV2 _instance =
      OpenEarableSettingsV2._internal();

  factory OpenEarableSettingsV2() {
    return _instance;
  }

  OpenEarableSettingsV2._internal() {
    resetState();
  }

  final List<List<String>> _imuOptions = [
    ["0", "10", "20", "30", "40", "50", "60", "70", "80"],
    ["90", "100", "200", "300", "400", "500", "600", "700", "800"],
  ];

  final List<List<String>> _barometerOptions = [
    ["0", "10", "20", "30", "40", "50", "60", "70", "80"],
    ["90", "100", "200", "300"],
  ];

  final List<List<String>> _microphoneOptions = [
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
    ["62500"],
  ];

  final List<List<String>> _pulseOximeterOptions = [
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

  final List<List<String>> _vitalsOptions = [
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
    [],
  ];

  final List<List<String>> _opticalTemperatureOptions = [
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
    ["20", "30", "40", "50", "60"],
  ];

  late SensorSettings microphone1Settings;
  late SensorSettings microphone2Settings;
  late SensorSettings imuSettings;
  late SensorSettings pulseOximeterSettings;
  late SensorSettings vitalsSettings;
  late SensorSettings opticalTemperatureSettings;
  late SensorSettings barometerSettings;

  late Color selectedColor;
  int selectedButtonIndex = 0;
  late bool rainbowModeActive;

  void resetState() {
    microphone1Settings = SensorSettings(
      frequencyOptionsBLE: _microphoneOptions[0],
      additionalOptionsSD: _microphoneOptions[1],
      sensorID: 2,
    );

    microphone2Settings = SensorSettings(
      frequencyOptionsBLE: _microphoneOptions[0],
      additionalOptionsSD: _microphoneOptions[1],
      sensorID: 3,
    );

    microphone1Settings.relatedSettings = microphone2Settings;
    microphone2Settings.relatedSettings = microphone1Settings;

    imuSettings = SensorSettings(
      frequencyOptionsBLE: _imuOptions[0],
      additionalOptionsSD: _imuOptions[1],
      sensorID: 0,
    );

    pulseOximeterSettings = SensorSettings(
      frequencyOptionsBLE: _pulseOximeterOptions[0],
      additionalOptionsSD: _pulseOximeterOptions[1],
      sensorID: 4,
    );

    vitalsSettings = SensorSettings(
      frequencyOptionsBLE: _vitalsOptions[0],
      additionalOptionsSD: _vitalsOptions[1],
      sensorID: 5,
    );

    opticalTemperatureSettings = SensorSettings(
      frequencyOptionsBLE: _opticalTemperatureOptions[0],
      additionalOptionsSD: _opticalTemperatureOptions[1],
      sensorID: 6,
    );

    barometerSettings = SensorSettings(
      frequencyOptionsBLE: _barometerOptions[0],
      additionalOptionsSD: _barometerOptions[1],
      sensorID: 1,
    );

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
  late bool isFakeDisabledBLE;
  late bool isFakeDisabledSD;
  late int sensorID;
  SensorSettings? relatedSettings;

  SensorSettings({
    required this.frequencyOptionsBLE,
    required additionalOptionsSD,
    required this.sensorID,
    this.sensorSelected = false,
    this.selectedOptionBLE = "0",
    this.selectedOptionSD = "0",
    this.isFakeDisabledBLE = false,
    this.isFakeDisabledSD = false,
    this.relatedSettings,
  }) {
    frequencyOptionsSD = frequencyOptionsBLE + additionalOptionsSD;
  }

  OpenEarableSensorConfig getSensorConfigBLE() {
    double? samplingRate =
        sensorSelected ? double.tryParse(selectedOptionBLE) : 0;
    return OpenEarableSensorConfig(
      sensorId: sensorID,
      samplingRate: samplingRate ?? 0,
      latency: 0,
    );
  }

  void updateSelectedBLEOption(String option) {
    selectedOptionBLE = option;
    if (relatedSettings != null) {
      if (option != "0") {
        isFakeDisabledBLE = false;
        selectedOptionSD = "0";
        isFakeDisabledSD = true;
        relatedSettings!.selectedOptionBLE = "0";
        relatedSettings!.isFakeDisabledBLE = true;
        relatedSettings!.isFakeDisabledSD = false;
      } else {
        isFakeDisabledSD = false;
        if (relatedSettings!.selectedOptionSD == "0") {
          relatedSettings!.isFakeDisabledBLE = false;
        }
      }
      relatedSettings!.notifyListeners();
      relatedSettings!.onValuesChanged();
    }
    notifyListeners();
    onValuesChanged();
  }

  void updateSelectedSDOption(String option) {
    selectedOptionSD = option;
    if (relatedSettings != null) {
      if (option != "0") {
        isFakeDisabledSD = false;
        selectedOptionBLE = "0";
        isFakeDisabledBLE = true;
        if (relatedSettings!.selectedOptionSD == "0") {
          relatedSettings!.isFakeDisabledBLE = false;
        }
      } else if (relatedSettings!.selectedOptionBLE == "0") {
        isFakeDisabledBLE = false;
      }
      relatedSettings!.notifyListeners();
      relatedSettings!.onValuesChanged();
    }
    notifyListeners();
    onValuesChanged();
  }

  void onValuesChanged() {
    if (sensorSelected) {
      if (selectedOptionBLE == "0" && selectedOptionSD == "0") {
        sensorSelected = false;
      }
    } else {
      if (selectedOptionBLE != "0" || selectedOptionSD != "0") {
        sensorSelected = true;
      }
    }
  }
}
