import 'dart:async';

import 'package:open_earable/apps_tab/posture_tracker/model/attitude_tracker.dart';
import 'package:open_earable/apps_tab/posture_tracker/model/ewma.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart';

class EarableAttitudeTracker extends AttitudeTracker {
  final OpenEarable _openEarable;
  StreamSubscription<Map<String, dynamic>>? _subscription;

  @override
  bool get isTracking => _subscription != null && !_subscription!.isPaused;
  @override
  bool get isAvailable => _openEarable.bleManager.connected;

  final EWMA _rollEWMA = EWMA(0.5);
  final EWMA _pitchEWMA = EWMA(0.5);
  final EWMA _yawEWMA = EWMA(0.5);

  EarableAttitudeTracker(this._openEarable) {
    _openEarable.bleManager.connectionStateStream.listen((connected) {
      didChangeAvailability(this);
      if (!connected) {
        cancel();
      }
    });
  }

  @override
  void start() {
    if (_subscription?.isPaused ?? false) {
      _subscription?.resume();
      return;
    }

    _openEarable.sensorManager.writeSensorConfig(_buildSensorConfig());
    _subscription =
        _openEarable.sensorManager.subscribeToSensorData(0).listen((event) {
      updateAttitude(
          roll: _rollEWMA.update(event["EULER"]["ROLL"]),
          pitch: _pitchEWMA.update(event["EULER"]["PITCH"]),
          yaw: _yawEWMA.update(event["EULER"]["YAW"]),);
    });
  }

  @override
  void stop() {
    _subscription?.pause();
  }

  @override
  void cancel() {
    stop();
    _subscription?.cancel();
    super.cancel();
  }

  OpenEarableSensorConfig _buildSensorConfig() {
    return OpenEarableSensorConfig(sensorId: 0, samplingRate: 30, latency: 0);
  }
}
