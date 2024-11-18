import 'package:flutter/material.dart';
import 'package:open_earable/ble/ble_controller.dart';
import 'sensor_control_row.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart';
import 'package:provider/provider.dart';
import '../../models/open_earable_settings_v2.dart';

class SensorControlCard extends StatefulWidget {
  const SensorControlCard({super.key});

  @override
  State<SensorControlCard> createState() => _SensorControlCardState();
}

class _SensorControlCardState extends State<SensorControlCard> {
  @override
  void initState() {
    super.initState();
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
        color: Theme.of(context).colorScheme.primary,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
                  child: Text(
                    'Sensor Control',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18.0,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Spacer(),
                // This matches the Spacer in your DynamicValuePicker row
                SizedBox(
                  width: 80,
                  height: 37,
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: Text(
                      "BLE",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color.fromRGBO(168, 168, 172, 1.0),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 4),
                // Space between the first title and the second title
                SizedBox(
                  width: 80,
                  height: 37,
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: Text(
                      "SD",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color.fromRGBO(168, 168, 172, 1.0),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 4),
                // Space before the "Hz" label
                Text(
                  "Hz",
                  textAlign: TextAlign.left,
                  style: TextStyle(color: Color.fromRGBO(168, 168, 172, 255)),
                ),
                SizedBox(width: 16),
              ],
            ),
            ChangeNotifierProvider<SensorSettings>.value(
              value: OpenEarableSettingsV2().microphone1Settings,
              child: SensorControlRow("Microphone 1"),
            ),
            SizedBox(height: 4),
            ChangeNotifierProvider<SensorSettings>.value(
              value: OpenEarableSettingsV2().microphone2Settings,
              child: SensorControlRow("Microphone 2"),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 0),
              child: Divider(
                color: Color.fromRGBO(168, 168, 172, 1.0),
              ),
            ),
            ChangeNotifierProvider<SensorSettings>.value(
              value: OpenEarableSettingsV2().imuSettings,
              child: SensorControlRow("9-Axis IMU"),
            ),
            SizedBox(height: 4),
            ChangeNotifierProvider<SensorSettings>.value(
              value: OpenEarableSettingsV2().pulseOximeterSettings,
              child: SensorControlRow("Pulse Oximeter\n(Red/Infrared)"),
            ),
            SizedBox(height: 4),
            ChangeNotifierProvider<SensorSettings>.value(
              value: OpenEarableSettingsV2().vitalsSettings,
              child: SensorControlRow("Heart Rate,\nSpO2"),
            ),
            SizedBox(height: 4),
            ChangeNotifierProvider<SensorSettings>.value(
              value: OpenEarableSettingsV2().opticalTemperatureSettings,
              child: SensorControlRow("Optical Temp.\n(Surface)"),
            ),
            SizedBox(height: 4),
            ChangeNotifierProvider<SensorSettings>.value(
              value: OpenEarableSettingsV2().barometerSettings,
              child: SensorControlRow("Pressure,\nTemp. (Ambient)"),
            ),
            Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 37,
                      child: ElevatedButton(
                        onPressed:
                            Provider.of<BluetoothController>(context).connected
                                ? _writeSensorConfigs
                                : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              Provider.of<BluetoothController>(context)
                                      .connected
                                  ? Theme.of(context).colorScheme.secondary
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
            ),
          ],
        ),
      ),
    );
  }
}
