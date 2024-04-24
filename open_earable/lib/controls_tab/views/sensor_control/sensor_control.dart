import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'dart:io';
import 'package:open_earable/ble/ble_controller.dart';
import 'sensor_control_row.dart';
import 'package:open_earable_flutter/src/open_earable_flutter.dart';
import 'package:provider/provider.dart';
import '../../models/open_earable_settings_v2.dart';

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
        double.tryParse(OpenEarableSettingsV2().imuSettings.selectedOptionBLE);
    double? barometerSamplingRate = double.tryParse(
        OpenEarableSettingsV2().barometerSettings.selectedOptionBLE);
    double? microphone1SamplingRate = double.tryParse(
        OpenEarableSettingsV2().microphone1Settings.selectedOptionBLE);
    double? microphone2SamplingRate = double.tryParse(
        OpenEarableSettingsV2().microphone2Settings.selectedOptionBLE);
    double? pulseOximeterSamplingRate = double.tryParse(
        OpenEarableSettingsV2().pulseOximeterSettings.selectedOptionBLE);

    OpenEarableSensorConfig imuConfig = OpenEarableSensorConfig(
        sensorId: 0,
        samplingRate: OpenEarableSettingsV2().imuSettings.sensorSelected
            ? imuSamplingRate!
            : 0,
        latency: 0);
    OpenEarableSensorConfig barometerConfig = OpenEarableSensorConfig(
        sensorId: 1,
        samplingRate: OpenEarableSettingsV2().barometerSettings.sensorSelected
            ? barometerSamplingRate!
            : 0,
        latency: 0);
    OpenEarableSensorConfig microphoneConfig = OpenEarableSensorConfig(
        sensorId: 2,
        samplingRate: OpenEarableSettingsV2().microphone1Settings.sensorSelected
            ? microphone1SamplingRate!
            : 0,
        latency: 0);
    OpenEarableSensorConfig microphone2Config = OpenEarableSensorConfig(
        sensorId: 3,
        samplingRate: OpenEarableSettingsV2().microphone2Settings.sensorSelected
            ? microphone2SamplingRate!
            : 0,
        latency: 0);
    await _openEarable.sensorManager.writeSensorConfig(imuConfig);
    await _openEarable.sensorManager.writeSensorConfig(barometerConfig);
    await _openEarable.sensorManager.writeSensorConfig(microphoneConfig);
    await _openEarable.sensorManager.writeSensorConfig(microphone2Config);
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
              ChangeNotifierProvider<SensorSettings>(
                  create: (_) => OpenEarableSettingsV2().microphone1Settings,
                  child: SensorControlRow("Microphone 1")),
              SizedBox(height: 4),
              ChangeNotifierProvider<SensorSettings>(
                  create: (context) =>
                      OpenEarableSettingsV2().microphone2Settings,
                  child: SensorControlRow("Microphone 2")),
              Divider(
                color: Color.fromRGBO(168, 168, 172, 1.0),
              ),
              ChangeNotifierProvider<SensorSettings>(
                  create: (context) => OpenEarableSettingsV2().imuSettings,
                  child: SensorControlRow("9-Axis IMU")),
              SizedBox(height: 4),
              ChangeNotifierProvider<SensorSettings>(
                  create: (context) =>
                      OpenEarableSettingsV2().pulseOximeterSettings,
                  child: SensorControlRow("Pulse Oximeter\n(Red/Infrared)")),
              SizedBox(height: 4),
              ChangeNotifierProvider<SensorSettings>(
                  create: (context) => OpenEarableSettingsV2().vitalsSettings,
                  child: SensorControlRow("Heart Rate,\nSpO2")),
              SizedBox(height: 4),
              ChangeNotifierProvider<SensorSettings>(
                  create: (context) =>
                      OpenEarableSettingsV2().opticalTemperatureSettings,
                  child: SensorControlRow("Optical Temp.\n(Surface)")),
              SizedBox(height: 4),
              ChangeNotifierProvider<SensorSettings>(
                  create: (context) =>
                      OpenEarableSettingsV2().barometerSettings,
                  child: SensorControlRow("Pressure,\nTemp. (Ambient)")),
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
}
