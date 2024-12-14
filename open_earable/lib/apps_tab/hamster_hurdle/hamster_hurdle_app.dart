import 'dart:async';
import 'dart:math';

import 'package:flutter/cupertino.dart';
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

  @override
  Widget build(BuildContext context) {
    return Text(currentAction.name);
  }

  /// Builds the sensor config.
  OpenEarableSensorConfig _buildOpenEarableConfig() {
    return OpenEarableSensorConfig(sensorId: 0, samplingRate: 30, latency: 0);
  }

  /// Processes the sensor data.
  void _processSensorData(Map<String, dynamic> data) {
    _accZ = data["ACC"]["Z"];
    _accY = data["ACC"]["Y"];
    _accX = data["ACC"]["Z"];
    _gyroY = data["GYRO"]["Y"];

    double accMagnitude =
        _accZ.sign * sqrt(_accX * _accX + _accY * _accY + _accZ * _accZ);
    double currentAcc = accMagnitude - _gravity;
    _determineAction(currentAcc, _gyroY);

  }

  /// Sets up listeners for sensor data.
  void _setupListeners() {
    _imuSubscription = widget.openEarable.sensorManager
        .subscribeToSensorData(0)
        .listen(_processSensorData);
  }

  void _determineAction(double acceleration, double gyroForward) {
    if(gyroForward > 10  && currentAction == GameAction.running) {
      setState(() {
        currentAction = GameAction.ducking;
      });
    }
    if(gyroForward < -10 && currentAction == GameAction.ducking) {
      setState(() {
        currentAction = GameAction.running;
      });
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
}

enum GameAction {
  ducking,
  jumping,
  gettingUp,
  running,
}
