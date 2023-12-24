import 'dart:async';

import 'package:open_earable_flutter/src/open_earable_flutter.dart';
import 'package:flutter/material.dart';
import 'package:charts_flutter/flutter.dart' as charts;
import 'package:simple_kalman/simple_kalman.dart';
import 'package:collection/collection.dart';
import 'dart:math';
import 'dart:core';

class JumpHeightChart extends StatefulWidget {
  final OpenEarable _openEarable;
  final String _title;
  JumpHeightChart(this._openEarable, this._title);
  @override
  _JumpHeightChartState createState() =>
      _JumpHeightChartState(_openEarable, _title);
}

class _JumpHeightChartState extends State<JumpHeightChart> {
  final OpenEarable _openEarable;
  final String _title;
  late List<DataValue> _data;
  StreamSubscription? _dataSubscription;
  _JumpHeightChartState(this._openEarable, this._title);
  late int _minX = 0;
  late int _maxX = 0;
  late List<String> colors;
  List<charts.Series<dynamic, num>> seriesList = [];
  late double _minY;
  late double _maxY;
  final _errorMeasureAcc = 5.0;
  late SimpleKalman _kalmanX, _kalmanY, _kalmanZ;
  int _numDatapoints = 200;

  double _velocity = 0.0;
  /// Sampling rate time slice (inverse of frequency).
  double _timeSlice = 1 / 30.0; 
  /// Standard gravity in m/s^2.
  double _gravity = 9.81;
  /// Pitch angle in radians.
  double _pitch = 0.0;
  double _height = 0.0;

  _setupListeners() {
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
      _dataSubscription =
        _openEarable.sensorManager.subscribeToSensorData(0).listen((data) {
          int timestamp = data["timestamp"];
          _pitch = data["EULER"]["PITCH"];

          XYZValue rawAccData = XYZValue(
            timestamp: timestamp,
            x: data["ACC"]["X"],
            y: data["ACC"]["Y"],
            z: data["ACC"]["Z"],
            units: {"X": "m/s²", "Y": "m/s²", "Z": "m/s²"}
          );
          XYZValue filteredAccData = XYZValue(
            timestamp: timestamp,
            x: _kalmanX.filtered(data["ACC"]["X"]),
            y: _kalmanY.filtered(data["ACC"]["Y"]),
            z: _kalmanZ.filtered(data["ACC"]["Z"]),
            units: {"X": "m/s²", "Y": "m/s²", "Z": "m/s²"}
          );

          if (_title == "Height Data") {
            DataValue height = _calculateHeightData(filteredAccData);
            _updateData(height);
          }
          if (_title == "Raw Acceleration Data") {
            _updateData(rawAccData);
          } else if (_title == "Filtered Acceleration Data") {
            _updateData(filteredAccData);
          }
      });
  }

  DataValue _calculateHeightData(XYZValue accValue) {
    // Subtract gravity to get acceleration due to movement.
    double currentAcc = accValue.z * cos(_pitch) + accValue.x * sin(_pitch) - _gravity;;

    double threshold = 0.3;
    double accMagnitude = sqrt(accValue.x * accValue.x + accValue.y * accValue.y + accValue.z * accValue.z);
    bool isStationary = (accMagnitude > _gravity - threshold) && (accMagnitude < _gravity + threshold);
    /// Checks if the device is stationary based on acceleration magnitude.
    if (isStationary) {
        _velocity = 0.0;
    } else {
        // Integrate acceleration to get velocity.
        _velocity += currentAcc * _timeSlice;

        // Integrate velocity to get height.
        _height += _velocity * _timeSlice;
    }

    // Prevent height from going negative.
    _height = max(0, _height);
    return Jump(DateTime.fromMillisecondsSinceEpoch(accValue.timestamp), _height);
  }

