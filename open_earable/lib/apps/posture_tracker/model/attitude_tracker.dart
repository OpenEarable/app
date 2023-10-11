// ignore_for_file: unnecessary_this

import 'dart:async';

import 'package:flutter/material.dart';

import 'attitude.dart';

/// An abstract class for attitude trackers.
abstract class AttitudeTracker {
  StreamController<Attitude> attitudeStreamController = StreamController<Attitude>();

  Future<Attitude> get attitude => this.attitudeStreamController.stream.first;
  bool get isTracking;

  /// Listen to the attitude stream.
  /// 
  /// [callback] is called when a new attitude is received.
  void listen(void Function(Attitude) callback) {
    this.attitudeStreamController.stream.listen(callback);
  }

  /// Start tracking the attitude.
  /// 
  /// In order to receive the data, you need to call `listen()` first.
  void start();

  /// Stop tracking the attitude.
  /// 
  /// You can resume the tracking by calling `start()` again.
  void stop();

  /// Cancle the stream and close the stream controller.
  /// 
  /// If you want to use the tracker again, you need to call listen() again.
  @mustCallSuper
  void cancle() {
    this.attitudeStreamController.close();
  }
}