import 'dart:async';

import 'package:open_earable/apps/posture_tracker/model/attitude.dart';
import 'package:open_earable/apps/posture_tracker/model/attitude_tracker.dart';
import 'package:open_earable_flutter/src/open_earable_flutter.dart';

class EarableAttitudeTracker extends AttitudeTracker {
  final OpenEarable _openEarable;
  StreamSubscription<Map<String, dynamic>>? _subscription;

  EarableAttitudeTracker(this._openEarable);

  @override
  bool get isTracking => _subscription != null && !_subscription!.isPaused; 

  @override
  void start() {
    if (_subscription?.isPaused ?? false) {
      _subscription?.resume();
      return;
    }

    _openEarable.sensorManager.writeSensorConfig(_buildSensorConfig());
    _subscription = _openEarable.sensorManager.subscribeToSensorData(0).listen((event) {
      _updateAttitude(
        event["EULER"]["ROLL"],
        event["EULER"]["PITCH"],
        event["EULER"]["YAW"]
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

  void _updateAttitude(double roll, double pitch, double yaw) {
    attitudeStreamController.add(Attitude(roll: roll, pitch: pitch, yaw: yaw));
  }
}