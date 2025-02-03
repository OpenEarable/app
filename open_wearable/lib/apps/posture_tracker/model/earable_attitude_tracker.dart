import 'dart:async';

import 'package:open_earable_flutter/open_earable_flutter.dart';
import 'package:open_wearable/apps/posture_tracker/model/attitude_tracker.dart';
import 'package:open_wearable/apps/posture_tracker/model/ewma.dart';

class EarableAttitudeTracker extends AttitudeTracker {
  final SensorManager _sensorManager;
  final SensorConfigurationManager _sensorConfigurationManager;
  StreamSubscription<Map<String, dynamic>>? _subscription;

  @override
  bool get isTracking => _subscription != null && !_subscription!.isPaused;

  final EWMA _rollEWMA = EWMA(0.5);
  final EWMA _pitchEWMA = EWMA(0.5);
  final EWMA _yawEWMA = EWMA(0.5);

  EarableAttitudeTracker(this._sensorManager, this._sensorConfigurationManager);

  @override
  void start() {
    if (_subscription?.isPaused ?? false) {
      _subscription?.resume();
      return;
    }

    _sensorManager.writeSensorConfig(_buildSensorConfig());
    _subscription =
        _sensorManager.sensorManager.subscribeToSensorData(0).listen((event) {
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

  void setAvailability(bool isAvailable) {
    _isAvailble = isAvailable;
    didChangeAvailability(this);
  }
}
