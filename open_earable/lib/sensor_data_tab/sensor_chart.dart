import 'dart:async';

import 'sensor_html_chart_stub.dart'
    if (dart.library.html) 'sensor_html_chart.dart';
import 'package:open_earable/shared/earable_not_connected_warning.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart';
import 'package:flutter/material.dart';
import 'package:community_charts_flutter/community_charts_flutter.dart'
    as charts;
import 'package:simple_kalman/simple_kalman.dart';
import 'package:collection/collection.dart';
import 'dart:math';
import 'dart:core';
import 'package:flutter/foundation.dart';

class EarableDataChart extends StatefulWidget {
  final OpenEarable openEarable;
  final String sensorName;
  final String chartTitle;
  final String shortTitle;

  const EarableDataChart({
    required this.openEarable,
    required this.sensorName,
    required this.chartTitle,
    String? shortTitle,
    super.key,
  }) : shortTitle = shortTitle ?? chartTitle;

  @override
  State<EarableDataChart> createState() => _EarableDataChartState();

  static List<EarableDataChart> _getV1DataCharts(OpenEarable openEarable) {
    return [
      EarableDataChart(
        openEarable: openEarable,
        sensorName: 'ACC',
        chartTitle: 'Accelerometer',
        shortTitle: 'Acc.',
      ),
      EarableDataChart(
        openEarable: openEarable,
        sensorName: 'GYRO',
        chartTitle: 'Gyroscope',
        shortTitle: 'Gyro.',
      ),
      EarableDataChart(
        openEarable: openEarable,
        sensorName: 'MAG',
        chartTitle: 'Magnetometer',
        shortTitle: 'Magn.',
      ),
      EarableDataChart(
        openEarable: openEarable,
        sensorName: 'BARO',
        chartTitle: 'Pressure',
        shortTitle: 'Press.',
      ),
      EarableDataChart(
        openEarable: openEarable,
        sensorName: 'TEMP',
        chartTitle: 'Temperature (Ambient)',
        shortTitle: 'Temp. (A.)',
      ),
    ];
  }

  static List<EarableDataChart> _getV2DataCharts(OpenEarable openEarable) {
    return [
      EarableDataChart(
        openEarable: openEarable,
        sensorName: 'ACC',
        chartTitle: 'Accelerometer',
        shortTitle: 'Acc.',
      ),
      EarableDataChart(
        openEarable: openEarable,
        sensorName: 'GYRO',
        chartTitle: 'Gyroscope',
        shortTitle: 'Gyro.',
      ),
      EarableDataChart(
        openEarable: openEarable,
        sensorName: 'MAG',
        chartTitle: 'Magnetometer',
        shortTitle: 'Magn.',
      ),
      EarableDataChart(
        openEarable: openEarable,
        sensorName: 'BARO',
        chartTitle: 'Pressure',
        shortTitle: 'Press.',
      ),
      EarableDataChart(
        openEarable: openEarable,
        sensorName: 'TEMP',
        chartTitle: 'Temperature (Ambient)',
        shortTitle: 'Temp. (A.)',
      ),
      EarableDataChart(
        openEarable: openEarable,
        sensorName: 'OPTTEMP',
        chartTitle: 'Temperature (Surface)',
        shortTitle: 'Temp. (S.)',
      ),
      EarableDataChart(
        openEarable: openEarable,
        sensorName: 'PULSOX',
        chartTitle: 'Heart Rate',
        shortTitle: 'HR',
      ),
      EarableDataChart(
        openEarable: openEarable,
        sensorName: 'PULSOX',
        chartTitle: 'SpO2',
        shortTitle: 'SpO2',
      ),
      EarableDataChart(
        openEarable: openEarable,
        sensorName: 'PPG',
        chartTitle: 'PPG',
        shortTitle: 'PPG',
      ),
    ];
  }

  static List<EarableDataChart> getAvailableDataCharts(
    OpenEarable openEarable,
    bool isV2,
  ) {
    if (isV2) {
      return _getV2DataCharts(openEarable);
    }

    return _getV1DataCharts(openEarable);
  }

  static int getAvailableDataChartsCount(
    OpenEarable openEarable,
    bool isV2,
  ) {
    if (isV2) {
      return 9;
    }

    return 5;
  }
}

