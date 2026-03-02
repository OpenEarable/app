import 'dart:async';
import 'dart:collection';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart';

class SensorDataProvider with ChangeNotifier {
  final Sensor sensor;
  final int timeWindow; // seconds

  late final int _timestampCutoffMs;
  final Queue<SensorValue> sensorValues = Queue();

  StreamSubscription<SensorValue>? _sensorStreamSubscription;

  Timer? _throttleTimer;
  final Duration _throttleDuration = const Duration(milliseconds: 15);

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

      while (sensorValues.isNotEmpty && sensorValues.first.timestamp < cutoff) {
        sensorValues.removeFirst();
      }

      _throttledNotifyListeners();
    });
  }

  void _throttledNotifyListeners() {
    if (_throttleTimer?.isActive ?? false) return;

    _throttleTimer = Timer(_throttleDuration, notifyListeners);
  }

  @override
  void dispose() {
    _sensorStreamSubscription?.cancel();
    super.dispose();
  }
}
