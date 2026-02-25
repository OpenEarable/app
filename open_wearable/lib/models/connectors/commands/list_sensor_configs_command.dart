import 'package:open_earable_flutter/open_earable_flutter.dart';
import 'command.dart';
import 'device_command.dart';

class ListSensorConfigsCommand extends DeviceCommand {
  ListSensorConfigsCommand({required super.runtime})
      : super(name: 'list_sensor_configurations');

  @override
  Future<List<Map<String, dynamic>>> execute(List<CommandParam> params) async {
    final wearable = await getWearable(params);
    final manager = requireWearableCapability<SensorConfigurationManager>(
      wearable,
      action: name,
    );

    return _serializeSensorConfigurations(manager);
  }

  List<Map<String, dynamic>> _serializeSensorConfigurations(
    SensorConfigurationManager manager,
  ) {
    return manager.sensorConfigurations.map((configuration) {
      return <String, dynamic>{
        'name': configuration.name,
        'unit': configuration.unit,
        'values': configuration.values
            .map(_serializeSensorConfigurationValue)
            .toList(),
        'off_value': configuration.offValue?.key,
      };
    }).toList();
  }

  Map<String, dynamic> _serializeSensorConfigurationValue(
    SensorConfigurationValue value,
  ) {
    final payload = <String, dynamic>{'key': value.key};

    if (value is SensorFrequencyConfigurationValue) {
      payload['frequency_hz'] = value.frequencyHz;
    }
    if (value is ConfigurableSensorConfigurationValue) {
      payload['options'] = value.options.map((option) => option.name).toList();
    }

    return payload;
  }
}
