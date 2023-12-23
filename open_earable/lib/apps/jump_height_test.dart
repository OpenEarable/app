import 'package:flutter/material.dart';
import 'dart:async';
import 'package:open_earable_flutter/src/open_earable_flutter.dart';
import 'package:charts_flutter/flutter.dart' as charts;
import 'package:simple_kalman/simple_kalman.dart';
import 'dart:math';

/// An app that lets you test your jump height using an OpenEarable device.
class JumpHeightTest extends StatefulWidget {
  final OpenEarable _openEarable;

  /// Constructs a JumpHeightTest widget with a given OpenEarable device.
  JumpHeightTest(this._openEarable);

  @override
  _JumpHeightTestState createState() => _JumpHeightTestState(_openEarable);
}

/// A class representing a jump with a time and height.
class Jump {
  final DateTime _time;
  final double _height;

  /// Constructs a Jump object with a time and height.
  Jump(this._time, this._height);
}

/// A stateless widget to display jump heights in a bar chart.
class HeightChart extends StatelessWidget {
  final List<charts.Series> _seriesList;
  final bool _animate;

  /// Constructs a HeightChart widget with given series list and animate flag.
  HeightChart(this._seriesList, {required bool animate}) : _animate = animate;

  @override
  Widget build(BuildContext context) {
    return new charts.BarChart(
      _seriesList.cast<charts.Series<Jump, String>>(),
      animate: _animate,
    );
  }
}

/// State class for JumpHeightTest widget.
class _JumpHeightTestState extends State<JumpHeightTest> {
  /// Stores the start time of a jump test.
  DateTime? _startTime;
  /// Current height calculated from sensor data.
  double _height = 0.0;
  // List to store each jump's data.
  List<Jump> _jumpData = [];
  // Flag to indicate if jump measurement is ongoing.
  bool _isJumping = false;
  /// Instance of OpenEarable device.
  final OpenEarable _openEarable;
  /// Flag to indicate if an OpenEarable device is connected.
  bool _earableConnected = false;
  /// Subscription to IMU sensor data.
  StreamSubscription? _imuSubscription;
  /// Stores the maximum height achieved in a jump.
  double _maxHeight = 0.0;  // Variable to keep track of maximum jump height
  /// Error measure for Kalman filter.
  final _errorMeasureAcc = 5.0;
  /// Kalman filters for accelerometer data.
  late SimpleKalman _kalmanX, _kalmanY, _kalmanZ;
  /// Current velocity calculated from acceleration.
  double _velocity = 0.0;
  /// Sampling rate time slice (inverse of frequency).
  double _timeSlice = 1 / 30.0; 
  /// Standard gravity in m/s^2.
  double _gravity = 9.81;
  /// X-axis acceleration.
  double _accX = 0.0;
  /// Y-axis acceleration.
  double _accY = 0.0;
  /// Z-axis acceleration.
  double _accZ = 0.0;
  /// Pitch angle in radians.
  double _pitch = 0.0;

  /// Constructs a _JumpHeightTestState object with a given OpenEarable device.
  _JumpHeightTestState(this._openEarable);

  /// Initializes state and sets up listeners for sensor data.
  @override
  void initState() {
    super.initState();
    // Initialize Kalman filters.
    _initializeKalmanFilters();
    // Set up listeners for sensor data.
    if (_openEarable.bleManager.connected) {
      _setupListeners();
      _earableConnected = true;
    }
  }

  /// Disposes IMU data subscription when the state object is removed.
  @override
  void dispose() {
    super.dispose();
    _imuSubscription?.cancel();
  }

  /// Sets up listeners to receive sensor data from the OpenEarable device.
  _setupListeners() {
    _imuSubscription =
      _openEarable.sensorManager.subscribeToSensorData(0).listen((data) {
        // Only process sensor data if jump measurement is ongoing.
        if (!_isJumping) {
          return;
        }
        _processSensorData(data);
      });
  }
  
  /// Starts the jump height measurement process.
  /// It sets the sampling rate, initializes or resets variables, and begins listening to sensor data.
  void _startJump() {
    // Set sampling rate to maximum.
    _openEarable.sensorManager.writeSensorConfig(_buildSensorConfig());
    _startTime = DateTime.now();

    setState(() {
      // Clear data from previous jump.
      _jumpData.clear();
      _isJumping = true;
      _height = 0.0;
      _velocity = 0.0;
      // Reset max height on starting a new jump
      _maxHeight = 0.0;
    });
  }

  /// Stops the jump height measurement process.
  void _stopJump() {
    if (_isJumping) {
      setState(() {
        _isJumping = false;
      });
    }
  }

  /// Initializes Kalman filters for accelerometer data.
  void _initializeKalmanFilters() {
    _kalmanX = SimpleKalman(
        errorMeasure: _errorMeasureAcc,
        errorEstimate: _errorMeasureAcc,
        q: 0.9);
    _kalmanY = SimpleKalman(
        errorMeasure: _errorMeasureAcc,
        errorEstimate: _errorMeasureAcc,
        q: 0.9);
    _kalmanZ = SimpleKalman(
        errorMeasure: _errorMeasureAcc,
        errorEstimate: _errorMeasureAcc,
        q: 0.9);
  }

