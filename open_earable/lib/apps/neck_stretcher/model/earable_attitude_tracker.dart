import 'dart:async';

import 'package:open_earable/apps/neck_stretcher/model/attitude_tracker.dart';
import 'package:open_earable_flutter/src/open_earable_flutter.dart';

/// earable implementation of attitude tracker
class EarableAttitudeTracker_Stretcher extends AttitudeTracker {
  final OpenEarable _openEarable;
  StreamSubscription<Map<String, dynamic>>? _subscription;
  
  @override
  bool get isTracking => _subscription != null && !_subscription!.isPaused;
  @override
  bool get isAvailable => _openEarable.bleManager.connected;

  EarableAttitudeTracker_Stretcher(this._openEarable) {
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
    _subscription = _openEarable.sensorManager.subscribeToSensorData(0).listen((event) {
      updateAttitude(
        roll: event["EULER"]["ROLL"],
        pitch: event["EULER"]["PITCH"],
        yaw: event["EULER"]["YAW"]
      );
    });
  }

  @override
  void stop() {
    _subscription?.pause();
  }

  @override
  void cancel() {
    _subscription?.cancel();
    super.cancel();
  }

  OpenEarableSensorConfig _buildSensorConfig() {
    return OpenEarableSensorConfig(
      sensorId: 0,
      samplingRate: 30,
      latency: 0
    );
  }
}