class _EarableDataChartState extends State<EarableDataChart> {
  late List<SensorData> _data;
  StreamSubscription? _dataSubscription;
  late int _minX = 0;
  late int _maxX = 0;
  late List<String> colors;
  List<charts.Series<dynamic, num>> seriesList = [];
  List<ChartSeries> webSeriesList = [];
  late double _minY;
  late double _maxY;
  final errorMeasure = {"ACC": 5.0, "GYRO": 10.0, "MAG": 25.0};
  late SimpleKalman kalmanX, kalmanY, kalmanZ;
  final int _numDatapoints = 200;
  final Map<String, String> _units = {
    "ACC": "m/s\u00B2",
    "GYRO": "°/s",
    "MAG": "µT",
    "BARO": "Pa",
    "TEMP": "°C",
    "OPTTEMP": "°C",
    "PPG": "nm",
  };

  void _setupListeners() {
    _dataSubscription?.cancel();
    if (!widget.openEarable.bleManager.connected) {
      return;
    }
    if (widget.sensorName == "BARO") {
      _createSingleDataSubscription("Pressure");
    } else if (widget.sensorName == "TEMP") {
      _createSingleDataSubscription("Temperature");
    } else if (widget.sensorName == "PULSOX") {
      if (widget.chartTitle == "SpO2") {
        _createSingleDataSubscription("SpO2");
      } else {
        _createSingleDataSubscription("HeartRate");
      }
    } else if (widget.sensorName == "OPTTEMP") {
      _createSingleDataSubscription("Temperature");
    } else if (widget.sensorName == "PPG") {
      _dataSubscription?.cancel();
      _dataSubscription = widget.openEarable.sensorManager
          .subscribeToSensorData(1)
          .listen((data) {
        int timestamp = data["timestamp"];
        SensorData sensorData = SensorData(
          name: widget.sensorName,
          timestamp: timestamp,
          values: [
            data[widget.sensorName]["Red"],
            data[widget.sensorName]["InfraRed"],
          ],
          units: data[widget.sensorName]["units"],
        );
        _updateData(sensorData);
      });
    } else if (widget.sensorName == "ACC" ||
        widget.sensorName == "GYRO" ||
        widget.sensorName == "MAG") {
      kalmanX = SimpleKalman(
        errorMeasure: errorMeasure[widget.sensorName]!,
        errorEstimate: errorMeasure[widget.sensorName]!,
        q: 0.9,
      );
      kalmanY = SimpleKalman(
        errorMeasure: errorMeasure[widget.sensorName]!,
        errorEstimate: errorMeasure[widget.sensorName]!,
        q: 0.9,
      );
      kalmanZ = SimpleKalman(
        errorMeasure: errorMeasure[widget.sensorName]!,
        errorEstimate: errorMeasure[widget.sensorName]!,
        q: 0.9,
      );
      _dataSubscription?.cancel();
      _dataSubscription = widget.openEarable.sensorManager
          .subscribeToSensorData(0)
          .listen((data) {
        int timestamp = data["timestamp"];
        SensorData xyzValue = SensorData(
          name: widget.sensorName,
          timestamp: timestamp,
          values: [
            kalmanX.filtered(data[widget.sensorName]["X"]),
            kalmanY.filtered(data[widget.sensorName]["Y"]),
            kalmanZ.filtered(data[widget.sensorName]["Z"]),
          ],
          units: data[widget.sensorName]["units"],
        );

        _updateData(xyzValue);
      });
    }
  }

  void _createSingleDataSubscription(String componentName) {
    _dataSubscription?.cancel();
    _dataSubscription = widget.openEarable.sensorManager
        .subscribeToSensorData(1)
        .listen((data) {
      //units.addAll(data["TEMP"]["units"]);
      int timestamp = data["timestamp"];
      SensorData sensorData = SensorData(
        name: widget.sensorName,
        timestamp: timestamp,
        values: [data[widget.sensorName][componentName]],
        //temperature: data["TEMP"]["Temperature"],
        units: data[widget.sensorName]["units"],
      );
      _updateData(sensorData);
    });
  }

