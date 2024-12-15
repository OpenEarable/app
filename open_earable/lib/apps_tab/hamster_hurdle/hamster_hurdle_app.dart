import 'dart:async';
import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart';
import 'package:simple_kalman/simple_kalman.dart';

class HamsterHurdleApp extends StatefulWidget {
  /// Instance of OpenEarable device.
  final OpenEarable openEarable;

  const HamsterHurdleApp(this.openEarable, {super.key});

  @override
  State<HamsterHurdleApp> createState() => _HamsterHurdleState();
}

class _HamsterHurdleState extends State<HamsterHurdleApp> {
  /// Subscription to the IMU sensor.
  StreamSubscription? _imuSubscription;

  DateTime? _timeOfJumpDetection;

  /// X-axis acceleration.
  double _accX = 0.0;

  /// Y-axis acceleration.
  double _accY = 0.0;

  /// Z-axis acceleration.
  double _accZ = 0.0;

  /// Y-axis from gyroscope.
  double _gyroY = 0.0;

  ///The error measurement used in the Kalman-Filter for acceleration
  final double errorMeasureAcc = 5.0;

  ///The error measurement used in the Kalman-Filter for the gyroscope
  final double errorMeasureGyro = 10.0;

  /// Kalman filters for accelerometer and gyroscope data.
  late SimpleKalman _kalmanAccX, _kalmanAccY, _kalmanAccZ, _kalmanGyroY;

  /// Standard gravity in m/s^2.
  final double _gravity = 9.81;

  GameAction currentAction = GameAction.running;

  /// Builds the sensor config.
  OpenEarableSensorConfig _buildOpenEarableConfig() {
    return OpenEarableSensorConfig(sensorId: 0, samplingRate: 30, latency: 0);
  }

  /// Processes the sensor data.
  void _processSensorData(Map<String, dynamic> data) {
    _accZ = data["ACC"]["Z"];
    _accY = data["ACC"]["Y"];
    _accX = data["ACC"]["X"];
    _gyroY = data["GYRO"]["Y"];

    double accMagnitude =
        _accZ.sign * sqrt(_accX * _accX + _accY * _accY + _accZ * _accZ);
    double currentAcc = accMagnitude - _gravity;
    _determineAction();
  }

  /// Sets up listeners for sensor data.
  void _setupListeners() {
    _imuSubscription = widget.openEarable.sensorManager
        .subscribeToSensorData(0)
        .listen(_processSensorData);
  }

  void _determineAction() {
    double threshold = 0.5;
    if (_accZ < 0 + threshold) {
      setState(() {
        _timeOfJumpDetection = DateTime.now();
        currentAction = GameAction.jumping;
      });
    } else if (_accZ > _gravity + 2 && !_currentlyJumping()) {
      setState(() {
        currentAction = GameAction.ducking;
      });
    }
  }

  bool _currentlyJumping() {
    if (_timeOfJumpDetection == null) {
      return false;
    } else {
      return DateTime.now().difference(_timeOfJumpDetection!) <
          Duration(milliseconds: 900);
    }
  }

  @override
  void initState() {
    super.initState();
    if (widget.openEarable.bleManager.connected) {
      widget.openEarable.sensorManager
          .writeSensorConfig(_buildOpenEarableConfig());
      _setupListeners();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(

    )
  }


}

enum GameAction {
  ducking,
  jumping,
  gettingUp,
  running,
}