  /// Processes incoming sensor data and updates jump height.
  void _processSensorData(Map<String, dynamic> data) {
    /// Kalman filtered accelerometer data for X.
    _accX = _kalmanX.filtered(data["ACC"]["X"]);
    /// Kalman filtered accelerometer data for Y.
    _accY = _kalmanY.filtered(data["ACC"]["Y"]);
    /// Kalman filtered accelerometer data for Z.
    _accZ = _kalmanZ.filtered(data["ACC"]["Z"]);
    /// Pitch angle in radians.
    _pitch = data["EULER"]["PITCH"];
    // Calculates the current vertical acceleration.
    // It adjusts the Z-axis acceleration with the pitch angle to account for the device's orientation.
    double currentAcc = _accZ * cos(_pitch) + _accX * sin(_pitch);
    // Subtract gravity to get acceleration due to movement.
    currentAcc -= _gravity; 
    
    _updateHeight(currentAcc);
  }

  /// Checks if the device is stationary based on acceleration magnitude.
  bool _deviceIsStationary(double threshold) {
    double accMagnitude = sqrt(_accX * _accX + _accY * _accY + _accZ * _accZ);
    bool isStationary = (accMagnitude > _gravity - threshold) && (accMagnitude < _gravity + threshold);
    return isStationary;
  }

  /// Updates the current height based on the current acceleration.
  /// If the device is stationary, the velocity is reset to 0.
  /// Otherwise, it integrates the current acceleration to update velocity and height.
  _updateHeight(double currentAcc) {
    setState(() {
      if (_deviceIsStationary(0.3)) {
          _velocity = 0.0;
      } else {
          // Integrate acceleration to get velocity.
          _velocity += currentAcc * _timeSlice;

          // Integrate velocity to get height.
          _height += _velocity * _timeSlice;
      }

      // Prevent height from going negative.
      _height = max(0, _height);

      // Update maximum height if the current height is greater.
      if (_height > _maxHeight) {
        _maxHeight = _height;
      }

      _jumpData.add(Jump(DateTime.now(), _height));
    });
    // For debugging.
    // print("Stationary: ${deviceIsStationary(0.3)}, Acc: $currentAcc, Vel: $velocity, Height: $height");
  }

  /// Builds the UI for the jump height test.
  /// It displays a line chart of jump height over time and the maximum jump height achieved.
  @override
  Widget build(BuildContext context) {
    List<charts.Series<Jump, num>> jumpDataSeries = [
      charts.Series(
        id: "Jumps",
        data: _jumpData,
        // X-axis: time in milliseconds since the start of the jump.
        domainFn: (Jump series, _) => series._time.difference(_startTime!).inMilliseconds,
        measureFn: (Jump series, _) => series._height,
        colorFn: (Jump series, _) => charts.MaterialPalette.cyan.shadeDefault,
      )
    ];
    return Scaffold(
      appBar: AppBar(
        title: Text('Jump Height Test'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Expanded(
              child: charts.LineChart(
                jumpDataSeries,
                animate: false,
                behaviors: [
                  // X-axis label.
                  new charts.ChartTitle('Time (ms)',
                      behaviorPosition: charts.BehaviorPosition.bottom,
                      titleStyleSpec: charts.TextStyleSpec(
                        color: charts.MaterialPalette.white,
                        fontSize: 10
                      ),
                      titleOutsideJustification: charts.OutsideJustification.middleDrawArea),
                  // Y-axis label.
                  new charts.ChartTitle('Height (m)',
                      behaviorPosition: charts.BehaviorPosition.start,
                      titleStyleSpec: charts.TextStyleSpec(
                        color: charts.MaterialPalette.white,
                        fontSize: 10
                      ),
                      titleOutsideJustification: charts.OutsideJustification.middleDrawArea)
                ],
                // Include timeline points in line.
                defaultRenderer: charts.LineRendererConfig(includePoints: true),
                ),
            ),
            Text(
              'Max Height: ${_maxHeight.toStringAsFixed(2)} m',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            Column(children: [
              ElevatedButton(
                onPressed: _earableConnected ? () { _isJumping ? _stopJump() : _startJump(); } : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: !_isJumping ? Colors.greenAccent : Colors.red,
                  foregroundColor: Colors.black,
                ),
                child: Text(_isJumping ? 'Stop Jump' : 'Start Jump'),
              ),
              Visibility(
                // Show error message if no OpenEarable device is connected.
                visible: !_earableConnected,
                maintainState: true,
                maintainAnimation: true,
                maintainSize: true,
                child: Text(
                  "No Earable Connected",
                  style: TextStyle(
                    color: Colors.red,
                    fontSize: 12,
                  ),
                ),
              )
            ])
          ],
        ),
      ),
    );
  }

  /// Builds a sensor configuration for the OpenEarable device.
  /// Sets the sensor ID, sampling rate, and latency.
  OpenEarableSensorConfig _buildSensorConfig() {
    return OpenEarableSensorConfig(
      sensorId: 0,
      samplingRate: 30,
      latency: 0,
    );
  }
}
