import 'dart:async';
import 'package:flutter/material.dart';
import 'attitude.dart';

/// An abstract class that defines the core functionality of an attitude tracker
abstract class AttitudeTracker {
  StreamController<Attitude> _attitudeStreamController = StreamController<Attitude>.broadcast();

  Attitude _rawAttitude = Attitude(); // Stores the most recent raw attitude data
  Attitude get rawAttitude => _rawAttitude; // Public getter for raw attitude
  Attitude _attitude = Attitude(); // Stores the processed attitude data
  Attitude get attitude => _attitude; // Public getter for processed attitude
  bool get isTracking; // Indicates whether the tracker is currently tracking

  // Indicates whether tracking is available
  bool get isAvailable => true;

  // Reference attitude used for calibration
  Attitude _referenceAttitude = Attitude();

  // Callback called when the tracker's availability changes
  Function(AttitudeTracker) didChangeAvailability = (_) {};

  /// Listen to the attitude stream.
  ///
  ///callback is called when a new attitude is received.
  void listen(void Function(Attitude) callback) {
    this._attitudeStreamController.stream.listen(callback);
  }

  /// Start tracking the attitude.
  ///
  /// In order to receive the data, you need to call `listen()` first.
  void start();

  /// Stop tracking the attitude.
  ///
  /// You can resume the tracking by calling `start()` again.
  void stop();

  /// Calibrates the tracker to the current raw attitude
  ///
  /// Sets the current raw attitude as the reference for future updates
  void calibrateToCurrentAttitude() async {
    _referenceAttitude = _rawAttitude;
  }

  /// Cancle the stream and close the stream controller.
  ///
  /// If you want to use the tracker again, you need to call listen() again.
  @mustCallSuper
  void cancle() {
    this._attitudeStreamController.close();
  }

  /// Updates the attitude with new values.
  ///
  /// This method updates the raw and processed attitude. 
  /// It calculates the processed attitude based on the difference from the reference attitude.
  void updateAttitude(
      {double? roll, double? pitch, double? yaw, Attitude? attitude}) {
    if (roll == null && pitch == null && yaw == null && attitude == null) {
      throw ArgumentError(
          "Either roll, pitch and yaw or attitude must be provided");
    }
    // Check if attitude is not null, otherwise use the angles
    attitude ??= Attitude(roll: roll ?? 0, pitch: pitch ?? 0, yaw: yaw ?? 0);
    _rawAttitude = attitude;
    // Update the stream controller with the attitude
    _attitude = attitude - _referenceAttitude;
    _attitudeStreamController.add(_attitude);
  }
}
