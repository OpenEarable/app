import 'dart:async';
import 'dart:collection';

import 'package:open_earable_flutter/open_earable_flutter.dart';

/// Shared sensor streams to avoid multiple direct subscriptions to
/// single-subscription sensor streams.
class SensorStreams {
  SensorStreams._();

  static final Map<String, Map<Sensor, Stream<SensorValue>>>
      _sharedStreamsByDevice = {};
  static Map<Sensor, Stream<SensorValue>> _createIdentitySensorStreamMap() =>
      LinkedHashMap<Sensor, Stream<SensorValue>>.identity();

  static Stream<SensorValue> shared({
    required Wearable wearable,
    required Sensor sensor,
  }) {
    final deviceStreams = _sharedStreamsByDevice.putIfAbsent(
      wearable.deviceId,
      // Identity map avoids collisions when Sensor overrides ==/hashCode
      // non-uniquely across different devices.
      _createIdentitySensorStreamMap,
    );
    return deviceStreams.putIfAbsent(
      sensor,
      () => sensor.sensorStream.asBroadcastStream(),
    );
  }

  static void clearForSensor({
    required Wearable wearable,
    required Sensor sensor,
  }) {
    final deviceStreams = _sharedStreamsByDevice[wearable.deviceId];
    if (deviceStreams == null) {
      return;
    }
    deviceStreams.remove(sensor);
    if (deviceStreams.isEmpty) {
      _sharedStreamsByDevice.remove(wearable.deviceId);
    }
  }
}
