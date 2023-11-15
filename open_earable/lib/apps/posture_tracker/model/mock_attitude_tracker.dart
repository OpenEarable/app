import 'dart:async';
import 'dart:math';

import 'package:open_earable/apps/posture_tracker/model/attitude.dart';
import 'package:open_earable/apps/posture_tracker/model/attitude_tracker.dart';

class MockAttitudeTracker extends AttitudeTracker {
  Stream<Attitude> _attitudeStream = Stream.empty();
  StreamSubscription<Attitude>? _attitudeSubscription;

  @override
  bool get isTracking => _attitudeSubscription != null && !_attitudeSubscription!.isPaused;

  bool _isAvailable = false;
  @override
  bool get isAvailable => _isAvailable;

  MockAttitudeTracker({Function(AttitudeTracker)? didChangeAvailability}) : super() {
    _attitudeStream = Stream.periodic(Duration(milliseconds: 100), (count) {
      return Attitude(
        roll: sin(count / 10) * pi / 4,
        pitch: sin(count / 20) * pi / 4,
        yaw: sin(count / 30) * pi / 4
      );
    });
    didChangeAvailability = didChangeAvailability ?? (_) { };

    didChangeAvailability(this);
    // wait for 5 seconds before setting the tracker to available
    Timer(Duration(seconds: 3), () {
      _isAvailable = true;
      this.didChangeAvailability(this);
    });
  }

  @override
  void start() {
    if (_attitudeSubscription != null) {
      if (_attitudeSubscription!.isPaused) {
        _attitudeSubscription!.resume();
      }
      return;
    }

    _attitudeSubscription = _attitudeStream.listen((value) {
      updateAttitude(attitude: value);
    });
  }

  @override
  void stop() {
    _attitudeSubscription?.pause();
  }

  @override
  void cancle() {
    _attitudeSubscription?.cancel();
    super.cancle();
  }
}