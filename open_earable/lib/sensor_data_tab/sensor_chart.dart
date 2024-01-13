import 'dart:async';

import 'package:flutter/scheduler.dart';
import 'package:open_earable_flutter/src/open_earable_flutter.dart';
import 'package:flutter/material.dart';
import 'package:charts_flutter/flutter.dart' as charts;
import 'package:simple_kalman/simple_kalman.dart';
import 'package:collection/collection.dart';
import 'dart:math';
import 'dart:core';

class EarableDataChart extends StatefulWidget {
  final OpenEarable _openEarable;
  final String _title;
  EarableDataChart(this._openEarable, this._title);
  @override
  _EarableDataChartState createState() =>
      _EarableDataChartState(_openEarable, _title);
}

class _EarableDataChartState extends State<EarableDataChart> {
  final OpenEarable _openEarable;
  final String _title;
  late List<SensorData> _data;
  StreamSubscription? _dataSubscription;
  _EarableDataChartState(this._openEarable, this._title);
  late int _minX = 0;
  late int _maxX = 0;
  late List<String> colors;
  List<charts.Series<dynamic, num>> seriesList = [];
  late double _minY;
  late double _maxY;
  final errorMeasure = {"ACC": 5.0, "GYRO": 10.0, "MAG": 25.0};
  late SimpleKalman kalmanX, kalmanY, kalmanZ;
  late String _sensorName;
  int _numDatapoints = 200;
  Map<String, String> _units = {
    "Accelerometer": "m/s\u00B2",
    "Gyroscope": "°/s",
    "Magnetometer": "µT",
    "Pressure": "Pa",
    "Temperature": "°C"
  };
  _setupListeners() {
    if (_title == "Pressure" || _title == "Temperature") {
      _dataSubscription =
          _openEarable.sensorManager.subscribeToSensorData(1).listen((data) {
        //units.addAll(data["TEMP"]["units"]);
        int timestamp = data["timestamp"];
        SensorData sensorData = SensorData(
            name: _sensorName,
            timestamp: timestamp,
            values: [data[_sensorName][_title]],
            //temperature: data["TEMP"]["Temperature"],
            units: data[_sensorName]["units"]);
        _updateData(sensorData);
      });
    } else {
      kalmanX = SimpleKalman(
          errorMeasure: errorMeasure[_sensorName]!,
          errorEstimate: errorMeasure[_sensorName]!,
          q: 0.9);
      kalmanY = SimpleKalman(
          errorMeasure: errorMeasure[_sensorName]!,
          errorEstimate: errorMeasure[_sensorName]!,
          q: 0.9);
      kalmanZ = SimpleKalman(
          errorMeasure: errorMeasure[_sensorName]!,
          errorEstimate: errorMeasure[_sensorName]!,
          q: 0.9);
      _dataSubscription =
          _openEarable.sensorManager.subscribeToSensorData(0).listen((data) {
        int timestamp = data["timestamp"];
        SensorData xyzValue = SensorData(
            name: _title,
            timestamp: timestamp,
            values: [
              kalmanX.filtered(data[_sensorName]["X"]),
              kalmanY.filtered(data[_sensorName]["Y"]),
              kalmanZ.filtered(data[_sensorName]["Z"]),
            ],
            units: data[_sensorName]["units"]);

        _updateData(xyzValue);
      });
    }
  }

  _updateData(SensorData value) {
    setState(() {
      _data.add(value);
      _checkLength(_data);
      SensorData? maxXYZValue = maxBy(_data, (SensorData b) => b.getMax());
      SensorData? minXYZValue = minBy(_data, (SensorData b) => b.getMin());

      if (maxXYZValue == null || minXYZValue == null) {
        return;
      }
      double maxY = maxXYZValue!.getMax();
      double minY = minXYZValue!.getMin();
      double maxAbsValue = max(maxY.abs(), minY.abs());
      _maxY = (_title == "Pressure" || _title == "Temperature")
          ? maxY
          : maxAbsValue;

      _minY = (_title == "Pressure" || _title == "Temperature")
          ? minY
          : -maxAbsValue;
      _maxX = value.timestamp;
      _minX = _data[0].timestamp;
    });
  }

