import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_timer_countdown/flutter_timer_countdown.dart';
import 'package:open_earable/apps_tab/cpready/model/data.dart';
import 'package:open_earable/apps_tab/cpready/widgets/CPRInstructionView.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart';
import 'package:simple_kalman/simple_kalman.dart';

class CPReady extends StatefulWidget {
  const CPReady(this._openEarable, {super.key});

  final OpenEarable _openEarable;

  @override
  State<CPReady> createState() => _CPReadyState();
}

class _CPReadyState extends State<CPReady> {
  /// The subscription to the imu data.
  StreamSubscription? _imuSubscription;

  /// Flag to indicate if an OpenEarable device is connected.
  bool _earableConnected = false;

  /// Error measure for the Kalman filter.
  final _errorMeasureAcc = 5.0;

  /// Kalman filters for accelerometer data.
  late SimpleKalman _kalmanX, _kalmanY, _kalmanZ;

  /// Sampling rate time.
  final double _samplingRate = 30;

  /// Standard gravity in m/s^2.
  final double _gravity = 9.81;

  /// Accelerations.
  double _accX = 0.0;
  double _accY = 0.0;
  double _accZ = 0.0;

  /// Current velocity calculated from acceleration.
  double _currentVelocity = 0.0;

  /// The current vertical acceleration
  double _currentVerticalAcc = 0.0;

  /// Last measured velocity
  double _lastVelocity = 0.0;

  /// Pitch angle in radians.
  double _pitch = 0.0;

  double _roll = 0.0;

  /// The alpha parameter for the exponential smoothing
  final double _exponentialSmoothingAlpha = 0.7;

  /// The threshold after which the device should be considered stationary
  final double _accelerationThreshold = 0.2;

  /// Last change in the direction of vertical movement that was recorded
  DateTime? _lastChange;

  /// Bool storing if a cpr is currently executed.
  bool _doingCPR = false;

  /// Instruction currently given to the user
  CPRInstruction _currentInstruction = CPRInstruction.fine;

  /// Current frequency of up and down movements in Hz
  double _currentFrequency = 100 / 60;

  /// Initializes state and sets up listeners for sensor data.
  @override
  void initState() {
    super.initState();
    // Set up listeners for sensor data.
    if (widget._openEarable.bleManager.connected) {
      // Set the configuration for the OpenEarable device
      widget._openEarable.sensorManager.writeSensorConfig(_buildSensorConfig());
      _initializeKalmanFilters();
      _setupListeners();
      _earableConnected = true;
    }
  }

  ///Disposes the widget
  @override
  void dispose() {
    super.dispose();
    _imuSubscription?.cancel();
  }

  /// Sets up listeners to receive sensor data from the OpenEarable device.
  void _setupListeners() {
    _imuSubscription = widget._openEarable.sensorManager
        .subscribeToSensorData(0)
        .listen((data) {
      // Only process sensor data if the user is currently performing CPR.
      if (_doingCPR) {
        _processSensorData(data);
      }
    });
  }

  /// Processes incoming sensor [data] and updates jump height.
  void _processSensorData(Map<String, dynamic> data) {
    /// Kalman filtered accelerometer data for X.
    _accX = _kalmanX.filtered(data["ACC"]["X"]);

    /// Kalman filtered accelerometer data for Y.
    _accY = _kalmanY.filtered(data["ACC"]["Y"]);

    /// Kalman filtered accelerometer data for Z.
    _accZ = _kalmanZ.filtered(data["ACC"]["Z"]);

    _roll = data["EULER"]["ROLL"];

    /// Pitch angle in radians.
    _pitch = data["EULER"]["PITCH"];
    // Calculates the current vertical acceleration.
    // It adjusts the Z-axis acceleration with the pitch angle to account for the device's orientation.
    _currentVerticalAcc = _accZ * cos(_pitch) + _accX * sin(_pitch);

    // Subtract gravity to get acceleration due to movement.
    _currentVerticalAcc -= _gravity;

    _updateVelocity();
  }

  /// Updates the current velocity based on the [currentVerticalAcc].
  void _updateVelocity() {
    setState(() {
      if (_deviceIsStationary(_accelerationThreshold)) {
        //If the device is not accelerating, we can assume in our use case that the user is not moving vertically.
        _currentVerticalAcc = 0;
        _currentVelocity = 0;
      } else {
        // Integrate acceleration to get velocity.
        _currentVelocity += _currentVerticalAcc * (1 / _samplingRate);
      }

      if (_currentVelocity.sign != _lastVelocity.sign) {
        // The user has changed its vertical direction of movement, indicating
        // a change between an up and a down movement.
        // We can therefore now measure the frequency with which they are performing CPR.
        _updateFrequency();
      }
      _lastVelocity = _currentVelocity;
    });
  }

  /// Checks if the device is stationary based on acceleration magnitude.
  bool _deviceIsStationary(double threshold) {
    double accMagnitude = sqrt(_accX * _accX + _accY * _accY + _accZ * _accZ);
    bool isStationary = (accMagnitude > _gravity - threshold) &&
        (accMagnitude < _gravity + threshold);
    return isStationary;
  }

