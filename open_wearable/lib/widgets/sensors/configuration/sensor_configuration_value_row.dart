import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart';
import 'package:open_wearable/view_models/sensor_config_notifier.dart';
import 'package:open_wearable/view_models/sensor_configuration_provider.dart';
import 'package:open_wearable/widgets/sensors/configuration/sensor_configuration_detail_view.dart';

/// A row that displays a sensor configuration and allows the user to select a value.
/// 
/// The selected value is added to the [SensorConfigurationProvider].
class SensorConfigurationValueRow extends StatelessWidget {
  final SensorConfiguration sensorConfiguration;

  const SensorConfigurationValueRow({super.key, required this.sensorConfiguration});

  @override
  Widget build(BuildContext context) {
    // Get the notifier from InheritedNotifier, making this widget reactive to state changes
    final sensorConfigNotifier = SensorConfigInheritedNotifier.of(context);

    return GestureDetector(
      onTap: () {
        showPlatformModalSheet(
          context: context,
          builder: (modalContext) {
            return SensorConfigInheritedNotifier(notifier: sensorConfigNotifier, child: SensorConfigurationDetailView(sensorConfiguration: sensorConfiguration));
          },
        );
      },
      child: PlatformListTile(
        title: Text(sensorConfiguration.name),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isOn(sensorConfigNotifier, sensorConfiguration))
              Icon(Icons.check, color: Colors.green)
            else
              Icon(Icons.close, color: Colors.red),
          ],
        ),
      ),
    );
  }

  bool isOn(SensorConfigNotifier notifier, SensorConfiguration config) {
    if (config is StreamableSensorConfiguration) {
      return (config as StreamableSensorConfiguration).streamData;
    }
    if (config is RecordableSensorConfig) {
      return (config as RecordableSensorConfig).recordData;
    }
    return true; // Default case for non-streamable/non-recordable configurations
  }
}