import 'dart:async';

import 'package:open_earable/apps/star_finder/model/attitude_tracker.dart';
import 'package:open_earable/apps/star_finder/model/ewma.dart';
import 'package:open_earable_flutter/src/open_earable_flutter.dart';

class StarFinderEarableAttitudeTracker extends AttitudeTracker {
  final OpenEarable _openEarable;
  StreamSubscription<Map<String, dynamic>>? _subscription;
  
  @override
  bool get isTracking => _subscription != null && !_subscription!.isPaused;
  @override
  bool get isAvailable => _openEarable.bleManager.connected;

  EWMA _roll = EWMA(0.2);
  EWMA _pitch = EWMA(0.2);
  EWMA _yaw = EWMA(0.2);

  StarFinderEarableAttitudeTracker(this._openEarable) {
    _openEarable.bleManager.connectionStateStream.listen((connected) {
      didChangeAvailability(this);
      if (!connected) {
        cancle();
      }
    });
  }

  @override
  void start() {
    if (_subscription?.isPaused ?? false) {
      _subscription?.resume();
      return;
    }

    _openEarable.sensorManager.writeSensorConfig(_buildSensorConfig());
    _subscription = _openEarable.sensorManager.subscribeToSensorData(0).listen((event) {
      updateAttitude(
        roll: _roll.update(event["EULER"]["ROLL"]) * 180 / 3.14,
        pitch: _pitch.update(event["EULER"]["PITCH"]) * 180 / 3.14,
        yaw: _yaw.update(event["EULER"]["YAW"]) * 180 / 3.14
      );
      //print("${event["EULER"]["ROLL"]},${event["EULER"]["PITCH"]},${event["EULER"]["YAW"]}");
    });
  }

  @override
  void stop() {
    _subscription?.pause();
  }

  @override
  void cancle() {
    stop();
    _subscription?.cancel();
    super.cancle();
  }

  OpenEarableSensorConfig _buildSensorConfig() {
    return OpenEarableSensorConfig(
      sensorId: 0,
      samplingRate: 30,
      latency: 0
    );
  }
}