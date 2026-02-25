import 'package:open_earable_flutter/open_earable_flutter.dart';

import 'command.dart';
import 'ipc_internal_param_names.dart';
import 'param_readers.dart';
import 'runtime_command.dart';

class SubscribeCommand extends RuntimeCommand {
  SubscribeCommand({required super.runtime})
      : super(
          name: 'subscribe',
          params: [
            CommandParam<String>(name: 'device_id', required: true),
            CommandParam<String>(name: 'stream', required: true),
            CommandParam<Map<String, dynamic>>(name: 'args'),
            CommandParam<dynamic>(name: sessionParamName, required: true),
          ],
        );

  @override
  Future<Map<String, dynamic>> execute(List<CommandParam> params) async {
    final session = requireParam(params, sessionParamName);
    final deviceId = requireStringParam(params, 'device_id');
    final streamName = requireStringParam(params, 'stream');
    final args = readOptionalMapParam(params, 'args');
    final wearable = await runtime.getWearable(deviceId: deviceId);

    final Stream<dynamic> stream = _resolveStream(
      wearable: wearable,
      streamName: streamName,
      args: args,
    );

    final subscriptionId = await runtime.createSubscriptionId();
    await runtime.attachStreamSubscription(
      session: session,
      subscriptionId: subscriptionId,
      streamName: streamName,
      deviceId: wearable.deviceId,
      stream: stream,
    );

    return <String, dynamic>{
      'subscription_id': subscriptionId,
      'stream': streamName,
      'device_id': wearable.deviceId,
    };
  }

  Stream<dynamic> _resolveStream({
    required Wearable wearable,
    required String streamName,
    required Map<String, dynamic> args,
  }) {
    switch (streamName) {
      case 'sensor_values':
        return _resolveSensor(
          wearable: wearable,
          args: args,
        ).sensorStream;
      case 'sensor_configuration':
        return _requireCapability<SensorConfigurationManager>(
          wearable: wearable,
          streamName: streamName,
        ).sensorConfigurationStream;
      case 'button_events':
        return _requireCapability<ButtonManager>(
          wearable: wearable,
          streamName: streamName,
        ).buttonEvents;
      case 'battery_percentage':
        return _requireCapability<BatteryLevelStatus>(
          wearable: wearable,
          streamName: streamName,
        ).batteryPercentageStream;
      case 'battery_power_status':
        return _requireCapability<BatteryLevelStatusService>(
          wearable: wearable,
          streamName: streamName,
        ).powerStatusStream;
      case 'battery_health_status':
        return _requireCapability<BatteryHealthStatusService>(
          wearable: wearable,
          streamName: streamName,
        ).healthStatusStream;
      case 'battery_energy_status':
        return _requireCapability<BatteryEnergyStatusService>(
          wearable: wearable,
          streamName: streamName,
        ).energyStatusStream;
      default:
        throw UnsupportedError('Unknown stream: $streamName');
    }
  }

  Sensor _resolveSensor({
    required Wearable wearable,
    required Map<String, dynamic> args,
  }) {
    final manager = _requireCapability<SensorManager>(
      wearable: wearable,
      streamName: 'sensor_values',
    );
    final sensors = manager.sensors;
    if (sensors.isEmpty) {
      throw StateError('Wearable has no sensors.');
    }

    if (args['sensor_id'] != null) {
      final sensorId = args['sensor_id'].toString();
      for (var i = 0; i < sensors.length; i++) {
        if (_sensorId(sensors[i], i) == sensorId) {
          return sensors[i];
        }
      }
      throw StateError('Unknown sensor_id: $sensorId');
    }

    if (args['sensor_index'] != null) {
      final index = _asInt(args['sensor_index'], name: 'sensor_index');
      if (index < 0 || index >= sensors.length) {
        throw RangeError.index(index, sensors, 'sensor_index');
      }
      return sensors[index];
    }

    if (args['sensor_name'] != null) {
      final name = args['sensor_name'].toString();
      final matched =
          sensors.where((sensor) => sensor.sensorName == name).toList();
      if (matched.length != 1) {
        throw StateError(
          'sensor_name must resolve to exactly one sensor. Matches: ${matched.length}',
        );
      }
      return matched.first;
    }

    throw ArgumentError(
      'sensor_values subscription requires one of sensor_id, sensor_index, or sensor_name.',
    );
  }

  T _requireCapability<T>({
    required Wearable wearable,
    required String streamName,
  }) {
    if (!wearable.hasCapability<T>()) {
      throw UnsupportedError(
        'Stream "$streamName" requires capability $T on ${wearable.deviceId}.',
      );
    }
    return wearable.requireCapability<T>();
  }

  String _sensorId(Sensor sensor, int index) {
    final normalized = sensor.sensorName
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    return '${normalized}_$index';
  }

  int _asInt(Object? value, {required String name}) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      final parsed = int.tryParse(value);
      if (parsed != null) {
        return parsed;
      }
    }
    throw FormatException('Expected "$name" to be an integer.');
  }
}
