// ignore_for_file: unnecessary_this

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:open_earable/apps/driving_assistant/model/driving_attitude.dart';

/// An abstract class for DrivingAttitude trackers.
abstract class BaseAttitudeTracker {
  StreamController<DrivingAttitude> _drivingAttitudeStreamController = StreamController<DrivingAttitude>.broadcast();

  DrivingAttitude _rawDrivingAttitude = DrivingAttitude();
  DrivingAttitude get rawDrivingAttitude => _rawDrivingAttitude;
  DrivingAttitude _drivingAttitude = DrivingAttitude();
  DrivingAttitude get drivingAttitude => _drivingAttitude;
  bool get isTracking;
  /// check if tracking is available
  bool get isAvailable => true;

  DrivingAttitude _referenceDrivingAttitude = DrivingAttitude();

  /// Callback that is called when the tracker changes availability. Takes the tracker as an argument.
  Function(BaseAttitudeTracker) didChangeAvailability = (_) { };

  /// Listen to the DrivingAttitude stream.
  /// 
  /// [callback] is called when a new DrivingAttitude is received.
  void listen(void Function(DrivingAttitude) callback) {
    this._drivingAttitudeStreamController.stream.listen(callback);
  }

  /// Start tracking the DrivingAttitude.
  /// 
  /// In order to receive the data, you need to call `listen()` first.
  void start();

  /// Stop tracking the DrivingAttitude.
  /// 
  /// You can resume the tracking by calling `start()` again.
  void stop();

  void calibrate(DrivingAttitude referenceDrivingAttitude) {
    _referenceDrivingAttitude = referenceDrivingAttitude;
  }

  void calibrateToCurrentDrivingAttitude() async {
    _referenceDrivingAttitude = _rawDrivingAttitude;
    print("calibrated to {roll: ${_referenceDrivingAttitude.roll}, pitch: ${_referenceDrivingAttitude.pitch}, yaw: ${_referenceDrivingAttitude.yaw}}");
  }

  /// Cancle the stream and close the stream controller.
  /// 
  /// If you want to use the tracker again, you need to call listen() again.
  @mustCallSuper
  void cancle() {
    this._drivingAttitudeStreamController.close();
  }

  void updateDrivingAttitude ({double? roll, double? pitch, double? yaw, double? gyroY, DrivingAttitude? drivingAttitude}) {
    if (roll == null && pitch == null && yaw == null && gyroY == null && drivingAttitude == null) {
      throw ArgumentError("Either roll, pitch, yaw and gyroY or DrivingAttitude must be provided");
    }
    // Check if DrivingAttitude is not null, otherwise use the angles
    drivingAttitude ??= DrivingAttitude(roll: roll ?? 0, pitch: pitch ?? 0, yaw: yaw ?? 0, gyroY: gyroY ?? 0);
    _rawDrivingAttitude = drivingAttitude;
    // Update the stream controller with the DrivingAttitude
    _drivingAttitude = drivingAttitude - _referenceDrivingAttitude;
    _drivingAttitudeStreamController.add(_drivingAttitude);
  }

}