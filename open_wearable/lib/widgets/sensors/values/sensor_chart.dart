import 'dart:collection';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart' hide logger;
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
  static const List<Color> _fallbackColors = [
    Color(0xFF4A90E2),
    Color(0xFFE76F51),
    Color(0xFF2A9D8F),
    Color(0xFFB565D9),
    Color(0xFFF4A261),
    Color(0xFF3D5A80),
    Color(0xFFD62828),
  ];

  late Map<String, bool> _axisEnabled;
  int? _xOriginTimestamp;
  int? _originSensorHash;

  @override
  void initState() {
    super.initState();
    final sensor = context.read<SensorDataProvider>().sensor;
    _axisEnabled = {for (var axis in sensor.axisNames) axis: true};
  }

  void _toggleAxis(String axisName, bool value) {
    setState(() {
      _axisEnabled[axisName] = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    final dataProvider = context.watch<SensorDataProvider>();
    final sensor = dataProvider.sensor;
    final sensorValues = dataProvider.sensorValues;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final compactMode = !widget.allowToggleAxes;

    final currentSensorHash = identityHashCode(sensor);
    if (_originSensorHash != currentSensorHash) {
      _originSensorHash = currentSensorHash;
      _xOriginTimestamp = null;
    }

    final axisData = _buildAxisData(sensor, sensorValues);
    final enabledSeries = <_AxisSeries>[
      for (int i = 0; i < sensor.axisNames.length; i++)
        if (_axisEnabled[sensor.axisNames[i]] ?? false)
          _AxisSeries(
            spots: axisData[sensor.axisNames[i]] ?? const <FlSpot>[],
            color: _axisColor(
              axisIndex: i,
              axisName: sensor.axisNames[i],
              colorScheme: colorScheme,
            ),
          ),
    ];

    final windowSeconds = dataProvider.timeWindow.toDouble();
    final maxX = _calculateMaxX(sensor, sensorValues, fallback: windowSeconds);
    final minX = max(0.0, maxX - windowSeconds);

    final axisChipTextStyle = theme.textTheme.labelMedium;
    const disabledChipLabelColor = Color(0xFF8A8A8A);
    const disabledChipBackgroundColor = Color(0xFFECECEC);
    const disabledChipBorderColor = Color(0xFFD7D7D7);
    const disabledChipDotColor = Color(0xFFB3B3B3);

    final leftUnit = sensor.axisUnits.isNotEmpty ? sensor.axisUnits.first : '';

    final chartData = LineChartData(
      minX: minX,
      maxX: maxX,
      lineTouchData: LineTouchData(
        enabled: !compactMode,
        handleBuiltInTouches: !compactMode,
      ),
      gridData: FlGridData(
        show: true,
        drawVerticalLine: true,
        getDrawingHorizontalLine: (_) => FlLine(
          color: colorScheme.outline.withValues(alpha: 0.2),
          strokeWidth: 1,
        ),
        getDrawingVerticalLine: (_) => FlLine(
          color: colorScheme.outline.withValues(alpha: 0.2),
          strokeWidth: 1,
        ),
      ),
      titlesData: FlTitlesData(
        leftTitles: AxisTitles(
          axisNameWidget: leftUnit.isEmpty
              ? null
              : PlatformText(
                  leftUnit,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
          axisNameSize: leftUnit.isEmpty ? 0 : (compactMode ? 16 : 22),
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: compactMode ? 34 : 46,
            minIncluded: false,
            maxIncluded: false,
            getTitlesWidget: (value, meta) => SideTitleWidget(
              meta: meta,
              space: 6,
              child: SizedBox(
                width: compactMode ? 30 : 40,
                child: Text(
                  _formatYAxisTick(value),
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.fade,
                  textAlign: TextAlign.right,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ),
        ),
        rightTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
        topTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
        bottomTitles: AxisTitles(
          axisNameSize: 0,
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: compactMode ? 20 : 24,
            interval: compactMode ? 2 : 1,
            minIncluded: false,
            maxIncluded: false,
            getTitlesWidget: (value, meta) => SideTitleWidget(
              meta: meta,
              child: Text(
                _formatXAxisTick(value),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ),
      ),
      borderData: FlBorderData(
        show: true,
        border: Border(
          left: BorderSide(
            color: colorScheme.outline.withValues(alpha: 0.28),
          ),
          bottom: BorderSide(
            color: colorScheme.outline.withValues(alpha: 0.28),
          ),
        ),
      ),
      lineBarsData: enabledSeries
          .map(
            (series) => LineChartBarData(
              spots: series.spots,
              isCurved: false,
              barWidth: 2.2,
              color: series.color,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(show: false),
            ),
          )
          .toList(growable: false),
    );

    final enabledAxes =
        sensor.axisNames.where((axis) => _axisEnabled[axis] ?? false).toList();

    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              compactMode ? 2 : 6,
              compactMode ? 2 : 4,
              2,
              0,
            ),
            child: LineChart(
              chartData,
              duration: const Duration(milliseconds: 0),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: LayoutBuilder(
            builder: (context, constraints) => Row(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minWidth: max(0.0, constraints.maxWidth - 70),
                      ),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children:
                              sensor.axisNames.asMap().entries.map((entry) {
                            final axisIndex = entry.key;
                            final axisName = entry.value;
                            final axisColor = _axisColor(
                              axisIndex: axisIndex,
                              axisName: axisName,
                              colorScheme: colorScheme,
                            );
                            final selected = _axisEnabled[axisName] ?? false;
                            final chipLabelColor = selected
                                ? axisColor.withValues(alpha: 0.95)
                                : disabledChipLabelColor;
                            final chipBackgroundColor = selected
                                ? axisColor.withValues(alpha: 0.18)
                                : disabledChipBackgroundColor;
                            final chipBorderColor = selected
                                ? axisColor.withValues(alpha: 0.28)
                                : disabledChipBorderColor;
                            final chipDotColor = axisColor;
                            final disabledDotColor = disabledChipDotColor;

                            return Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: FilterChip(
                                label: Text(
                                  axisName,
                                  style: axisChipTextStyle?.copyWith(
                                    color: chipLabelColor,
                                    fontWeight: FontWeight.w700,
                                    fontSize: compactMode ? 10.5 : 11.5,
                                  ),
                                ),
                                avatar: Container(
                                  width: 7,
                                  height: 7,
                                  decoration: BoxDecoration(
                                    color: selected
                                        ? chipDotColor
                                        : disabledDotColor,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                selected: selected,
                                onSelected: (value) =>
                                    _toggleAxis(axisName, value),
                                showCheckmark: false,
                                visualDensity: compactMode
                                    ? const VisualDensity(
                                        horizontal: -3,
                                        vertical: -3,
                                      )
                                    : const VisualDensity(
                                        horizontal: -2,
                                        vertical: -2,
                                      ),
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                                labelPadding:
                                    const EdgeInsets.symmetric(horizontal: 4),
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 4),
                                selectedColor: chipBackgroundColor,
                                backgroundColor: chipBackgroundColor,
                                side: BorderSide(
                                  color: chipBorderColor,
                                ),
                              ),
                            );
                          }).toList(growable: false),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Time (s)',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (enabledAxes.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Enable at least one axis to display data.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
      ],
    );
  }

  double _calculateMaxX(
    Sensor sensor,
    Queue<SensorValue> buffer, {
    required double fallback,
  }) {
    if (buffer.isEmpty) return fallback;
    return _toElapsedSeconds(sensor, buffer.last.timestamp);
  }

  double _toElapsedSeconds(Sensor sensor, int timestamp) {
    final scale = pow(10, -sensor.timestampExponent).toDouble();
    _xOriginTimestamp ??= timestamp;

    if (timestamp < _xOriginTimestamp!) {
      _xOriginTimestamp = timestamp;
    }

    return (timestamp - _xOriginTimestamp!).toDouble() / scale;
  }

  Map<String, List<FlSpot>> _buildAxisData(
    Sensor sensor,
    Queue<SensorValue> buffer,
  ) {
    final data = <String, List<FlSpot>>{
      for (var axis in sensor.axisNames) axis: <FlSpot>[],
    };
    if (buffer.isEmpty) return data;

    for (final sensorValue in buffer) {
      final x = _toElapsedSeconds(sensor, sensorValue.timestamp);
      if (sensorValue is SensorDoubleValue) {
        for (int i = 0; i < sensor.axisCount; i++) {
          data[sensor.axisNames[i]]!.add(FlSpot(x, sensorValue.values[i]));
        }
      } else {
        final values = (sensorValue as SensorIntValue).values;
        for (int i = 0; i < sensor.axisCount; i++) {
          data[sensor.axisNames[i]]!.add(FlSpot(x, values[i].toDouble()));
        }
      }
    }

    return data;
  }

  String _formatXAxisTick(double value) {
    final rounded = value.roundToDouble();
    if ((value - rounded).abs() < 0.05) {
      return rounded.toInt().toString();
    }
    return value.toStringAsFixed(1);
  }

  String _formatYAxisTick(double value) {
    final abs = value.abs();
    String output;

    if (abs >= 100000 || (abs > 0 && abs < 0.001)) {
      output = value.toStringAsExponential(1);
    } else if (abs >= 1000) {
      output = value.toStringAsFixed(0);
    } else if (abs >= 100) {
      output = value.toStringAsFixed(1);
    } else if (abs >= 1) {
      output = value.toStringAsFixed(2);
    } else {
      output = value.toStringAsFixed(3);
    }

    return _trimTrailingZeros(output);
  }

  String _trimTrailingZeros(String value) {
    if (value.contains('e') || value.contains('E')) return value;
    var result = value;
    if (result.contains('.')) {
      result = result.replaceFirst(RegExp(r'0+$'), '');
      result = result.replaceFirst(RegExp(r'\.$'), '');
    }
    return result;
  }

  Color _axisColor({
    required int axisIndex,
    required String axisName,
    required ColorScheme colorScheme,
  }) {
    final name = axisName.toLowerCase();

    if (name == 'x') return const Color(0xFF4A90E2);
    if (name == 'y') return const Color(0xFFE76F51);
    if (name == 'z') return const Color(0xFF2A9D8F);
    if (name == 'r' || name == 'red') return Colors.red;
    if (name == 'g' || name == 'green') return Colors.green;
    if (name == 'b' || name == 'blue') return Colors.blue;
    if (name.contains('temp')) return const Color(0xFFFB8500);
    if (name.contains('pressure')) return const Color(0xFF6C63FF);

    if (axisIndex == 0) return colorScheme.primary;
    return _fallbackColors[axisIndex % _fallbackColors.length];
  }
}

class _AxisSeries {
  final List<FlSpot> spots;
  final Color color;

  const _AxisSeries({
    required this.spots,
    required this.color,
  });
}
