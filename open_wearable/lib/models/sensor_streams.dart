import 'dart:async';

import 'package:open_earable_flutter/open_earable_flutter.dart';

/// Shared sensor streams to avoid multiple direct subscriptions to
/// single-subscription sensor streams.
class SensorStreams {
  SensorStreams._();

  static final Map<Sensor, Stream<SensorValue>> _sharedStreams = {};

  static Stream<SensorValue> shared(Sensor sensor) {
    return _sharedStreams.putIfAbsent(
      sensor,
      () => sensor.sensorStream.asBroadcastStream(),
    );
  }

  static void clearForSensor(Sensor sensor) {
    _sharedStreams.remove(sensor);
  }
}
