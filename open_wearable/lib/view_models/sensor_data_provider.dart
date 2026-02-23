import 'dart:async';
import 'dart:collection';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart';
import 'package:open_wearable/models/sensor_streams.dart';

class SensorDataProvider with ChangeNotifier {
  final Wearable wearable;
  final Sensor sensor;
  final int timeWindow; // seconds

  late final int _timestampUnitsPerSecond;
  late final int _timestampCutoff;
  final Queue<SensorValue> sensorValues = Queue();

  StreamSubscription<SensorValue>? _sensorStreamSubscription;

  Timer? _throttleTimer;
  Timer? _silenceTimer;
  Timer? _staleDataTimer;
  final Duration _throttleDuration = const Duration(milliseconds: 15);
  final Duration _staleDataInterval = const Duration(milliseconds: 100);

  int? _lastSensorTimestamp;
  DateTime? _lastSensorArrivalTime;

  SensorDataProvider({
    required this.wearable,
    required this.sensor,
    this.timeWindow = 5,
  }) {
    _timestampUnitsPerSecond = max(
      1,
      pow(10, -sensor.timestampExponent).round(),
    );
    _timestampCutoff = _timestampUnitsPerSecond * timeWindow;
    _listenToStream();
  }

  int get displayTimestamp {
    final lastTimestamp = _lastSensorTimestamp;
    final lastArrivalTime = _lastSensorArrivalTime;
    if (lastTimestamp == null || lastArrivalTime == null) {
      return lastTimestamp ?? 0;
    }
    final elapsedMicroseconds =
        DateTime.now().difference(lastArrivalTime).inMicroseconds;
    final elapsedTimestampUnits =
        (elapsedMicroseconds * _timestampUnitsPerSecond) ~/
            Duration.microsecondsPerSecond;
    return lastTimestamp + elapsedTimestampUnits;
  }

  void _listenToStream() {
    _sensorStreamSubscription = SensorStreams.shared(
      wearable: wearable,
      sensor: sensor,
    ).listen((sensorValue) {
      sensorValues.add(sensorValue);
      _lastSensorTimestamp = sensorValue.timestamp;
      _lastSensorArrivalTime = DateTime.now();
      _pruneStaleValues(referenceTimestamp: sensorValue.timestamp);
      _stopStaleDataTicker();
      _scheduleSilenceWatch();

      _throttledNotifyListeners();
    });
  }

  void _pruneStaleValues({required int referenceTimestamp}) {
    final cutoff = referenceTimestamp - _timestampCutoff;
    // Sensor values are timestamp-ordered from the stream, so stale values
    // only need to be removed from the queue front.
    while (sensorValues.isNotEmpty && sensorValues.first.timestamp < cutoff) {
      sensorValues.removeFirst();
    }
  }

  bool get _isSensorSilent {
    final lastArrivalTime = _lastSensorArrivalTime;
    if (lastArrivalTime == null) {
      return true;
    }
    return DateTime.now().difference(lastArrivalTime) >= _staleDataInterval;
  }

  void _scheduleSilenceWatch() {
    _silenceTimer?.cancel();
    _silenceTimer = Timer(_staleDataInterval, () {
      if (_isSensorSilent) {
        _startStaleDataTickerIfNeeded();
      }
    });
  }

  void _startStaleDataTickerIfNeeded() {
    if ((_staleDataTimer?.isActive ?? false) || sensorValues.isEmpty) return;

    _staleDataTimer = Timer.periodic(_staleDataInterval, (_) {
      if (sensorValues.isEmpty || !_isSensorSilent) {
        _stopStaleDataTicker();
        return;
      }

      final previousLength = sensorValues.length;
      _pruneStaleValues(referenceTimestamp: displayTimestamp);

      if (sensorValues.isEmpty) {
        _stopStaleDataTicker();
      }

      if (sensorValues.isNotEmpty || previousLength != sensorValues.length) {
        _throttledNotifyListeners();
      }
    });
  }

  void _stopStaleDataTicker() {
    _staleDataTimer?.cancel();
    _staleDataTimer = null;
  }

  void _throttledNotifyListeners() {
    if (_throttleTimer?.isActive ?? false) return;

    _throttleTimer = Timer(_throttleDuration, notifyListeners);
  }

  @override
  void dispose() {
    _throttleTimer?.cancel();
    _silenceTimer?.cancel();
    _stopStaleDataTicker();
    _sensorStreamSubscription?.cancel();
    super.dispose();
  }
}
