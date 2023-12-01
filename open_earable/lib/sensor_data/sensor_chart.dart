import 'dart:async';

import 'package:open_earable_flutter/src/open_earable_flutter.dart';
import 'package:flutter/material.dart';
import 'package:charts_flutter/flutter.dart' as charts;
import 'package:simple_kalman/simple_kalman.dart';

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
  late List<DataValue> _data;
  StreamSubscription? _dataSubscription;
  _EarableDataChartState(this._openEarable, this._title);
  late int _minX = 0;
  late int _maxX = 0;
  late List<String> colors;
  List<charts.Series<dynamic, num>> seriesList = [];
  late int minY;
  late int maxY;
  final errorMeasure = {"ACC": 5.0, "GYRO": 10.0, "MAG": 25.0};
  late SimpleKalman kalmanX, kalmanY, kalmanZ;
  late String _sensorName;
  int _numDatapoints = 200;
  _setupListeners() {
    if (_title == "Pressure Data") {
      _dataSubscription =
          _openEarable.sensorManager.subscribeToSensorData(1).listen((data) {
        Map<dynamic, dynamic> units = {};
        units.addAll(data["BARO"]["units"]);
        units.addAll(data["TEMP"]["units"]);
        int timestamp = data["timestamp"];
        BarometerValue barometerValue = BarometerValue(
            timestamp: timestamp,
            pressure: data["BARO"]["Pressure"],
            temperature: data["TEMP"]["Temperature"],
            units: units);
        setState(() {
          _data.add(barometerValue);
          _checkLength(_data);
          _maxX = barometerValue.timestamp;
          _minX = _data[0].timestamp;
        });
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
        /*
        XYZValue accelerometerValue = XYZValue(
            timestamp: timestamp,
            x: data["ACC"]["X"],
            y: data["ACC"]["Y"],
            z: data["ACC"]["Z"],
            units: data["ACC"]["units"]);
        XYZValue gyroscopeValue = XYZValue(
            timestamp: timestamp,
            x: data["GYRO"]["X"],
            y: data["GYRO"]["Y"],
            z: data["GYRO"]["Z"],
            units: data["GYRO"]["units"]);
        XYZValue magnetometerValue = XYZValue(
            timestamp: timestamp,
            x: data["MAG"]["X"],
            y: data["MAG"]["Y"],
            z: data["MAG"]["Z"],
            units: data["MAG"]["units"]);
        */
        XYZValue dataValue = XYZValue(
            timestamp: timestamp,
            z: kalmanZ.filtered(data[_sensorName]["Z"]),
            x: kalmanX.filtered(data[_sensorName]["X"]),
            y: kalmanY.filtered(data[_sensorName]["Y"]),
            units: data["ACC"]["units"]);

        setState(() {
          _data.add(dataValue);
          _checkLength(_data);
          _maxX = dataValue.timestamp;
          _minX = _data[0].timestamp;
        });
      });
    }
  }

  _getColor(String title) {
    if (title == "Accelerometer Data") {
      return ['#FF6347', '#3CB371', '#1E90FF'];
    } else if (title == "Gyroscope Data") {
      return ['#FFD700', '#FF4500', '#D8BFD8'];
    } else if (title == "Magnetometer Data") {
      return ['#F08080', '#98FB98', '#ADD8E6'];
    } else if (title == "Pressure Data") {
      return ['#32CD32', '#FFA07A'];
    }
  }

  @override
  void initState() {
    super.initState();
    _data = [];
    switch (_title) {
      case 'Pressure Data':
        _sensorName = 'BARO';
      case 'Accelerometer Data':
        _sensorName = 'ACC';
      case 'Gyroscope Data':
        _sensorName = 'GYRO';
      case 'Magnetometer Data':
        _sensorName = 'MAG';
    }
    colors = _getColor(_title);
    if (_title == 'Pressure Data') {
      minY = 0;
      maxY = 130;
    } else if (_title == "Magnetometer Data") {
      minY = -200;
      maxY = 200;
    } else {
      minY = -25;
      maxY = 25;
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
    if (_title == 'Pressure Data') {
      seriesList = [
        charts.Series<DataValue, int>(
          id: 'Pressure${_data.isNotEmpty ? " (${_data[0].units['Pressure']})" : ""}',
          colorFn: (_, __) => charts.Color.fromHex(code: colors[0]),
          domainFn: (DataValue data, _) => data.timestamp,
          measureFn: (DataValue data, _) =>
              (data as BarometerValue).pressure / 1000,
          data: _data,
        ),
        charts.Series<DataValue, int>(
          id: 'Temperature${_data.isNotEmpty ? " (${_data[0].units['Temperature']})" : ""}',
          colorFn: (_, __) => charts.Color.fromHex(code: colors[1]),
          domainFn: (DataValue data, _) => data.timestamp,
          measureFn: (DataValue data, _) =>
              (data as BarometerValue).temperature,
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
              viewport: charts.NumericExtents(minY, maxY),
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
  String toString() {
    return "timestamp: $timestamp\nx: $x, y: $y, z: $z";
  }
}

class BarometerValue extends DataValue {
  final double pressure;
  final double temperature;

  BarometerValue(
      {required timestamp,
      required this.pressure,
      required this.temperature,
      required units})
      : super(timestamp: timestamp, units: units);
  @override
  String toString() {
    return "timestamp: $timestamp\npressure: $pressure, temperature:$temperature";
  }
}
