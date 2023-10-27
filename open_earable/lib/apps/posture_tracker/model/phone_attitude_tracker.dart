import 'dart:async';

import 'package:motion_sensors/motion_sensors.dart';
import 'package:open_earable/apps/posture_tracker/model/attitude_tracker.dart';

class PhoneAttitudeTracker extends AttitudeTracker {
  StreamSubscription<OrientationEvent>? _orientationSubscription;

  @override
  bool get isTracking => _orientationSubscription != null && !_orientationSubscription!.isPaused; 

  @override
  void start() {
    if (_orientationSubscription?.isPaused ?? false) {
      _orientationSubscription?.resume();
      return;
    }
    _orientationSubscription = motionSensors.orientation.listen((event) {
      updateAttitude(roll: event.roll, pitch: event.pitch, yaw: event.yaw);
    });
  }

  @override
  void stop() {
    _orientationSubscription?.pause();
  }

  @override
  void cancle() {
    _orientationSubscription?.cancel();
    super.cancle();
  }
}