  void _updateData(SensorData value) {
    setState(() {
      _data.add(value);
      _checkLength(_data);
      SensorData? maxXYZValue = maxBy(_data, (SensorData b) => b.getMax());
      SensorData? minXYZValue = minBy(_data, (SensorData b) => b.getMin());

      if (maxXYZValue == null || minXYZValue == null) {
        return;
      }
      double maxY = maxXYZValue.getMax();
      double minY = minXYZValue.getMin();
      double maxAbsValue = max(maxY.abs(), minY.abs());
      bool isIMUChart = widget.sensorName == "ACC" ||
          widget.sensorName == "GYRO" ||
          widget.sensorName == "MAG";

      _maxY = isIMUChart ? maxAbsValue : maxY;
      _minY = isIMUChart ? -maxAbsValue : minY;
      _maxX = value.timestamp;
      _minX = _data[0].timestamp;
    });
  }

  List<String> _getColor(String title) {
    if (title == "Accelerometer") {
      return ['#FF6347', '#3CB371', '#1E90FF'];
    } else if (title == "Gyroscope") {
      return ['#FFD700', '#FF4500', '#D8BFD8'];
    } else if (title == "Magnetometer") {
      return ['#F08080', '#98FB98', '#ADD8E6'];
    } else if (title == "Pressure") {
      return ['#32CD32'];
    } else if (title == "Temperature (Ambient)" ||
        title == "Temperature (Surface)") {
      return ['#FFA07A'];
    } else if (title == "Heart Rate") {
      return ['#FF6347'];
    } else if (title == "SpO2") {
      return ['#ADD8E6'];
    } else if (title == "PPG") {
      return ['#32CD32', '#B22222'];
    }

    // Default return value
    return ['#FFFFFF', '#FFFFFF'];
  }

