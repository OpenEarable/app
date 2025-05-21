import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart';
import 'package:open_wearable/view_models/sensor_data_provider.dart';
import 'package:provider/provider.dart';

class SensorChart extends StatefulWidget {
  final bool allowToggleAxes;

  const SensorChart({
    super.key,
    this.allowToggleAxes = true,
  });

  @override
  State<SensorChart> createState() => _SensorChartState();
}

class _SensorChartState extends State<SensorChart> {
  late Map<String, bool> _axisEnabled;

  @override
  void initState() {
    super.initState();
    final sensor = context.read<SensorDataProvider>().sensor;
    _axisEnabled = { for (var axis in sensor.axisNames) axis: true };
  }

  void _toggleAxis(String axisName, bool value) {
    logger.d('Toggling axis $axisName to $value');
    setState(() {
      _axisEnabled[axisName] = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    Sensor sensor = context.watch<SensorDataProvider>().sensor;
    final enabledAxes = sensor.axisNames
        .where((axis) => _axisEnabled[axis] ?? false)
        .toList();
    final axisData = _buildAxisData(
      sensor,
      context.watch<SensorDataProvider>().sensorValues,
    );
    
    return Column(
      children: [
        if (widget.allowToggleAxes)
          Wrap(
            spacing: 8,
            children: sensor.axisNames.map((axisName) {
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
              lineTouchData: LineTouchData(enabled: true),
              gridData: FlGridData(show: true),
              titlesData: FlTitlesData(show: true),
              borderData: FlBorderData(show: false),
              lineBarsData: enabledAxes.map((axisName) {
                return LineChartBarData(
                  spots: axisData[axisName] ?? [],
                  isCurved: false,
                  barWidth: 2,
                  isStrokeCapRound: true,
                  dotData: FlDotData(show: false),
                );
              }).toList(),
            ),
            duration: const Duration(milliseconds: 0),
          ),
        ),
      ],
    );
  }

  Map<String, List<FlSpot>> _buildAxisData(Sensor sensor, List<SensorValue> buffer) {
    if (buffer.isEmpty) return { for (var axis in sensor.axisNames) axis: [] };

    final t0 = buffer.first.timestamp.toDouble();
    final scale = pow(10, -sensor.timestampExponent).toDouble();

    return {
      for (int i = 0; i < sensor.axisCount; i++)
        sensor.axisNames[i]: buffer.map((v) {
          final x = (v.timestamp - t0) / scale;
          final y = v is SensorDoubleValue
              ? v.values[i]
              : (v as SensorIntValue).values[i].toDouble();
          return FlSpot(x, y);
        }).toList()
    };
  }
}