  _getColor(String title) {
    if (title == "Accelerometer") {
      return ['#FF6347', '#3CB371', '#1E90FF'];
    } else if (title == "Gyroscope") {
      return ['#FFD700', '#FF4500', '#D8BFD8'];
    } else if (title == "Magnetometer") {
      return ['#F08080', '#98FB98', '#ADD8E6'];
    } else if (title == "Pressure") {
      return ['#32CD32'];
    } else if (title == "Temperature") {
      return ['#FFA07A'];
    }
  }

  @override
  void initState() {
    super.initState();
    _data = [];
    switch (_title) {
      case 'Pressure':
        _sensorName = 'BARO';
      case 'Temperature':
        _sensorName = 'TEMP';
      case 'Accelerometer':
        _sensorName = 'ACC';
      case 'Gyroscope':
        _sensorName = 'GYRO';
      case 'Magnetometer':
        _sensorName = 'MAG';
    }
    colors = _getColor(_title);
    if (_title == 'Temperature') {
      _minY = 0;
      _maxY = 30;
    } else if (_title == 'Pressure') {
      _minY = 0;
      _maxY = 130000;
    } else if (_title == "Magnetometer") {
      _minY = -200;
      _maxY = 200;
    } else {
      _minY = -25;
      _maxY = 25;
    }
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
    if (_title == 'Pressure' || _title == 'Temperature') {
      seriesList = [
        charts.Series<SensorData, int>(
          id: '$_title${_data.isNotEmpty ? " (${_units[_title]})" : ""}',
          colorFn: (_, __) => charts.Color.fromHex(code: colors[0]),
          domainFn: (SensorData data, _) => data.timestamp,
          measureFn: (SensorData data, _) => data.values[0],
          data: _data,
        ),
      ];
    } else {
      seriesList = [
        charts.Series<SensorData, int>(
          id: 'X${_data.isNotEmpty ? " (${_units[_title]})" : ""}',
          colorFn: (_, __) => charts.Color.fromHex(code: colors[0]),
          domainFn: (SensorData data, _) => data.timestamp,
          measureFn: (SensorData data, _) => data.values[0],
          data: _data,
        ),
        charts.Series<SensorData, int>(
          id: 'Y${_data.isNotEmpty ? " (${_units[_title]})" : ""}',
          colorFn: (_, __) => charts.Color.fromHex(code: colors[1]),
          domainFn: (SensorData data, _) => data.timestamp,
          measureFn: (SensorData data, _) => data.values[1],
          data: _data,
        ),
        charts.Series<SensorData, int>(
          id: 'Z${_data.isNotEmpty ? " (${_units[_title]})" : ""}',
          colorFn: (_, __) => charts.Color.fromHex(code: colors[2]),
          domainFn: (SensorData data, _) => data.timestamp,
          measureFn: (SensorData data, _) => data.values[2],
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
              tickProviderSpec: charts.BasicNumericTickProviderSpec(
                  desiredTickCount: 7,
                  zeroBound: false,
                  dataIsInWholeNumbers: false),
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

class SensorData {
  final String name;
  final int timestamp;
  final List<double> values;
  final Map<dynamic, dynamic> units;

  SensorData(
      {required this.name,
      required this.timestamp,
      required this.values,
      required this.units});

  double getMax() {
    return values.reduce(
        (currentMax, element) => element > currentMax ? element : currentMax);
  }

  double getMin() {
    return values.reduce(
        (currentMin, element) => element < currentMin ? element : currentMin);
  }

  @override
  String toString() {
    return "sensor name: $name\ntimestamp: $timestamp\nvalues: ${values.join(", ")}";
  }
}
