// ignore_for_file: unnecessary_this

import 'dart:async';

import 'package:motion_sensors/motion_sensors.dart';
import 'package:open_earable/apps/posture_tracker/model/attitude_tracker.dart';

import 'attitude.dart';

class PhoneAttitudeTracker extends AttitudeTracker {
  StreamSubscription<OrientationEvent>? _orientationSubscription;

  @override
  bool get isTracking => this._orientationSubscription != null && !this._orientationSubscription!.isPaused; 

  @override
  void start() {
    this._orientationSubscription = motionSensors.orientation.listen((event) { 
      print("roll: ${event.roll}, pitch: ${event.pitch}, yaw: ${event.yaw}");
      this._updateAttitude(event.roll, event.pitch, event.yaw);
    });
  }

  @override
  void stop() {
    this._orientationSubscription?.cancel();
  }

  @override
  void cancle() {
    this._orientationSubscription?.cancel();
    super.cancle();
  }

  void _updateAttitude(double roll, double pitch, double yaw) {
    this.attitudeStreamController.add(Attitude(roll: roll, pitch: pitch, yaw: yaw));
  }
}