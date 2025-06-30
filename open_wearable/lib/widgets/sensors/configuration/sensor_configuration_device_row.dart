import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart';
import 'package:open_wearable/widgets/sensors/configuration/edge_recorder_prefix_row.dart';
import 'package:open_wearable/widgets/sensors/configuration/sensor_configuration_value_row.dart';
import 'package:provider/provider.dart';

import '../../../view_models/sensor_configuration_provider.dart';

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
            trailing: _buildResetButton(context),
          ),
          if (device is SensorConfigurationManager)
            ListView.builder(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              itemCount: (device as SensorConfigurationManager).sensorConfigurations.length,
              itemBuilder: (context, index) {
                return SensorConfigurationValueRow(
                  sensorConfiguration: (device as SensorConfigurationManager).sensorConfigurations[index],
                );
              },
            )
          else
            Text("This device does not support sensors"),
          if (device is EdgeRecorderManager) ...[
            const Divider(),
            EdgeRecorderPrefixRow(
              manager: device as EdgeRecorderManager,
            ),
          ],
        ],
      ),
    );
  }

  Widget? _buildResetButton(BuildContext context) {
    if (device is! SensorConfigurationManager) {
      return null;
    }

    return Consumer<SensorConfigurationProvider>(
      builder: (context, sensorConfigNotifier, child) {
        bool allSensorsOff = (device as SensorConfigurationManager).sensorConfigurations.every(
          (config) => sensorConfigNotifier.getSelectedConfigurationValue(config) == config.offValue,
        );

        if (allSensorsOff) {
          return SizedBox.shrink();
        }

        return PlatformTextButton(
          alignment: Alignment.centerRight,
          padding: EdgeInsets.zero,
          onPressed: () {
            sensorConfigNotifier.turnOffAllSensors();
          },
          child: Text("ALL OFF"),
        );
      },
    );
  }
}
