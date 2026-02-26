import 'package:open_earable_flutter/open_earable_flutter.dart';
import 'command.dart';
import 'device_command.dart';

class ListSensorsCommand extends DeviceCommand {
  ListSensorsCommand({required super.runtime}) : super(name: 'list_sensors');

  @override
  Future<List<Map<String, dynamic>>> execute(List<CommandParam> params) async {
    final wearable = await getWearable(params);
    final manager = requireWearableCapability<SensorManager>(
      wearable,
      action: name,
    );
    return _serializeSensors(manager);
  }

  List<Map<String, dynamic>> _serializeSensors(SensorManager manager) {
    final sensors = manager.sensors;
    return [
      for (var index = 0; index < sensors.length; index++)
        <String, dynamic>{
          'sensor_id': _sensorId(sensors[index], index),
          'sensor_index': index,
          'name': sensors[index].sensorName,
          'chart_title': sensors[index].chartTitle,
          'short_chart_title': sensors[index].shortChartTitle,
          'axis_names': sensors[index].axisNames,
          'axis_units': sensors[index].axisUnits,
          'timestamp_exponent': sensors[index].timestampExponent,
        },
    ];
  }

  String _sensorId(Sensor sensor, int index) {
    final normalized = sensor.sensorName
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    return '${normalized}_$index';
  }
}
