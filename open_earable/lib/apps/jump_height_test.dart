import 'package:flutter/material.dart';
import 'dart:async';
import 'package:open_earable_flutter/src/open_earable_flutter.dart';

class JumpHeightTest extends StatefulWidget {
  final OpenEarable _openEarable;
  JumpHeightTest(this._openEarable);
  @override
  _JumpHeightTestState createState() => _JumpHeightTestState(_openEarable);
}

class _JumpHeightTestState extends State<JumpHeightTest> {
  DateTime? _startTime;
  double _jumpHeight = 0.0;
  bool _isJumping = false;
  final OpenEarable _openEarable;
  StreamSubscription? _imuSubscription;
  _JumpHeightTestState(this._openEarable);
  double _maxJumpHeight = 0.0;  // Variable to keep track of maximum jump height


  @override
  void initState() {
    super.initState();
    if (_openEarable.bleManager.connected) {
      _setupListeners();
    }
  }

  List<double> _accelerations = []; // Store relative accelerations
  double _lambda = 1.4; // Correction factor, adjust as needed

  _setupListeners() {
    _imuSubscription =
      _openEarable.sensorManager.subscribeToSensorData(0).listen((data) {
      double currentAcc = double.parse(data["ACC"]["Y"].toString());
      
      if (_accelerations.isNotEmpty) {
        double relativeAcc = currentAcc - _accelerations.last;
        _accelerations.add(relativeAcc);
      } else {
        _accelerations.add(currentAcc);
      }
    });
  }

  _calculateJumpHeight() {
    double height = 0.0;
    // TODO: timeSlice = 1 / samplingRate
    double timeSlice = 0.04; // Ensure this matches your data sampling rate
    
    print("Acc length: ${_accelerations.length}"); // Debug log
    for (int i = 0; i < _accelerations.length; i++) {
      height += 0.5 * _accelerations[i] * timeSlice * timeSlice;
    }
    height *= _lambda;

    print("Calculated Height: $height"); // Debug log

    if (height > _maxJumpHeight) {
      _maxJumpHeight = height;  // Update max height if current height is greater
    }

    setState(() {
      _jumpHeight = height;
    });
  }


  @override
  void dispose() {
    super.dispose();
    _imuSubscription?.cancel();
  }

  void _startJump() {
    _startTime = DateTime.now();
    setState(() {
      _isJumping = true;
      _maxJumpHeight = 0.0;  // Reset max height on starting a new jump
    });
    // Set sampling rate to maximum
    _openEarable.sensorManager.writeSensorConfig(_buildSensorConfig());
  }

  void _stopJump() {
    if (_isJumping) {
      // Calculate final jump height
      _calculateJumpHeight();

      // Resetting the state for the next jump
      _accelerations.clear();
      setState(() {
        _isJumping = false;
      });
    }
    // Here, _maxJumpHeight holds the maximum height reached during the jump
    print("Maximum Jump Height: $_maxJumpHeight meters");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Jump Height Test'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(
              'Jump Height: ${_jumpHeight.toStringAsFixed(2)} meters',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isJumping ? _stopJump : _startJump,
              child: Text(_isJumping ? 'Stop Jump' : 'Start Jump'),
            ),
          ],
        ),
      ),
    );
  }

  OpenEarableSensorConfig _buildSensorConfig() {
    return OpenEarableSensorConfig(
      sensorId: 0,
      samplingRate: 30,
      latency: 0,
    );
  }
}