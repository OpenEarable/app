import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart';
import 'package:open_wearable/view_models/sensor_configuration_provider.dart';
import 'package:open_wearable/widgets/sensors/configuration/sensor_configuration_detail_view.dart';
import 'package:provider/provider.dart';

import 'sensor_config_option_icon_factory.dart';

/// A row that displays a sensor configuration and allows the user to select a value.
///
/// The selected value is added to the [SensorConfigurationProvider].
class SensorConfigurationValueRow extends StatelessWidget {
  final SensorConfiguration sensorConfiguration;

  const SensorConfigurationValueRow({
    super.key,
    required this.sensorConfiguration,
  });

  @override
  Widget build(BuildContext context) {
    final sensorConfigNotifier =
        Provider.of<SensorConfigurationProvider>(context);

    return PlatformListTile(
      onTap: () {
        showPlatformModalSheet(
          context: context,
          builder: (modalContext) {
            return ChangeNotifierProvider.value(
              value: sensorConfigNotifier,
              child: PlatformScaffold(
                appBar: PlatformAppBar(
                  title: PlatformText(sensorConfiguration.name),
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
      title: PlatformText(sensorConfiguration.name),
      trailing: _isOn(sensorConfigNotifier, sensorConfiguration)
          ? () {
              if (sensorConfigNotifier
                      .getSelectedConfigurationValue(sensorConfiguration) ==
                  null) {
                return PlatformText(
                  "Internal Error",
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.secondary,
                  ),
                );
              }
              SensorConfigurationValue value = sensorConfigNotifier
                  .getSelectedConfigurationValue(sensorConfiguration)!;
              if (value is SensorFrequencyConfigurationValue) {
                SensorFrequencyConfigurationValue freqValue = value;

                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (sensorConfiguration is ConfigurableSensorConfiguration)
                      ...(sensorConfigNotifier.getSelectedConfigurationOptions(
                        sensorConfiguration,
                      )).map(
                        (option) {
                          return Icon(
                            getSensorConfigurationOptionIcon(option),
                            color: Theme.of(context).colorScheme.secondary,
                          );
                        },
                      ),
                    PlatformText(
                      "${freqValue.frequencyHz} Hz",
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.secondary,
                      ),
                    ),
                  ],
                );
              }

              return PlatformText(
                value.toString(),
                style: TextStyle(
                  color: Theme.of(context).colorScheme.secondary,
                ),
              );
            }()
          : PlatformText(
              "Off",
              style: TextStyle(color: Theme.of(context).colorScheme.secondary),
            ),
    );
  }

  bool _isOn(SensorConfigurationProvider notifier, SensorConfiguration config) {
    bool isOn = false;
    if (config is ConfigurableSensorConfiguration) {
      isOn = notifier.getSelectedConfigurationOptions(config).isNotEmpty;
    } else if (config is SensorFrequencyConfiguration) {
      SensorFrequencyConfigurationValue? value =
          notifier.getSelectedConfigurationValue(config)
              as SensorFrequencyConfigurationValue?;
      isOn = value?.frequencyHz != null && value!.frequencyHz > 0;
    } else {
      isOn = true;
    }

    return isOn;
  }
}
