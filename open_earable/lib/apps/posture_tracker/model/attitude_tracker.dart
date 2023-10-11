// ignore_for_file: unnecessary_this

import 'dart:async';

import 'attitude.dart';

/// An abstract class for attitude trackers.
abstract class AttitudeTracker {
  StreamController<Attitude> attitudeStreamController = StreamController<Attitude>();

  Future<Attitude> get attitude => this.attitudeStreamController.stream.first;
  bool get isTracking;

  /// Listen to the attitude stream.
  /// [callback] is called when a new attitude is received.
  void listen(void Function(Attitude) callback) {
    this.attitudeStreamController.stream.listen(callback);
  }

  void start();

  void stop();

  /// Cancle the stream and close the stream controller.
  /// If you want to use the tracker again, you need to call listen() again.
  void cancle() {
    this.attitudeStreamController.close();
  }
}