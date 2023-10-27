// ignore_for_file: unnecessary_this

import 'dart:async';

import 'package:flutter/material.dart';

import 'attitude.dart';

/// An abstract class for attitude trackers.
abstract class AttitudeTracker {
  StreamController<Attitude> _attitudeStreamController = StreamController<Attitude>();

  Future<Attitude> get attitude => this._attitudeStreamController.stream.first;
  bool get isTracking;
  /// check if tracking is available
  bool get isAvailable => true;

  Attitude _referenceAttitude = Attitude();

  /// Callback that is called when the tracker changes availability. Takes the tracker as an argument.
  Function(AttitudeTracker) didChangeAvailability = (_) { };

  /// Listen to the attitude stream.
  /// 
  /// [callback] is called when a new attitude is received.
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

  void calibrate(Attitude referenceAttitude) {
    _referenceAttitude = referenceAttitude;
  }

  /// Cancle the stream and close the stream controller.
  /// 
  /// If you want to use the tracker again, you need to call listen() again.
  @mustCallSuper
  void cancle() {
    this._attitudeStreamController.close();
  }

  void updateAttitude ({double? roll, double? pitch, double? yaw, Attitude? attitude}) {
    if (roll == null && pitch == null && yaw == null && attitude == null) {
      throw ArgumentError("Either roll, pitch and yaw or attitude must be provided");
    }
    // Check if attitude is not null, otherwise use the angles
    attitude ??= Attitude(roll: roll ?? 0, pitch: pitch ?? 0, yaw: yaw ?? 0);
    // Update the stream controller with the attitude
    _attitudeStreamController.add (attitude - _referenceAttitude);
  }

}