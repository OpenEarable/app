import 'package:open_earable_flutter/open_earable_flutter.dart' hide logger;
import 'command.dart';
import 'device_command.dart';

class SetSensorConfigCommand extends DeviceCommand {
  SetSensorConfigCommand({required super.runtime})
      : super(
          name: 'set_sensor_configuration',
          params: [
            CommandParam<String>(name: 'configuration_name', required: true),
            CommandParam<String>(name: 'value_key', required: true),
          ],
        );

  @override
  Future<Map<String, dynamic>> execute(List<CommandParam> params) async {
    final wearable = await getWearable(params);
    final manager = requireWearableCapability<SensorConfigurationManager>(
      wearable,
      action: name,
    );

    final configurationName =
        requireParam<String>(params, 'configuration_name');
    final valueKey = requireParam<String>(params, 'value_key');

    final configuration = manager.sensorConfigurations.firstWhere(
      (config) => config.name == configurationName,
      orElse: () => throw ArgumentError(
        'Unknown sensor configuration: $configurationName',
      ),
    );

    final value = configuration.values.firstWhere(
      (value) => value.key == valueKey,
      orElse: () => throw ArgumentError(
        "Unknown value key '$valueKey' for configuration '$configurationName'",
      ),
    );

    configuration.setConfiguration(value);
    return <String, dynamic>{
      'configuration_name': configurationName,
      'value_key': valueKey,
    };
  }
}