  @override
  void didUpdateWidget(covariant EarableDataChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.openEarable != widget.openEarable) {
      // TODO: Fix this, both widgets hold the same mutable object, so this comparison is pointless
      _data.clear();
      _setupListeners();
    } else if (_dataSubscription == null) {
      // Workaround for now
      _setupListeners();
    }
  }

  @override
  void initState() {
    super.initState();
    _data = [];
    colors = _getColor(widget.chartTitle);
    if (widget.sensorName == 'TEMP' || widget.sensorName == 'OPTTEMP') {
      _minY = 0;
      _maxY = 30;
    } else if (widget.sensorName == 'BARO') {
      _minY = 0;
      _maxY = 130000;
    } else if (widget.sensorName == "MAG") {
      _minY = -200;
      _maxY = 200;
    } else {
      _minY = -25;
      _maxY = 25;
    }
    if (widget.openEarable.bleManager.connected) {
      _setupListeners();
    }
  }

  @override
  void dispose() {
    super.dispose();
    _dataSubscription?.cancel();
  }

  void _checkLength(data) {
    if (data.length > _numDatapoints) {
      data.removeRange(0, data.length - _numDatapoints);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.openEarable.bleManager.connected) {
      return EarableNotConnectedWarning();
    }
    if (widget.sensorName == 'ACC' ||
        widget.sensorName == 'GYRO' ||
        widget.sensorName == 'MAG') {
      seriesList = [
        charts.Series<SensorData, int>(
          id: 'X${_data.isNotEmpty ? " (${_units[widget.sensorName]})" : ""}',
          colorFn: (_, __) => charts.Color.fromHex(code: colors[0]),
          domainFn: (SensorData data, _) => data.timestamp,
          measureFn: (SensorData data, _) => data.values[0],
          data: _data,
        ),
        charts.Series<SensorData, int>(
          id: 'Y${_data.isNotEmpty ? " (${_units[widget.sensorName]})" : ""}',
          colorFn: (_, __) => charts.Color.fromHex(code: colors[1]),
          domainFn: (SensorData data, _) => data.timestamp,
          measureFn: (SensorData data, _) => data.values[1],
          data: _data,
        ),
        charts.Series<SensorData, int>(
          id: 'Z${_data.isNotEmpty ? " (${_units[widget.sensorName]})" : ""}',
          colorFn: (_, __) => charts.Color.fromHex(code: colors[2]),
          domainFn: (SensorData data, _) => data.timestamp,
          measureFn: (SensorData data, _) => data.values[2],
          data: _data,
        ),
      ];
      webSeriesList = [
        ChartSeries(
          id: 'X${_data.isNotEmpty ? " (${_units[widget.sensorName]})" : ""}',
          label:
              'X${_data.isNotEmpty ? " (${_units[widget.sensorName]})" : ""}',
          getDomainFn: (SensorData data, _) => data.timestamp,
          getMeasureFn: (SensorData data, _) => data.values[0],
          getColorFn: (_, __) => colors[0],
          data: _data,
        ),
        ChartSeries(
          id: 'Y${_data.isNotEmpty ? " (${_units[widget.sensorName]})" : ""}',
          label:
              'Y${_data.isNotEmpty ? " (${_units[widget.sensorName]})" : ""}',
          getDomainFn: (SensorData data, _) => data.timestamp,
          getMeasureFn: (SensorData data, _) => data.values[1],
          getColorFn: (_, __) => colors[1],
          data: _data,
        ),
        ChartSeries(
          id: 'Z${_data.isNotEmpty ? " (${_units[widget.sensorName]})" : ""}',
          label:
              'Z${_data.isNotEmpty ? " (${_units[widget.sensorName]})" : ""}',
          getDomainFn: (SensorData data, _) => data.timestamp,
          getMeasureFn: (SensorData data, _) => data.values[2],
          getColorFn: (_, __) => colors[2],
          data: _data,
        ),
      ];
    } else if (widget.sensorName == "PPG") {
      seriesList = [
        charts.Series<SensorData, int>(
          id: 'Red${_data.isNotEmpty ? " (${_units[widget.sensorName]})" : ""}',
          colorFn: (_, __) => charts.Color.fromHex(code: colors[0]),
          domainFn: (SensorData data, _) => data.timestamp,
          measureFn: (SensorData data, _) => data.values[0],
          data: _data,
        ),
        charts.Series<SensorData, int>(
          id: 'Infrared${_data.isNotEmpty ? " (${_units[widget.sensorName]})" : ""}',
          colorFn: (_, __) => charts.Color.fromHex(code: colors[1]),
          domainFn: (SensorData data, _) => data.timestamp,
          measureFn: (SensorData data, _) => data.values[1],
          data: _data,
        ),
      ];
    } else {
      seriesList = [
        charts.Series<SensorData, int>(
          id: '${widget.chartTitle}${_data.isNotEmpty ? " (${_units[widget.sensorName]})" : ""}',
          colorFn: (_, __) => charts.Color.fromHex(code: colors[0]),
          domainFn: (SensorData data, _) => data.timestamp,
          measureFn: (SensorData data, _) => data.values[0],
          data: _data,
        ),
      ];
      webSeriesList = [
        ChartSeries(
          id: '${widget.chartTitle}${_data.isNotEmpty ? " (${_units[widget.sensorName]})" : ""}',
          label:
              '${widget.chartTitle}${_data.isNotEmpty ? " (${_units[widget.sensorName]})" : ""}',
          getDomainFn: (SensorData data, _) => data.timestamp,
          getMeasureFn: (SensorData data, _) => data.values[0],
          getColorFn: (_, __) => colors[0],
          data: _data,
        ),
      ];
    }

    print("Created series list for ${widget.sensorName}: $webSeriesList");

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            widget.chartTitle,
            style: TextStyle(fontSize: 30),
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: kIsWeb
                ? ChartJsWidget(
                    chartType: 'line',
                    seriesList: webSeriesList,
                    title: widget.sensorName,
                  )
                : charts.LineChart(
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
                      tickProviderSpec: charts.BasicNumericTickProviderSpec(
                        desiredTickCount: 7,
                        zeroBound: false,
                        dataIsInWholeNumbers: false,
                      ),
                      renderSpec: charts.GridlineRendererSpec(
                        labelStyle: charts.TextStyleSpec(
                          fontSize: 14,
                          color: charts
                              .MaterialPalette.white, // Set the color here
                        ),
                      ),
                      viewport: charts.NumericExtents(_minY, _maxY),
                    ),
                    domainAxis: charts.NumericAxisSpec(
                      renderSpec: charts.GridlineRendererSpec(
                        labelStyle: charts.TextStyleSpec(
                          fontSize: 14,
                          color: charts
                              .MaterialPalette.white, // Set the color here
                        ),
                      ),
                      viewport: charts.NumericExtents(_minX, _maxX),
                    ),
                  ),
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

  SensorData({
    required this.name,
    required this.timestamp,
    required this.values,
    required this.units,
  });

  double getMax() {
    return values.reduce(
      (currentMax, element) => element > currentMax ? element : currentMax,
    );
  }

  double getMin() {
    return values.reduce(
      (currentMin, element) => element < currentMin ? element : currentMin,
    );
  }

  @override
  String toString() {
    return "sensor name: $name\ntimestamp: $timestamp\nvalues: ${values.join(", ")}";
  }
}
