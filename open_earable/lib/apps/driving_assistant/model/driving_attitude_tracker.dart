import 'dart:async';

import 'package:open_earable/apps/driving_assistant/model/base_attitude_tracker.dart';
import 'package:open_earable_flutter/src/open_earable_flutter.dart';

class DrivingAttitudeTracker extends BaseAttitudeTracker {
  final OpenEarable _openEarable;
  StreamSubscription<Map<String, dynamic>>? _subscription;

  @override
  bool get isTracking => _subscription != null && !_subscription!.isPaused;
  @override
  bool get isAvailable => _openEarable.bleManager.connected;

  DrivingAttitudeTracker(this._openEarable) {
    _openEarable.bleManager.connectionStateStream.listen((connected) {
      didChangeAvailability(this);
      if (!connected) {
        cancle();
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
    _subscription = _openEarable.sensorManager.subscribeToSensorData(0).listen((event) {
      updateDrivingAttitude(
          roll: event["EULER"]["ROLL"],
          pitch: event["EULER"]["PITCH"],
          yaw: event["EULER"]["YAW"],
          gyroY: event["GYRO"]["Y"],
      );
    });
  }

  @override
  void stop() {
    _subscription?.pause();
  }

  @override
  void cancle() {
    _subscription?.cancel();
    super.cancle();
  }

  OpenEarableSensorConfig _buildSensorConfig() {
    return OpenEarableSensorConfig(
        sensorId: 0,
        samplingRate: 30,
        latency: 0
    );
  }
}