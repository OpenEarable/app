import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'dart:io';
import 'package:open_earable/ble/ble_controller.dart';
import 'sensor_control_row.dart';
import 'package:open_earable_flutter/src/open_earable_flutter.dart';
import 'package:provider/provider.dart';
import '../../models/open_earable_settings_v2.dart';

class SensorControlCard extends StatefulWidget {
  SensorControlCard();

  @override
  _SensorControlCardState createState() => _SensorControlCardState();
}

class _SensorControlCardState extends State<SensorControlCard> {
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
    OpenEarable leftOpenEarable =
        Provider.of<BluetoothController>(context, listen: false)
            .openEarableLeft;
    OpenEarable rightOpenEarable =
        Provider.of<BluetoothController>(context, listen: false)
            .openEarableRight;

    OpenEarableSettingsV2 settings = OpenEarableSettingsV2();

    OpenEarableSensorConfig imuConfig =
        settings.imuSettings.getSensorConfigBLE();
    OpenEarableSensorConfig barometerConfig =
        settings.barometerSettings.getSensorConfigBLE();
    OpenEarableSensorConfig opticalTemperatureSensorConfig =
        settings.opticalTemperatureSettings.getSensorConfigBLE();
    OpenEarableSensorConfig microphone1Config =
        settings.microphone1Settings.getSensorConfigBLE();
    OpenEarableSensorConfig microphone2Config =
        settings.microphone2Settings.getSensorConfigBLE();
    OpenEarableSensorConfig pulseOximeterConfig =
        settings.pulseOximeterSettings.getSensorConfigBLE();
    OpenEarableSensorConfig vitalsConfig =
        settings.vitalsSettings.getSensorConfigBLE();
    if (leftOpenEarable.bleManager.connected) {
      await leftOpenEarable.sensorManager.writeSensorConfig(imuConfig);
      await leftOpenEarable.sensorManager.writeSensorConfig(barometerConfig);
      await leftOpenEarable.sensorManager
          .writeSensorConfig(opticalTemperatureSensorConfig);
      await leftOpenEarable.sensorManager.writeSensorConfig(microphone1Config);
      await leftOpenEarable.sensorManager.writeSensorConfig(microphone2Config);
      await leftOpenEarable.sensorManager
          .writeSensorConfig(pulseOximeterConfig);
      await leftOpenEarable.sensorManager.writeSensorConfig(vitalsConfig);
    }

    if (rightOpenEarable.bleManager.connected) {
      await rightOpenEarable.sensorManager.writeSensorConfig(imuConfig);
      await rightOpenEarable.sensorManager.writeSensorConfig(barometerConfig);
      await rightOpenEarable.sensorManager
          .writeSensorConfig(opticalTemperatureSensorConfig);
      await rightOpenEarable.sensorManager.writeSensorConfig(microphone1Config);
      await rightOpenEarable.sensorManager.writeSensorConfig(microphone2Config);
      await rightOpenEarable.sensorManager
          .writeSensorConfig(pulseOximeterConfig);
      await rightOpenEarable.sensorManager.writeSensorConfig(vitalsConfig);
    }
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
              Row(
                children: [
                  Text(
                    'Sensor Control',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18.0,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Spacer(), // This matches the Spacer in your DynamicValuePicker row
                  SizedBox(
                    width: 70,
                    height: 37,
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: Text("BLE",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: Color.fromRGBO(168, 168, 172, 1.0))),
                    ),
                  ),
                  SizedBox(
                      width:
                          8), // Space between the first title and the second title
                  SizedBox(
                    width: 70,
                    height: 37,
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: Text("SD",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: Color.fromRGBO(168, 168, 172, 1.0))),
                    ),
                  ),
                  SizedBox(width: 8), // Space before the "Hz" label
                  Text("Hz",
                      textAlign: TextAlign.left,
                      style:
                          TextStyle(color: Color.fromRGBO(168, 168, 172, 0))),
                ],
              ),
              ChangeNotifierProvider<SensorSettings>.value(
                  value: OpenEarableSettingsV2().microphone1Settings,
                  child: SensorControlRow("Microphone 1")),
              SizedBox(height: 4),
              ChangeNotifierProvider<SensorSettings>.value(
                  value: OpenEarableSettingsV2().microphone2Settings,
                  child: SensorControlRow("Microphone 2")),
              Divider(
                color: Color.fromRGBO(168, 168, 172, 1.0),
              ),
              ChangeNotifierProvider<SensorSettings>.value(
                  value: OpenEarableSettingsV2().imuSettings,
                  child: SensorControlRow("9-Axis IMU")),
              SizedBox(height: 4),
              ChangeNotifierProvider<SensorSettings>.value(
                  value: OpenEarableSettingsV2().pulseOximeterSettings,
                  child: SensorControlRow("Pulse Oximeter\n(Red/Infrared)")),
              SizedBox(height: 4),
              ChangeNotifierProvider<SensorSettings>.value(
                  value: OpenEarableSettingsV2().vitalsSettings,
                  child: SensorControlRow("Heart Rate,\nSpO2")),
              SizedBox(height: 4),
              ChangeNotifierProvider<SensorSettings>.value(
                  value: OpenEarableSettingsV2().opticalTemperatureSettings,
                  child: SensorControlRow("Optical Temp.\n(Surface)")),
              SizedBox(height: 4),
              ChangeNotifierProvider<SensorSettings>.value(
                  value: OpenEarableSettingsV2().barometerSettings,
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
