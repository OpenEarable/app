import 'package:flutter/material.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart';
import 'package:open_wearable/widgets/sensors/configuration/sensor_configuration_value_row.dart';

/// A widget that displays a list of sensor configurations for a device.
class SensorConfigurationDeviceRow extends StatelessWidget {
  final Wearable device;

  const SensorConfigurationDeviceRow({super.key, required this.device});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(10.0),
        child: Column(
          children: [
            // Device Title
            Row(
              children: [
                Text(device.name, style: Theme.of(context).textTheme.bodyLarge),
                Spacer(),
                if (device is DeviceIdentifier)
                  FutureBuilder(
                    future: (device as DeviceIdentifier).readDeviceIdentifier(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.done) {
                        return Text(snapshot.data.toString());
                      } else {
                        return CircularProgressIndicator();
                      }
                    },
                  )
              ],
            ),
            if (device is SensorConfigurationManager)
              ListView.builder(
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                itemCount: (device as SensorConfigurationManager).sensorConfigurations.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.all(10.0),
                    child: SensorConfigurationValueRow(
                      sensorConfiguration: (device as SensorConfigurationManager).sensorConfigurations[index]
                    ),
                  );
                },
              )
            else
              Text("This device does not support sensors"),
          ],
        ),
      ),
    );
  }
}