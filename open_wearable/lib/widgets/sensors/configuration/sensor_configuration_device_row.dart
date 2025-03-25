import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart';
import 'package:open_wearable/widgets/sensors/configuration/sensor_configuration_value_row.dart';

/// A widget that displays a list of sensor configurations for a device.
class SensorConfigurationDeviceRow extends StatelessWidget {
  final Wearable device;

  const SensorConfigurationDeviceRow({super.key, required this.device});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          PlatformListTile(
            title: Text(
              device.name,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            trailing: (device is DeviceIdentifier) ?
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
              : null,
          ),
          if (device is SensorConfigurationManager)
            ListView.builder(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              itemCount: (device as SensorConfigurationManager).sensorConfigurations.length,
              itemBuilder: (context, index) {
                return SensorConfigurationValueRow(
                  sensorConfiguration: (device as SensorConfigurationManager).sensorConfigurations[index]
                );
              },
            )
          else
            Text("This device does not support sensors"),
        ],
      ),
    );
  }
}