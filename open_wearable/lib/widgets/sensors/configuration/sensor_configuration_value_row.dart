import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart';
import 'package:open_wearable/view_models/sensor_config_notifier.dart';
import 'package:open_wearable/view_models/sensor_configuration_provider.dart';
import 'package:open_wearable/widgets/sensors/configuration/sensor_configuration_detail_view.dart';
import 'package:provider/provider.dart';

/// A row that displays a sensor configuration and allows the user to select a value.
/// 
/// The selected value is added to the [SensorConfigurationProvider].
class SensorConfigurationValueRow extends StatelessWidget {
  final SensorConfiguration sensorConfiguration;

  const SensorConfigurationValueRow({super.key, required this.sensorConfiguration});

  @override
  Widget build(BuildContext context) {
    final sensorConfigNotifier = Provider.of<SensorConfigNotifier>(context);

    return GestureDetector(
      onTap: () {
        showPlatformModalSheet(
          context: context,
          builder: (modalContext) {
            return ChangeNotifierProvider.value(
              value: sensorConfigNotifier,
              child: PlatformScaffold(
                appBar: PlatformAppBar(
                  title: Text(sensorConfiguration.name),
                  leading: IconButton(
                    icon: Icon(Icons.close),
                    onPressed: () => Navigator.of(modalContext).pop(),
                  ),
                ),
                body: SensorConfigurationDetailView(
                  sensorConfiguration: sensorConfiguration,
                ),
              ),
            );
          },
        );
      },
      child: PlatformListTile(
        title: Text(sensorConfiguration.name),
        trailing: _isOn(sensorConfigNotifier, sensorConfiguration) ?
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (sensorConfiguration is StreamableSensorConfiguration)
                if ((sensorConfiguration as StreamableSensorConfiguration).streamData)
                  Icon(Icons.bluetooth, color: Theme.of(context).colorScheme.secondary)
                else
                  Icon(Icons.bluetooth_disabled, color: Theme.of(context).colorScheme.secondary),
              if (sensorConfiguration is RecordableSensorConfig)
                if ((sensorConfiguration as RecordableSensorConfig).recordData)
                  Icon(Icons.file_download_outlined, color: Theme.of(context).colorScheme.secondary)
                else
                  Icon(Icons.file_download_off_outlined, color: Theme.of(context).colorScheme.secondary),
              Text(
                "${sensorConfigNotifier.sensorConfigurationValues[sensorConfiguration]} Hz",
                style: TextStyle(color: Theme.of(context).colorScheme.secondary)
              ),
            ],
          )
          : Text("Off", style: TextStyle(color: Theme.of(context).colorScheme.secondary)),
      ),
    );
  }

  bool _isOn(SensorConfigNotifier notifier, SensorConfiguration config) {
    bool isOn = false;
    if (config is StreamableSensorConfiguration) {
      isOn |= (config as StreamableSensorConfiguration).streamData;
    }
    if (config is RecordableSensorConfig) {
      isOn |= (config as RecordableSensorConfig).recordData;
    }

    if (config is! StreamableSensorConfiguration && config is! RecordableSensorConfig) {
      isOn = true;
    }

    return isOn;
  }
}