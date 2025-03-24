import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart';
import 'package:community_charts_flutter/community_charts_flutter.dart' as charts;

class SensorChart extends StatefulWidget {
  final Sensor sensor;
  final bool allowToggleAxes;
  /// Time window in seconds for which data is displayed
  final int timeWindow;

  const SensorChart({super.key, required this.sensor, this.allowToggleAxes = true, this.timeWindow = 5});

  @override
  State<SensorChart> createState() => _SensorChartState();
}

class _SensorChartState extends State<SensorChart> {
  List<charts.Series<ChartData, int>> _chartData = [];
  final List<ChartData> _dataPoints = [];

  // Track which axes are enabled
  late Map<String, bool> _axisEnabled;

  StreamSubscription<SensorValue>? _sensorStreamSubscription;

  @override
  void initState() {
    super.initState();
    _axisEnabled = {for (var name in widget.sensor.axisNames) name: true};
    _listenToSensorStream();
  }

  @override
  void didUpdateWidget(SensorChart oldWidget) {
    _listenToSensorStream();
    super.didUpdateWidget(oldWidget);
  }

  void _listenToSensorStream() {
    _sensorStreamSubscription = widget.sensor.sensorStream.listen((sensorValue) {
      setState(() {
        // Add new data points
        for (int i = 0; i < widget.sensor.axisCount; i++) {
          if (sensorValue is SensorDoubleValue) {
            _dataPoints.add(ChartData(sensorValue.timestamp, sensorValue.values[i], widget.sensor.axisNames[i]));
          } else if (sensorValue is SensorIntValue) {
            _dataPoints.add(ChartData(sensorValue.timestamp, sensorValue.values[i].toDouble(), widget.sensor.axisNames[i]));
          }
        }

        // Remove data older than 5 seconds
        int cutoffTime = sensorValue.timestamp - (widget.timeWindow * pow(10, -widget.sensor.timestampExponent) as int);
        _dataPoints.removeWhere((data) => data.time < cutoffTime);

        _updateChartData();
      });
    });
  }

  void _updateChartData() {
    // Update chart data based on enabled axes
    _chartData = [
      for (int i = 0; i < widget.sensor.axisCount; i++)
        if (_axisEnabled[widget.sensor.axisNames[i]] ?? false)
          charts.Series<ChartData, int>(
            id: widget.sensor.axisNames[i],
            colorFn: (_, __) => charts.MaterialPalette.blue.makeShades(widget.sensor.axisCount)[i],
            domainFn: (ChartData point, _) => point.time,
            measureFn: (ChartData point, _) => point.value,
            data: _dataPoints.where((point) => point.axisName == widget.sensor.axisNames[i]).toList(),
          ),
    ];
  }

  void _toggleAxis(String axisName, bool value) {
    setState(() {
      _axisEnabled[axisName] = value;
      _updateChartData();
    });
  }

  @override
  Widget build(BuildContext context) {
    // Filter only enabled axes data for scaling
    final filteredPoints = _dataPoints
        .where((point) => _axisEnabled[point.axisName] ?? false)
        .toList();

    final xValues = filteredPoints.map((e) => e.time).toList();
    final yValues = filteredPoints.map((e) => e.value).toList();

    final int? xMin = xValues.isNotEmpty ? xValues.reduce((a, b) => a < b ? a : b) : null;
    final int? xMax = xValues.isNotEmpty ? xValues.reduce((a, b) => a > b ? a : b) : null;

    final double? yMin = yValues.isNotEmpty ? yValues.reduce((a, b) => a < b ? a : b) : null;
    final double? yMax = yValues.isNotEmpty ? yValues.reduce((a, b) => a > b ? a : b) : null;

    return Column(
      children: [
        // Checkbox controls for each axis
        if (widget.allowToggleAxes)
          Wrap(
            spacing: 8.0,
            children: widget.sensor.axisNames.map((axisName) {
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Checkbox(
                    value: _axisEnabled[axisName],
                    onChanged: (value) => _toggleAxis(axisName, value ?? false),
                  ),
                  Text(axisName),
                ],
              );
            }).toList(),
          ),
        // Chart display
        Expanded(
          child: _chartData.isEmpty ?
            Center(
              child: Text('No data available'),
            ) :
            charts.LineChart(
              _chartData,
              animate: false,
              domainAxis: charts.NumericAxisSpec(
                viewport: xMin != null && xMax != null
                    ? charts.NumericExtents(xMin.toDouble(), xMax.toDouble())
                    : null,
                tickProviderSpec: const charts.BasicNumericTickProviderSpec(zeroBound: false, desiredMinTickCount: 3),
              ),
              primaryMeasureAxis: charts.NumericAxisSpec(
                viewport: yMin != null && yMax != null
                    ? charts.NumericExtents(yMin, yMax)
                    : null,
                tickProviderSpec: const charts.BasicNumericTickProviderSpec(zeroBound: false, desiredMinTickCount: 3),
              ),
              behaviors: [
                charts.SeriesLegend(),
                charts.ChartTitle(
                  'Time (${_timestampUnitPrefix(widget.sensor.timestampExponent)}s)',
                  behaviorPosition: charts.BehaviorPosition.bottom
                ),
                charts.ChartTitle(widget.sensor.axisUnits.first, behaviorPosition: charts.BehaviorPosition.start),
              ],
            ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    super.dispose();
    _sensorStreamSubscription?.cancel();
  }
}

String _timestampUnitPrefix(int exponent) {
  switch (exponent) {
    case 0:
      return '';
    case -3:
      return 'm';
    case -6:
      return 'µ';
    case -9:
      return 'n';
    default:
      return '?';
  }
}

class ChartData {
  final int time; // Timestamp in milliseconds
  final double value; // Sensor value
  final String axisName; // Name of the axis

  ChartData(this.time, this.value, this.axisName);
}