import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:open_earable/shared/dynamic_value_picker.dart';
import 'dart:io';
import 'package:open_earable/ble/ble_controller.dart';
import 'package:open_earable_flutter/src/open_earable_flutter.dart';
import 'package:provider/provider.dart';
import '../models/open_earable_settings.dart';

class V1SensorConfigurationCard extends StatefulWidget {
  @override
  _V1SensorConfigurationCardState createState() =>
      _V1SensorConfigurationCardState();
}

class _V1SensorConfigurationCardState extends State<V1SensorConfigurationCard> {
  late OpenEarable _openEarable;

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
        double.tryParse(OpenEarableSettings().selectedImuOption);
    double? barometerSamplingRate =
        double.tryParse(OpenEarableSettings().selectedBarometerOption);
    double? microphoneSamplingRate =
        double.tryParse(OpenEarableSettings().selectedMicrophoneOption);
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
            OpenEarableSettings().imuSettingSelected ? imuSamplingRate! : 0,
        latency: 0);
    OpenEarableSensorConfig barometerConfig = OpenEarableSensorConfig(
        sensorId: 1,
        samplingRate: OpenEarableSettings().barometerSettingSelected
            ? barometerSamplingRate!
            : 0,
        latency: 0);
    OpenEarableSensorConfig microphoneConfig = OpenEarableSensorConfig(
        sensorId: 2,
        samplingRate: OpenEarableSettings().microphoneSettingSelected
            ? microphoneSamplingRate!
            : 0,
        latency: 0);
    await _openEarable.sensorManager.writeSensorConfig(imuConfig);
    await _openEarable.sensorManager.writeSensorConfig(barometerConfig);
    await _openEarable.sensorManager.writeSensorConfig(microphoneConfig);
  }

  @override
  Widget build(BuildContext context) {
    _openEarable = Provider.of<BluetoothController>(context, listen: false)
        .openEarableLeft;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 5.0),
      child: Card(
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
                'Sensor Configuration',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18.0,
                  fontWeight: FontWeight.bold,
                ),
              ),
              _sensorConfigurationRow(
                  "IMU",
                  OpenEarableSettings().imuAndBarometerOptions,
                  OpenEarableSettings().imuSettingSelected,
                  OpenEarableSettings().selectedImuOption, (bool? newValue) {
                if (newValue != null) {
                  setState(() {
                    OpenEarableSettings().imuSettingSelected = newValue;
                  });
                }
              }, (String newValue) {
                OpenEarableSettings().selectedImuOption = newValue;
              }),
              _sensorConfigurationRow(
                  "Barometer",
                  OpenEarableSettings().imuAndBarometerOptions,
                  OpenEarableSettings().barometerSettingSelected,
                  OpenEarableSettings().selectedBarometerOption,
                  (bool? newValue) {
                if (newValue != null) {
                  setState(() {
                    OpenEarableSettings().barometerSettingSelected = newValue;
                  });
                }
              }, (String newValue) {
                OpenEarableSettings().selectedBarometerOption = newValue;
              }),
              _sensorConfigurationRow(
                  "Microphone",
                  OpenEarableSettings().microphoneOptions,
                  OpenEarableSettings().microphoneSettingSelected,
                  OpenEarableSettings().selectedMicrophoneOption,
                  (bool? newValue) {
                setState(() {
                  OpenEarableSettings().microphoneSettingSelected = newValue!;
                });
              }, (String newValue) {
                OpenEarableSettings().selectedMicrophoneOption = newValue;
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
      String currentValue,
      Function(bool?) changeBool,
      Function(String) changeSelection) {
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
                width: 100,
                height: 37,
                child: Container(
                    alignment: Alignment.centerRight,
                    child: DynamicValuePicker(
                      context,
                      options,
                      currentValue,
                      changeSelection,
                      Provider.of<BluetoothController>(context).connected,
                      false,
                    )))),
        SizedBox(width: 8),
        Text("Hz", style: TextStyle(color: Color.fromRGBO(168, 168, 172, 1.0))),
      ],
    );
  }
}
