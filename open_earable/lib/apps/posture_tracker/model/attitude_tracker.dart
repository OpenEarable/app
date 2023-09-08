// ignore_for_file: unnecessary_this

import 'dart:async';

import 'attitude.dart';

abstract class AttitudeTracker {
  StreamController<Attitude> attitudeStreamController = StreamController<Attitude>();

  Future<Attitude> get attitude => this.attitudeStreamController.stream.first;

  void listen(void Function(Attitude) callback) {
    this.attitudeStreamController.stream.listen(callback);
  }

  void start();

  void stop();
}