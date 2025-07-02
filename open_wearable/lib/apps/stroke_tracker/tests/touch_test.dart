import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart';

class TouchTestProvider extends ChangeNotifier {
  final VoidCallback onComplete;
  int _leftTapCount = 0;
  int _rightTapCount = 0;

  bool get leftTapped => _leftTapCount >= 3;
  bool get rightTapped => _rightTapCount >= 3;
  bool get isComplete => leftTapped && rightTapped;

  StreamSubscription? _leftSub;
  StreamSubscription? _rightSub;

  TouchTestProvider({required this.onComplete});

  static const double deltaThreshold = 0.07;
  double? _previousLeftMagnitude;
  double? _previousRightMagnitude;

  void startListening({
    required SensorManager leftManager,
    required SensorManager rightManager,
  }) {
    final leftAccel = leftManager.sensors.firstWhere(
      (s) => s.sensorName.toLowerCase().contains('accelerometer'),
      orElse: () => throw Exception('Left accelerometer not found'),
    );

    final rightAccel = rightManager.sensors.firstWhere(
      (s) => s.sensorName.toLowerCase().contains('accelerometer'),
      orElse: () => throw Exception('Right accelerometer not found'),
    );

    _configureSensor(leftAccel);
    _configureSensor(rightAccel);

    _leftSub = leftAccel.sensorStream.listen((data) {
      if (data is SensorDoubleValue) {
        final delta = _processDelta(data, isLeft: true);
        if (delta > deltaThreshold) {
          _leftTapCount++;
          print("Left tap detected \$_leftTapCount times");
          notifyListeners();
        }
      }
    });

    _rightSub = rightAccel.sensorStream.listen((data) {
      if (data is SensorDoubleValue && leftTapped) {
        final delta = _processDelta(data, isLeft: false);
        if (delta > deltaThreshold) {
          _rightTapCount++;
          print("Right tap detected \$_rightTapCount times");
          notifyListeners();
          if (isComplete) onComplete();
        }
      }
    });
  }

  double _processDelta(SensorDoubleValue sensorData, {required bool isLeft}) {
    final ax = sensorData.values[0].toDouble();
    final ay = sensorData.values[1].toDouble();
    final az = sensorData.values[2].toDouble();
    final magnitude = sqrt(ax * ax + ay * ay + az * az);

    final previous = isLeft ? _previousLeftMagnitude : _previousRightMagnitude;
    final delta = previous == null ? 0.0 : (magnitude - previous).abs();

    if (isLeft) {
      _previousLeftMagnitude = magnitude;
    } else {
      _previousRightMagnitude = magnitude;
    }
    print("${isLeft ? 'Left' : 'Right'} sensor delta: \$delta");
    return delta;
  }

  void _configureSensor(Sensor sensor) {
    for (var cfg in sensor.relatedConfigurations) {
      SensorConfigurationValue? streamConfig;
      for (var value in cfg.values) {
        if (value is ConfigurableSensorConfigurationValue &&
            value.options.any((o) => o is StreamSensorConfigOption)) {
          streamConfig = value;
          break;
        }
      }
      if (streamConfig != null) {
        cfg.setConfiguration(streamConfig);
        return;
      }
    }
    throw Exception('No streaming configuration found for \${sensor.sensorName}');
  }

  void stopListening() {
    _leftSub?.cancel();
    _rightSub?.cancel();
  }

  void reset() {
    stopListening();
    _leftTapCount = 0;
    _rightTapCount = 0;
    _previousLeftMagnitude = null;
    _previousRightMagnitude = null;
    notifyListeners();
  }
}

class TouchTest extends StatefulWidget {
  final SensorManager leftManager;
  final SensorManager rightManager;
  final VoidCallback onCompleted;

  const TouchTest({
    Key? key,
    required this.leftManager,
    required this.rightManager,
    required this.onCompleted,
  }) : super(key: key);

  @override
  State<TouchTest> createState() => _TouchTestState();
}

class _TouchTestState extends State<TouchTest> {
  late final TouchTestProvider provider;

  @override
  void initState() {
    super.initState();
    provider = TouchTestProvider(onComplete: widget.onCompleted);
    provider.startListening(
      leftManager: widget.leftManager,
      rightManager: widget.rightManager,
    );
  }

  @override
  void dispose() {
    provider.stopListening();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: provider,
      child: Consumer<TouchTestProvider>(
        builder: (_, p, __) {
          String instruction;
          if (!p.leftTapped) {
            instruction = 'Touch the LEFT earable 3 times';
          } else if (!p.rightTapped) {
            instruction = 'Touch the RIGHT earable 3 times';
          } else {
            instruction = 'Test complete! 🎉';
          }

          return Scaffold(
            body: Center(
              child: Text(
                instruction,
                style: TextStyle(fontSize: 24),
                textAlign: TextAlign.center,
              ),
            ),
            floatingActionButton: p.isComplete
                ? FloatingActionButton(
                    onPressed: provider.reset,
                    child: Icon(Icons.refresh),
                  )
                : null,
          );
        },
      ),
    );
  }
}