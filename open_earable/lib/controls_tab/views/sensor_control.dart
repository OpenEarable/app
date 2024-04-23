import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:open_earable/shared/dynamic_value_picker.dart';
import 'dart:io';
import 'package:open_earable/ble/ble_controller.dart';
import 'package:open_earable_flutter/src/open_earable_flutter.dart';
import 'package:provider/provider.dart';
import '../models/open_earable_settings_v2.dart';

class SensorControlCard extends StatefulWidget {
  final OpenEarable _openEarable;
  SensorControlCard(this._openEarable);

  @override
  _SensorControlCardState createState() =>
      _SensorControlCardState(_openEarable);
}

class _SensorControlCardState extends State<SensorControlCard> {
  final OpenEarable _openEarable;
  _SensorControlCardState(this._openEarable);

  void initState() {
    super.initState();
  }

  Color _getCheckboxColor(Set<MaterialState> states) {
    const Set<MaterialState> interactiveStates = <MaterialState>{
      MaterialState.pressed,
      MaterialState.hovered,
      MaterialState.focused,
      MaterialState.selected,
    };
    if (states.any(interactiveStates.contains)) {
      return Theme.of(context).colorScheme.secondary;
    }
    return Theme.of(context).colorScheme.primary;
  }

  void _showErrorDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Invalid sampling rates'),
          content: Text(
              'Please ensure that sampling rates of IMU and Barometer are not greater than 30 Hz'),
          actions: <Widget>[
            TextButton(
              child: Text('OK'),
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _writeSensorConfigs() async {
    double? imuSamplingRate =
        double.tryParse(OpenEarableSettingsV2().selectedImuOptionBLE);
    double? barometerSamplingRate =
        double.tryParse(OpenEarableSettingsV2().selectedBarometerOptionBLE);
    double? microphoneSamplingRate =
        double.tryParse(OpenEarableSettingsV2().selectedMicrophone1OptionBLE);
    if (imuSamplingRate == null ||
        barometerSamplingRate == null ||
        microphoneSamplingRate == null ||
        imuSamplingRate > 30 ||
        imuSamplingRate < 0 ||
        barometerSamplingRate > 30 ||
        barometerSamplingRate < 0) {
      _showErrorDialog(context);
    }
    OpenEarableSensorConfig imuConfig = OpenEarableSensorConfig(
        sensorId: 0,
        samplingRate:
            OpenEarableSettingsV2().imuSettingSelected ? imuSamplingRate! : 0,
        latency: 0);
    OpenEarableSensorConfig barometerConfig = OpenEarableSensorConfig(
        sensorId: 1,
        samplingRate: OpenEarableSettingsV2().barometerSettingSelected
            ? barometerSamplingRate!
            : 0,
        latency: 0);
    OpenEarableSensorConfig microphoneConfig = OpenEarableSensorConfig(
        sensorId: 2,
        samplingRate: OpenEarableSettingsV2().microphone1SettingSelected
            ? microphoneSamplingRate!
            : 0,
        latency: 0);
    await _openEarable.sensorManager.writeSensorConfig(imuConfig);
    await _openEarable.sensorManager.writeSensorConfig(barometerConfig);
    await _openEarable.sensorManager.writeSensorConfig(microphoneConfig);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 5.0),
      child: Card(
        //Audio Player Card
        color: Platform.isIOS
            ? CupertinoTheme.of(context).primaryContrastingColor
            : Theme.of(context).colorScheme.primary,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Sensor Control',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18.0,
                  fontWeight: FontWeight.bold,
                ),
              ),
              _sensorConfigurationRow(
                  "Microphone 1",
                  OpenEarableSettingsV2().microphoneOptions,
                  OpenEarableSettingsV2().microphone1SettingSelected,
                  OpenEarableSettingsV2().selectedMicrophone1OptionBLE,
                  OpenEarableSettingsV2().selectedMicrophone1OptionSD,
                  (bool? newValue) {
                setState(() {
                  OpenEarableSettingsV2().microphone1SettingSelected =
                      newValue!;
                });
              }, (String newValue) {
                OpenEarableSettingsV2().selectedMicrophone1OptionBLE = newValue;
              }, (String newValue) {
                OpenEarableSettingsV2().selectedMicrophone1OptionSD = newValue;
              }),
              SizedBox(height: 4),
              _sensorConfigurationRow(
                  "Microphone 2",
                  OpenEarableSettingsV2().microphoneOptions,
                  OpenEarableSettingsV2().microphone2SettingSelected,
                  OpenEarableSettingsV2().selectedMicrophone2OptionBLE,
                  OpenEarableSettingsV2().selectedMicrophone2OptionSD,
                  (bool? newValue) {
                setState(() {
                  OpenEarableSettingsV2().microphone2SettingSelected =
                      newValue!;
                });
              }, (String newValue) {
                OpenEarableSettingsV2().selectedMicrophone2OptionBLE = newValue;
              }, (String newValue) {
                OpenEarableSettingsV2().selectedMicrophone2OptionSD = newValue;
              }),
              Divider(
                color: Color.fromRGBO(168, 168, 172, 1.0),
              ),
              _sensorConfigurationRow(
                  "9-Axis IMU",
                  OpenEarableSettingsV2().imuAndBarometerOptions,
                  OpenEarableSettingsV2().imuSettingSelected,
                  OpenEarableSettingsV2().selectedImuOptionBLE,
                  OpenEarableSettingsV2().selectedImuOptionSD,
                  (bool? newValue) {
                if (newValue != null) {
                  setState(() {
                    OpenEarableSettingsV2().imuSettingSelected = newValue;
                  });
                }
              }, (String newValue) {
                OpenEarableSettingsV2().selectedImuOptionBLE = newValue;
              }, (String newValue) {
                OpenEarableSettingsV2().selectedImuOptionSD = newValue;
              }),
              SizedBox(height: 4),
              _sensorConfigurationRow(
                  "Pulse Oximeter\n(Red/Infrared)",
                  OpenEarableSettingsV2().pulseOximeterOptions,
                  OpenEarableSettingsV2().pulseOximeterSettingSelected,
                  OpenEarableSettingsV2().selectedPulseOximeterOptionBLE,
                  OpenEarableSettingsV2().selectedPulseOximeterOptionSD,
                  (bool? newValue) {
                if (newValue != null) {
                  setState(() {
                    OpenEarableSettingsV2().pulseOximeterSettingSelected =
                        newValue;
                  });
                }
              }, (String newValue) {
                OpenEarableSettingsV2().selectedPulseOximeterOptionBLE =
                    newValue;
              }, (String newValue) {
                OpenEarableSettingsV2().selectedPulseOximeterOptionSD =
                    newValue;
              }),
              SizedBox(height: 4),
              _sensorConfigurationRow(
                  "Heart Rate,\nSpO2",
                  OpenEarableSettingsV2().vitalsOptions,
                  OpenEarableSettingsV2().vitalsSettingSelected,
                  OpenEarableSettingsV2().selectedVitalsOptionBLE,
                  OpenEarableSettingsV2().selectedVitalsOptionSD,
                  (bool? newValue) {
                if (newValue != null) {
                  setState(() {
                    OpenEarableSettingsV2().vitalsSettingSelected = newValue;
                  });
                }
              }, (String newValue) {
                OpenEarableSettingsV2().selectedVitalsOptionBLE = newValue;
              }, (String newValue) {
                OpenEarableSettingsV2().selectedVitalsOptionSD = newValue;
              }),
              SizedBox(height: 4),
              _sensorConfigurationRow(
                  "Optical Temp.\n(Surface)",
                  OpenEarableSettingsV2().opticalTemperatureOptions,
                  OpenEarableSettingsV2().opticalTemperatureSettingSelected,
                  OpenEarableSettingsV2().selectedOpticalTemperatureOptionBLE,
                  OpenEarableSettingsV2().selectedOpticalTemperatureOptionSD,
                  (bool? newValue) {
                if (newValue != null) {
                  setState(() {
                    OpenEarableSettingsV2().opticalTemperatureSettingSelected =
                        newValue;
                  });
                }
              }, (String newValue) {
                OpenEarableSettingsV2().selectedOpticalTemperatureOptionBLE =
                    newValue;
              }, (String newValue) {
                OpenEarableSettingsV2().selectedBarometerOptionSD = newValue;
              }),
              SizedBox(height: 4),
              _sensorConfigurationRow(
                  "Pressure,\nTemp. (Ambient)",
                  OpenEarableSettingsV2().imuAndBarometerOptions,
                  OpenEarableSettingsV2().barometerSettingSelected,
                  OpenEarableSettingsV2().selectedBarometerOptionBLE,
                  OpenEarableSettingsV2().selectedBarometerOptionSD,
                  (bool? newValue) {
                if (newValue != null) {
                  setState(() {
                    OpenEarableSettingsV2().barometerSettingSelected = newValue;
                  });
                }
              }, (String newValue) {
                OpenEarableSettingsV2().selectedBarometerOptionBLE = newValue;
              }, (String newValue) {
                OpenEarableSettingsV2().selectedBarometerOptionSD = newValue;
              }),
              SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 37,
                      child: Platform.isIOS
                          ? CupertinoButton(
                              padding: EdgeInsets.zero,
                              onPressed:
                                  Provider.of<BluetoothController>(context)
                                          .connected
                                      ? () => _writeSensorConfigs()
                                      : null,
                              color: Provider.of<BluetoothController>(context)
                                      .connected
                                  ? CupertinoTheme.of(context).primaryColor
                                  : Colors.grey,
                              child: Text("Set Configuration"),
                            )
                          : ElevatedButton(
                              onPressed:
                                  Provider.of<BluetoothController>(context)
                                          .connected
                                      ? _writeSensorConfigs
                                      : null,
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    Provider.of<BluetoothController>(context)
                                            .connected
                                        ? Theme.of(context)
                                            .colorScheme
                                            .secondary
                                        : Colors.grey,
                                foregroundColor: Colors.black,
                                enableFeedback:
                                    Provider.of<BluetoothController>(context)
                                        .connected,
                              ),
                              child: Text("Set Configuration"),
                            ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sensorConfigurationRow(
      String sensorName,
      List<String> options,
      bool settingSelected,
      String currentValueBLE,
      String currentValueSD,
      Function(bool?) changeBool,
      Function(String) changeSelectionBLE,
      Function(String) changeSelectionSD) {
    return Row(
      children: [
        Platform.isIOS
            ? CupertinoCheckbox(
                value: settingSelected,
                onChanged: Provider.of<BluetoothController>(context).connected
                    ? changeBool
                    : null,
                activeColor: settingSelected
                    ? CupertinoTheme.of(context).primaryColor
                    : CupertinoTheme.of(context).primaryContrastingColor,
                checkColor: CupertinoTheme.of(context).primaryContrastingColor,
              )
            : Checkbox(
                checkColor: Theme.of(context).colorScheme.primary,
                fillColor: MaterialStateProperty.resolveWith(_getCheckboxColor),
                value: settingSelected,
                onChanged: Provider.of<BluetoothController>(context).connected
                    ? changeBool
                    : null,
              ),
        Text(
          sensorName,
          style: TextStyle(
            color: Color.fromRGBO(168, 168, 172, 1.0),
          ),
        ),
        Spacer(),
        Container(
            decoration: BoxDecoration(
              color: Provider.of<BluetoothController>(context).connected
                  ? Colors.white
                  : Colors.grey[200],
              borderRadius: BorderRadius.circular(4.0),
            ),
            child: SizedBox(
                width: 70,
                height: 37,
                child: Container(
                    alignment: Alignment.centerRight,
                    child: DynamicValuePicker(
                      context,
                      options,
                      currentValueBLE,
                      changeSelectionBLE,
                      changeBool,
                      Provider.of<BluetoothController>(context).connected,
                    )))),
        SizedBox(width: 8),
        Container(
            decoration: BoxDecoration(
              color: Provider.of<BluetoothController>(context).connected
                  ? Colors.white
                  : Colors.grey[200],
              borderRadius: BorderRadius.circular(4.0),
            ),
            child: SizedBox(
                width: 70,
                height: 37,
                child: Container(
                    alignment: Alignment.centerRight,
                    child: DynamicValuePicker(
                      context,
                      options,
                      currentValueSD,
                      changeSelectionSD,
                      changeBool,
                      Provider.of<BluetoothController>(context).connected,
                    )))),
        SizedBox(width: 8),
        Text("Hz", style: TextStyle(color: Color.fromRGBO(168, 168, 172, 1.0))),
      ],
    );
  }
}
