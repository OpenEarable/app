// ignore_for_file: unnecessary_this

import 'dart:async';

import 'attitude.dart';

class AttitudeTracker {
  StreamController<Attitude> _attitudeStreamController = StreamController<Attitude>();

  Future<Attitude> get attitude => this._attitudeStreamController.stream.first;

  void listen(void Function(Attitude) callback) {
    this._attitudeStreamController.stream.listen(callback);
  }

  void _updateAttitude(double roll, double pitch, double yaw) {
    this._attitudeStreamController.add(Attitude(roll: roll, pitch: pitch, yaw: yaw));
  }
}