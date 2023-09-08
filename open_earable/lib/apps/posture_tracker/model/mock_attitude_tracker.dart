// ignore_for_file: unnecessary_this

import 'dart:async';
import 'dart:math';

import 'package:open_earable/apps/posture_tracker/model/attitude.dart';
import 'package:open_earable/apps/posture_tracker/model/attitude_tracker.dart';

class MockAttitudeTracker extends AttitudeTracker {
  final Random _random = Random();
  Stream<Attitude> _attitudeStream = Stream.empty();
  StreamSubscription<Attitude>? _attitudeSubscription;

  MockAttitudeTracker() {
    this._attitudeStream = Stream<Attitude>.periodic(Duration(seconds: 1), (count) => (Attitude(roll: pi / 2 - this._random.nextDouble() * pi)));
  }

  @override
  void start() {
    if (this._attitudeSubscription != null) {
      if (this._attitudeSubscription!.isPaused) {
        this._attitudeSubscription!.resume();
      }
      return;
    }

    this._attitudeSubscription = this._attitudeStream.listen((value) {
      print("roll: ${value.roll}, pitch: ${value.pitch}, yaw: ${value.yaw}");
      this.attitudeStreamController.add(value);
    });
  }

  @override
  void stop() {
    this._attitudeSubscription?.pause();
  }
}