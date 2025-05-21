import 'dart:async';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart';

class SensorChart extends StatefulWidget {
  final Sensor sensor;
  final bool allowToggleAxes;
  final int timeWindow; // in seconds

  const SensorChart({
    super.key,
    required this.sensor,
    this.allowToggleAxes = true,
    this.timeWindow = 5,
  });

  @override
  State<SensorChart> createState() => _SensorChartState();
}

class _SensorChartState extends State<SensorChart> {
  late Map<String, bool> _axisEnabled;
  late Map<String, List<FlSpot>> _axisData;
  StreamSubscription<SensorValue>? _sensorStreamSubscription;
  late int _startTime;

  @override
  void initState() {
    super.initState();
    _axisEnabled = {
      for (var name in widget.sensor.axisNames) name: true,
    };
    _axisData = {
      for (var name in widget.sensor.axisNames) name: [],
    };
    _startTime = DateTime.now().millisecondsSinceEpoch;
    _listenToSensorStream();
  }

  void _listenToSensorStream() {
    _sensorStreamSubscription?.cancel();
    _sensorStreamSubscription = widget.sensor.sensorStream.listen((sensorValue) {
      final currentTime = DateTime.now().millisecondsSinceEpoch;
      final elapsedTime = (currentTime - _startTime) / 1000.0; // in seconds

      setState(() {
        for (int i = 0; i < widget.sensor.axisCount; i++) {
          final axisName = widget.sensor.axisNames[i];
          final value = sensorValue is SensorDoubleValue
              ? sensorValue.values[i]
              : (sensorValue as SensorIntValue).values[i].toDouble();

          _axisData[axisName]?.add(FlSpot(elapsedTime, value));

          // Remove data older than timeWindow
          _axisData[axisName] = _axisData[axisName]!
              .where((spot) => elapsedTime - spot.x <= widget.timeWindow)
              .toList();
        }
      });
    });
  }

  void _toggleAxis(String axisName, bool value) {
    setState(() {
      _axisEnabled[axisName] = value;
    });
  }

  @override
  void dispose() {
    _sensorStreamSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final enabledAxes = widget.sensor.axisNames
        .where((axis) => _axisEnabled[axis] ?? false)
        .toList();

    return Column(
      children: [
        if (widget.allowToggleAxes)
          Wrap(
            spacing: 8.0,
            children: widget.sensor.axisNames.map((axisName) {
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Checkbox(
                    value: _axisEnabled[axisName],
                    onChanged: (value) =>
                        _toggleAxis(axisName, value ?? false),
                  ),
                  Text(axisName),
                ],
              );
            }).toList(),
          ),
        Expanded(
          child: LineChart(
            LineChartData(
              lineTouchData: LineTouchData(enabled: false),
              gridData: FlGridData(show: true),
              titlesData: FlTitlesData(show: true),
              borderData: FlBorderData(show: false),
              lineBarsData: enabledAxes.map((axisName) {
                return LineChartBarData(
                  spots: _axisData[axisName] ?? [],
                  isCurved: false,
                  barWidth: 2,
                  isStrokeCapRound: true,
                  dotData: FlDotData(show: false),
                );
              }).toList(),
            ),
            duration: const Duration(microseconds: 0),
          ),
        ),
      ],
    );
  }
}