  _updateData(DataValue value) {
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
      _maxX = value.timestamp;
      _minX = _data[0].timestamp;
    });
  }

  _getColor(String title) {
    if (title == "Height Data") {
      return ['#FF6347', '#3CB371', '#1E90FF'];
    } else if (title == "Raw Acceleration Data") {
      return ['#FFD700', '#FF4500', '#D8BFD8'];
    } else if (title == "Filtered Acceleration Data") {
      return ['#F08080', '#98FB98', '#ADD8E6'];
    }
  }

  @override
  void initState() {
    super.initState();
    _data = [];
    colors = _getColor(_title);
    _minY = -25;
    _maxY = 25;
    _setupListeners();
  }

  @override
  void dispose() {
    super.dispose();
    _dataSubscription?.cancel();
  }

  _checkLength(data) {
    if (data.length > _numDatapoints) {
      data.removeRange(0, data.length - _numDatapoints);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_title == "Height Data") {
      seriesList = [
        charts.Series<DataValue, int>(
          id: 'Height (m)',
          colorFn: (_, __) => charts.Color.fromHex(code: colors[0]),
          domainFn: (DataValue data, _) => data.timestamp,
          measureFn: (DataValue data, _) => (data as Jump).height,
          data: _data,
        ),
      ];
    } else {
      seriesList = [
        charts.Series<DataValue, int>(
          id: 'X${_data.isNotEmpty ? " (${_data[0].units['X']})" : ""}',
          colorFn: (_, __) => charts.Color.fromHex(code: colors[0]),
          domainFn: (DataValue data, _) => data.timestamp,
          measureFn: (DataValue data, _) => (data as XYZValue).x,
          data: _data,
        ),
        charts.Series<DataValue, int>(
          id: 'Y${_data.isNotEmpty ? " (${_data[0].units['Y']})" : ""}',
          colorFn: (_, __) => charts.Color.fromHex(code: colors[1]),
          domainFn: (DataValue data, _) => data.timestamp,
          measureFn: (DataValue data, _) => (data as XYZValue).y,
          data: _data,
        ),
        charts.Series<DataValue, int>(
          id: 'Z${_data.isNotEmpty ? " (${_data[0].units['Z']})" : ""}',
          colorFn: (_, __) => charts.Color.fromHex(code: colors[2]),
          domainFn: (DataValue data, _) => data.timestamp,
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
                position: charts.BehaviorPosition
                    .bottom, // To position the legend at the end (bottom). You can change this as per requirement.
                outsideJustification: charts.OutsideJustification
                    .middleDrawArea, // To justify the position.
                horizontalFirst: false, // To stack items horizontally.
                desiredMaxRows:
                    1, // Optional if you want to define max rows for the legend.
                entryTextStyle: charts.TextStyleSpec(
                  // Optional styling for the text.
                  color: charts.Color(r: 255, g: 255, b: 255),
                  fontSize: 12,
                ),
              )
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
                viewport: charts.NumericExtents(_minX, _maxX)),
          ),
        ),
      ],
    );
  }
}

abstract class DataValue {
  final int timestamp;
  final Map<dynamic, dynamic> units;
  double getMin();
  double getMax();
  DataValue({required this.timestamp, required this.units});
}

class XYZValue extends DataValue {
  final double x;
  final double y;
  final double z;

  XYZValue(
      {required timestamp,
      required this.x,
      required this.y,
      required this.z,
      required units})
      : super(timestamp: timestamp, units: units);

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
    return "timestamp: $timestamp\nx: $x, y: $y, z: $z";
  }
}

/// A class representing a jump with a time and height.
class Jump extends DataValue {
  final DateTime _time;
  final double _height;

  /// Constructs a Jump object with a time and height.
  Jump(DateTime time, double height)
      : _time = time,
        _height = height,
        super(
          timestamp: time.millisecondsSinceEpoch, 
          units: {'height': 'meters'} // Providing default units
        );

  @override
  double getMin() {
    // Implement logic for min value
    // For example, it might always be 0 for a jump.
    return 0.0;
  }

  @override
  double getMax() {
    // Implement logic for max value
    // For Jump, it's likely the height.
    return _height;
  }

  // Optionally, if you need to access time and height outside, consider adding getters.
  DateTime get time => _time;
  double get height => _height;
}
