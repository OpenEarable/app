import 'dart:collection';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
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
                    checkColor: Colors.white,
                    activeColor: _axisColor(axisName),
                    onChanged: (value) =>
                        _toggleAxis(axisName, value ?? false),
                  ),
                  PlatformText(axisName),
                ],
              );
            }).toList(),
          ),
        Expanded(
          child: LineChart(
            LineChartData(
              lineTouchData: LineTouchData(enabled: true),
              gridData: FlGridData(show: true),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  axisNameWidget: PlatformText(sensor.axisUnits.first),
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 45,
                  ),
                ),
                rightTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: false,
                  ),
                ),
                topTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: false,
                  ),
                ),
                bottomTitles: AxisTitles(
                  axisNameWidget: PlatformText('Time (s)'),
                  axisNameSize: 30,
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 30,
                  ),
                ),
              ),
              borderData: FlBorderData(show: false),
              lineBarsData: enabledAxes.map((axisName) {
                return LineChartBarData(
                  spots: axisData[axisName] ?? [],
                  isCurved: false,
                  barWidth: 2,
                  color: _axisColor(axisName),
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

  Map<String, List<FlSpot>> _buildAxisData(Sensor sensor, Queue<SensorValue> buffer) {
    if (buffer.isEmpty) return { for (var axis in sensor.axisNames) axis: [] };

    final scale = pow(10, -sensor.timestampExponent).toDouble();

    return {
      for (int i = 0; i < sensor.axisCount; i++)
        sensor.axisNames[i]: buffer.map((v) {
          final x = v.timestamp.toDouble() / scale;
          final y = v is SensorDoubleValue
              ? v.values[i]
              : (v as SensorIntValue).values[i].toDouble();
          return FlSpot(x, y);
        }).toList(),
    };
  }

  Color _axisColor(String axisName) {
    final name = axisName.toLowerCase();

    if (name == 'r' || name == 'red') return Colors.red;
    if (name == 'g' || name == 'green') return Colors.green;
    if (name == 'b' || name == 'blue') return Colors.blue;

    // Fallback for unrecognized names (e.g., axis4, temp, etc.)
    final fallbackColors = [
      Colors.teal,
      Colors.amber,
      Colors.indigo,
      Colors.lime,
      Colors.brown,
      Colors.deepOrange,
      Colors.pink,
    ];
    final index = context.read<SensorDataProvider>().sensor.axisNames.indexOf(axisName);
    return fallbackColors[index % fallbackColors.length];
  }
}
