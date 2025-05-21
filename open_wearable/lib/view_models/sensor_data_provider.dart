import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart';

class SensorDataProvider with ChangeNotifier {
  final Sensor sensor;
  final int timeWindow; // seconds

  late final int _timestampCutoffMs;
  final List<SensorValue> sensorValues = [];

  StreamSubscription<SensorValue>? _sensorStreamSubscription;

  SensorDataProvider({
    required this.sensor,
    this.timeWindow = 5,
  }) {
    _timestampCutoffMs = pow(10, -sensor.timestampExponent).toInt() * timeWindow;
    _listenToStream();
  }

  void _listenToStream() {
    _sensorStreamSubscription = sensor.sensorStream.listen((sensorValue) {
      sensorValues.add(sensorValue);
      final cutoff = sensorValue.timestamp - _timestampCutoffMs;
      sensorValues.removeWhere((v) => v.timestamp < cutoff);

      notifyListeners();
    });
  }

  @override
  void dispose() {
    _sensorStreamSubscription?.cancel();
    super.dispose();
  }
}
