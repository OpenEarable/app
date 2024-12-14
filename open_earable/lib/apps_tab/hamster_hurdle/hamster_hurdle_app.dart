import 'dart:async';
import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart';

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

  final double _gravity = 9.81;
  double currentAcc = 0;

  @override
  Widget build(BuildContext context) {
    return Text("CurrentAcc: $currentAcc");
  }

  /// Builds the sensor config.
  OpenEarableSensorConfig _buildOpenEarableConfig() {
    return OpenEarableSensorConfig(sensorId: 0, samplingRate: 30, latency: 0);
  }

  /// Processes the sensor data.
  void _processSensorData(Map<String, dynamic> data) {
    double accX = data["ACC"]["X"];
    double accY = data["ACC"]["Y"];
    double accZ = data["ACC"]["Z"];
    double accMagnitude =
        accZ.sign * sqrt(accX * accX + accY * accY + accZ * accZ);
    currentAcc = accMagnitude - _gravity;
  }

  /// Sets up listeners for sensor data.
  void _setupListeners() {
    _imuSubscription = widget.openEarable.sensorManager
        .subscribeToSensorData(0)
        .listen(_processSensorData);
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
