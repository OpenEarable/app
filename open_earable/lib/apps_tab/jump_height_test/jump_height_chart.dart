import 'dart:async';

import 'package:open_earable_flutter/open_earable_flutter.dart';
import 'package:flutter/material.dart';
import 'package:community_charts_flutter/community_charts_flutter.dart'
    as charts;
import 'package:simple_kalman/simple_kalman.dart';
import 'package:collection/collection.dart';
import 'dart:math';
import 'dart:core';

/// A class representing a Chart for Jump Height.
class JumpHeightChart extends StatefulWidget {
  /// The OpenEarable object.
  final OpenEarable openEarable;

  /// The title of the chart.
  final String title;

  /// Constructs a JumpHeightChart object with an OpenEarable object and a title.
  const JumpHeightChart(this.openEarable, this.title, {super.key});

  @override
  State<JumpHeightChart> createState() => _JumpHeightChartState();
}

/// A class representing the state of a JumpHeightChart.
class _JumpHeightChartState extends State<JumpHeightChart> {
  /// The data of the chart.
  late List<DataValue> _data;

  /// The subscription to the data.
  StreamSubscription? _dataSubscription;

  /// The minimum x value of the chart.
  late int _minX = 0;

  /// The maximum x value of the chart.
  late int _maxX = 0;

  /// The colors of the chart.
  late List<String> colors;

  /// The series of the chart.
  List<charts.Series<dynamic, num>> seriesList = [];

  /// The minimum y value of the chart.
  late double _minY;

  /// The maximum y value of the chart.
  late double _maxY;

  /// The error measure of the Kalman filter.
  final _errorMeasureAcc = 5.0;

  /// The Kalman filter for the x value.
  late SimpleKalman _kalmanX;

  /// The Kalman filter for the y value.
  late SimpleKalman _kalmanY;

  /// The Kalman filter for the z value.
  late SimpleKalman _kalmanZ;

  /// The number of datapoints to display on the chart.
  final int _numDatapoints = 200;

  /// The velocity of the device.
  double _velocity = 0.0;

  /// Sampling rate time slice (inverse of frequency).
  final double _timeSlice = 1.0 / 30.0;

  /// Standard gravity in m/s^2.
  final double _gravity = 9.81;

  /// Pitch angle in radians.
  double _pitch = 0.0;

  /// The height of the jump.
  double _height = 0.0;

  /// Sets up the listeners for the data.
  void _setupListeners() {
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
    _dataSubscription = widget.openEarable.sensorManager
        .subscribeToSensorData(0)
        .listen((data) {
      int timestamp = data["timestamp"];
      _pitch = data["EULER"]["PITCH"];

      XYZValue rawAccData = XYZValue(
        timestamp: timestamp,
        x: data["ACC"]["X"],
        y: data["ACC"]["Y"],
        z: data["ACC"]["Z"],
        units: {"X": "m/s²", "Y": "m/s²", "Z": "m/s²"},
      );
      XYZValue filteredAccData = XYZValue(
        timestamp: timestamp,
        x: _kalmanX.filtered(data["ACC"]["X"]),
        y: _kalmanY.filtered(data["ACC"]["Y"]),
        z: _kalmanZ.filtered(data["ACC"]["Z"]),
        units: {"X": "m/s²", "Y": "m/s²", "Z": "m/s²"},
      );

      switch (widget.title) {
        case "Height Data":
          DataValue height = _calculateHeightData(filteredAccData);
          _updateData(height);
          break;
        case "Raw Acceleration Data":
          _updateData(rawAccData);
          break;
        case "Filtered Acceleration Data":
          _updateData(filteredAccData);
          break;
        default:
          throw ArgumentError("Invalid tab title.");
      }
    });
  }

  /// Calculates the height of the jump.
  DataValue _calculateHeightData(XYZValue accValue) {
    // Subtract gravity to get acceleration due to movement.
    double currentAcc =
        accValue.z * cos(_pitch) + accValue.x * sin(_pitch) - _gravity;

    double threshold = 0.3;
    double accMagnitude = sqrt(
      accValue.x * accValue.x +
          accValue.y * accValue.y +
          accValue.z * accValue.z,
    );
    bool isStationary = (accMagnitude > _gravity - threshold) &&
        (accMagnitude < _gravity + threshold);
    // Checks if the device is stationary based on acceleration magnitude.
    if (isStationary) {
      _velocity = 0.0;
      _height = 0.0;
    } else {
      // Integrate acceleration to get velocity.
      _velocity += currentAcc * _timeSlice;

      // Integrate velocity to get height.
      _height += _velocity * _timeSlice;
    }
    // Prevent height from going negative.
    _height = max(0, _height);

    return Jump(
      DateTime.fromMillisecondsSinceEpoch(accValue._timestamp),
      _height,
    );
  }

  /// Updates the data of the chart.
  void _updateData(DataValue value) {
    setState(() {
      _data.add(value);
      _checkLength(_data);
      DataValue? maxXYZValue = maxBy(_data, (DataValue b) => b.getMax());
      DataValue? minXYZValue = minBy(_data, (DataValue b) => b.getMin());
      if (maxXYZValue == null || minXYZValue == null) {
        return;
      }
      double maxAbsValue =
          max(maxXYZValue.getMax().abs(), minXYZValue.getMin().abs());
      _maxY = maxAbsValue;

      _minY = -maxAbsValue;
      _maxX = value._timestamp;
      _minX = _data[0]._timestamp;
    });
  }