  /// Updates the frequency of the CPR
  void _updateFrequency() {
    var currentTime = DateTime.now();
    if (_lastChange == null) {
      _lastChange = currentTime;
      return;
    }
    //difference is the duration for one up or down movement
    int difference = currentTime.difference(_lastChange!).inMilliseconds;

    //Converting the time needed for one up and down movement to a frequency [Hz].
    //The calculated frequency is also exponentially smoothened with the previous values.
    //Source exponential smoothing: https://en.wikipedia.org/wiki/Exponential_smoothing
    //Should only be calculated if the difference was big enough so that false positives are ignored.
    if (difference > 20
    ) {
      _currentFrequency = _exponentialSmoothingAlpha * (1000 / difference) / 2 + (1 - _exponentialSmoothingAlpha) * _currentFrequency;
      _lastChange = currentTime;
      _updateInstruction();
    }
  }

  /// Updates the instruction given to the user based on the frequency measured
  /// by the earable, with which they are currently giving CPR.
  ///
  /// The recommend CPR frequency is between 100 and 120 bpm
  /// (Source: [NHS](https://www.nhs.uk/conditions/first-aid/cpr/#:~:text=Keeping%20your%20hands%20on%20their,as%20long%20as%20you%20can.))
  void _updateInstruction() {
    if (_currentFrequency < (90 / 60)) {
      _currentInstruction = CPRInstruction.faster;
    } else if (_currentFrequency > (130 / 60)) {
      _currentInstruction = CPRInstruction.slower;
    } else {
      _currentInstruction = CPRInstruction.fine;
    }
  }

  /// Initializes Kalman filters for accelerometer data.
  void _initializeKalmanFilters() {
    _kalmanX = SimpleKalman(
      errorMeasure: _errorMeasureAcc,
      errorEstimate: _errorMeasureAcc,
      q: 0.9,
    );
    _kalmanY = SimpleKalman(
      errorMeasure: _errorMeasureAcc,
      errorEstimate: _errorMeasureAcc,
      q: 0.9,
    );
    _kalmanZ = SimpleKalman(
      errorMeasure: _errorMeasureAcc,
      errorEstimate: _errorMeasureAcc,
      q: 0.9,
    );
  }

  /// Builds a sensor configuration for the OpenEarable device.
  /// Sets the sensor ID, sampling rate, and latency.
  OpenEarableSensorConfig _buildSensorConfig() {
    return OpenEarableSensorConfig(
      sensorId: 0,
      samplingRate: _samplingRate,
      latency: 0,
    );
  }

  ///Starts or stops a CPR procedure.
  void _startStopCPR() {
    if (_doingCPR) {
      setState(() {
        _doingCPR = false;
        _lastVelocity = 0;
        _lastChange = null;
      });
      return;
    }

    setState(() {
      _doingCPR = true;
    });
    showDialog(
      barrierDismissible: false,
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text("Get in position"),
        content: Column(
          children: [
            const Text("First call emergency agencies before performing CPR"),
            TimerCountdown(
              format: CountDownTimerFormat.secondsOnly,
              endTime: DateTime.now().add(
                const Duration(
                  minutes: 00,
                  seconds: 03,
                ),
              ),
              onEnd: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    double mainButtonSize = min(MediaQuery.sizeOf(context).width / 2, 300);
    TextStyle mediumTextStyle = Theme.of(context).textTheme.displaySmall!;

    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              height: 10,
            ),
            Visibility(
              // Show error message if no OpenEarable device is connected.
              visible: !_earableConnected,
              maintainState: true,
              maintainAnimation: true,
              child: Column(
                children: [
                  Text(
                    "No Earable Connected",
                    style: TextStyle(
                      color: Colors.red,
                      fontSize: 30,
                    ),
                  ),
                  SizedBox(height: 20,)
                ],
              ),
            ),
            Center(
              //Button for starting the CPR
              child: ElevatedButton(
                style: ButtonStyle(
                    fixedSize: WidgetStateProperty.all(
                        Size(mainButtonSize, mainButtonSize)),
                    backgroundColor: WidgetStateProperty.all(Colors.red),
                    shape: WidgetStateProperty.all(CircleBorder())),
                onPressed: _startStopCPR,
                child: Text(
                  _doingCPR ? "Stop CPR" : "Start CPR",
                  style: Theme.of(context).textTheme.displayMedium,
                ),
              ),
            ),
            Visibility(
              // The values measured while doing CPR
              visible: _doingCPR,
              maintainState: true,
              maintainAnimation: true,
              child: Column(
                children: [
                  CPRInstructionView(instruction: _currentInstruction),
                  Text(
                    "Current frequency: ${_toBPM(_currentFrequency).round()} bpm",
                    style: mediumTextStyle,
                  ),
                  //Text("The recommend frequency is between 100 and 120 bpm", style: mediumTextStyle,),
                  Text(
                      "Current velocity: ${_currentVelocity.toStringAsFixed(4)}"),
                  Text(
                      "Current vertical accelaration: ${_currentVerticalAcc.toStringAsFixed(4)}"),
                  Text("Current x acc: ${_accX.toStringAsFixed(4)}"),
                  Text("Current y acc: ${_accY.toStringAsFixed(4)}"),
                  Text("Current z acc: ${_accZ.toStringAsFixed(4)}"),
                  Text("pitch: $_pitch"),
                  Text("roll: $_roll"),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Function that converts frequencies from Hz to bpm
double _toBPM(double currentFrequency) {
  return currentFrequency * 60;
}