  /// Gets the color of the chart lines.
  List<String> _getColor(String title) {
    switch (title) {
      case "Height Data":
        // Blue, Orange, and Teal - Good for colorblindness
        return ['#007bff', '#ff7f0e', '#2ca02c'];
      case "Raw Acceleration Data":
        // Purple, Magenta, and Cyan - Diverse hue and brightness
        return ['#9467bd', '#d62728', '#17becf'];
      case "Filtered Acceleration Data":
        // Olive, Brown, and Navy - High contrast
        return ['#8c564b', '#e377c2', '#1f77b4'];
      default:
        throw ArgumentError("Invalid tab title.");
    }
  }

  @override
  void initState() {
    super.initState();
    _data = [];
    colors = _getColor(widget.title);
    _minY = -25;
    _maxY = 25;
    _setupListeners();
  }

  @override
  void dispose() {
    super.dispose();
    _dataSubscription?.cancel();
  }

  /// Checks the length of the data an removes the oldest data if it is too long.
  void _checkLength(data) {
    if (data.length > _numDatapoints) {
      data.removeRange(0, data.length - _numDatapoints);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.title == "Height Data") {
      seriesList = [
        charts.Series<DataValue, int>(
          id: 'Height (m)',
          colorFn: (_, __) => charts.Color.fromHex(code: colors[0]),
          domainFn: (DataValue data, _) => data._timestamp,
          measureFn: (DataValue data, _) => (data as Jump)._height,
          data: _data,
        ),
      ];
    } else {
      seriesList = [
        charts.Series<DataValue, int>(
          id: 'X${_data.isNotEmpty ? " (${_data[0]._units['X']})" : ""}',
          colorFn: (_, __) => charts.Color.fromHex(code: colors[0]),
          domainFn: (DataValue data, _) => data._timestamp,
          measureFn: (DataValue data, _) => (data as XYZValue).x,
          data: _data,
        ),
        charts.Series<DataValue, int>(
          id: 'Y${_data.isNotEmpty ? " (${_data[0]._units['Y']})" : ""}',
          colorFn: (_, __) => charts.Color.fromHex(code: colors[1]),
          domainFn: (DataValue data, _) => data._timestamp,
          measureFn: (DataValue data, _) => (data as XYZValue).y,
          data: _data,
        ),
        charts.Series<DataValue, int>(
          id: 'Z${_data.isNotEmpty ? " (${_data[0]._units['Z']})" : ""}',
          colorFn: (_, __) => charts.Color.fromHex(code: colors[2]),
          domainFn: (DataValue data, _) => data._timestamp,
          measureFn: (DataValue data, _) => (data as XYZValue).z,
          data: _data,
        ),
      ];
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
        ),
        Expanded(
          child: charts.LineChart(
            seriesList,
            animate: false,
            behaviors: [
              charts.SeriesLegend(
                position: charts.BehaviorPosition.bottom,
                // To position the legend at the end (bottom). You can change this as per requirement.
                outsideJustification:
                    charts.OutsideJustification.middleDrawArea,
                // To justify the position.
                horizontalFirst: false,
                // To stack items horizontally.
                desiredMaxRows: 1,
                // Optional if you want to define max rows for the legend.
                entryTextStyle: charts.TextStyleSpec(
                  // Optional styling for the text.
                  color: charts.Color(r: 255, g: 255, b: 255),
                  fontSize: 12,
                ),
              ),
            ],
            primaryMeasureAxis: charts.NumericAxisSpec(
              renderSpec: charts.GridlineRendererSpec(
                labelStyle: charts.TextStyleSpec(
                  fontSize: 14,
                  color: charts.MaterialPalette.white, // Set the color here
                ),
              ),
              viewport: charts.NumericExtents(_minY, _maxY),
            ),
            domainAxis: charts.NumericAxisSpec(
              renderSpec: charts.GridlineRendererSpec(
                labelStyle: charts.TextStyleSpec(
                  fontSize: 14,
                  color: charts.MaterialPalette.white, // Set the color here
                ),
              ),
              viewport: charts.NumericExtents(_minX, _maxX),
            ),
          ),
        ),
      ],
    );
  }
}

/// A class representing a generic data value.
abstract class DataValue {
  /// The timestamp of the data.
  final int _timestamp;

  /// The units of the data.
  final Map<dynamic, dynamic> _units;

  /// Returns the minimum value of the data.
  double getMin();

  /// Returns the maximum value of the data.
  double getMax();

  /// Constructs a DataValue object with a timestamp and units.
  DataValue({required int timestamp, required Map<dynamic, dynamic> units})
      : _units = units,
        _timestamp = timestamp;
}

/// A class representing a generic XYZ value.
class XYZValue extends DataValue {
  /// The x value of the data.
  final double x;

  /// The y value of the data.
  final double y;

  /// The z value of the data.
  final double z;

  /// Constructs a XYZValue object with a timestamp, x, y, z, and units.
  XYZValue({
    required super.timestamp,
    required this.x,
    required this.y,
    required this.z,
    required super.units,
  });

  @override
  double getMax() {
    return max(x, max(y, z));
  }

  @override
  double getMin() {
    return min(x, min(y, z));
  }

  @override
  String toString() {
    return "timestamp: $_timestamp\nx: $x, y: $y, z: $z";
  }
}

/// A class representing a jump with a time and height.
class Jump extends DataValue {
  /// The time of the jump.
  final DateTime _time;

  /// The height of the jump.
  final double _height;

  /// Constructs a Jump object with a time and height.
  Jump(DateTime time, double height)
      : _time = time,
        _height = height,
        super(
          timestamp: time.millisecondsSinceEpoch,
          units: {'height': 'meters'},
        );

  @override
  double getMin() {
    return 0.0;
  }

  @override
  double getMax() {
    return _height;
  }

  @override
  String toString() {
    return "timestamp: ${_time.millisecondsSinceEpoch}\nheight $_height";
  }
}
