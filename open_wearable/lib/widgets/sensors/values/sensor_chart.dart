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
  final bool liveUpdatesEnabled;
  final VoidCallback? onDisabledTap;

  const SensorChart({
    super.key,
    this.allowToggleAxes = true,
    this.liveUpdatesEnabled = true,
    this.onDisabledTap,
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
    final dataProvider = widget.liveUpdatesEnabled
        ? context.watch<SensorDataProvider>()
        : context.read<SensorDataProvider>();
    final sensor = dataProvider.sensor;
    final sensorValues = widget.liveUpdatesEnabled
        ? dataProvider.sensorValues
        : Queue<SensorValue>();
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final compactMode = !widget.allowToggleAxes;
    final referenceTimestamp = dataProvider.displayTimestamp;

    final axisData = _buildAxisData(
      sensor,
      sensorValues,
      windowSeconds: dataProvider.timeWindow.toDouble(),
      referenceTimestamp: referenceTimestamp,
    );
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
    const maxX = 0.0;
    final minX = -windowSeconds;
    final yAxisBounds = _computeYAxisBounds(enabledSeries);

    final axisChipTextStyle = theme.textTheme.labelMedium;
    const disabledChipLabelColor = Color(0xFF8A8A8A);
    const disabledChipBackgroundColor = Color(0xFFECECEC);
    const disabledChipBorderColor = Color(0xFFD7D7D7);
    const disabledChipDotColor = Color(0xFFB3B3B3);

    final leftUnit = sensor.axisUnits.isNotEmpty ? sensor.axisUnits.first : '';

    final chartData = LineChartData(
      minX: minX,
      maxX: maxX,
      minY: yAxisBounds.min,
      maxY: yAxisBounds.max,
      lineTouchData: LineTouchData(
        enabled: widget.liveUpdatesEnabled && !compactMode,
        handleBuiltInTouches: widget.liveUpdatesEnabled && !compactMode,
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
            getTitlesWidget: (value, meta) {
              final isBoundaryTick = (value - yAxisBounds.min).abs() < 1e-6 ||
                  (value - yAxisBounds.max).abs() < 1e-6;
              if (isBoundaryTick) {
                return const SizedBox.shrink();
              }
              return SideTitleWidget(
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
              );
            },
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
            interval: 1,
            minIncluded: true,
            maxIncluded: true,
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
            child: Stack(
              alignment: Alignment.center,
              children: [
                Opacity(
                  opacity: widget.liveUpdatesEnabled ? 1 : 0.5,
                  child: LineChart(
                    chartData,
                    duration: const Duration(milliseconds: 0),
                  ),
                ),
                if (!widget.liveUpdatesEnabled)
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: widget.onDisabledTap,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: colorScheme.surface.withValues(alpha: 0.82),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: colorScheme.outline.withValues(alpha: 0.35),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          child: Text(
                            widget.onDisabledTap == null
                                ? 'Live graphs disabled'
                                : 'Live graphs disabled. Tap to open settings.',
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
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
                                onSelected: widget.liveUpdatesEnabled
                                    ? (value) => _toggleAxis(axisName, value)
                                    : null,
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

  double _toRelativeSeconds(
    Sensor sensor,
    int timestamp, {
    required int referenceTimestamp,
  }) {
    final scale = pow(10, -sensor.timestampExponent).toDouble();
    return (timestamp - referenceTimestamp).toDouble() / scale;
  }

  Map<String, List<FlSpot>> _buildAxisData(
    Sensor sensor,
    Queue<SensorValue> buffer, {
    required double windowSeconds,
    required int referenceTimestamp,
  }) {
    final data = <String, List<FlSpot>>{
      for (var axis in sensor.axisNames) axis: <FlSpot>[],
    };
    if (buffer.isEmpty) return data;

    for (final sensorValue in buffer) {
      final x = _toRelativeSeconds(
        sensor,
        sensorValue.timestamp,
        referenceTimestamp: referenceTimestamp,
      ).clamp(-windowSeconds, 0.0);
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

  _YAxisBounds _computeYAxisBounds(List<_AxisSeries> seriesList) {
    var minY = double.infinity;
    var maxY = double.negativeInfinity;

    for (final series in seriesList) {
      for (final spot in series.spots) {
        minY = min(minY, spot.y);
        maxY = max(maxY, spot.y);
      }
    }

    if (!minY.isFinite || !maxY.isFinite) {
      return const _YAxisBounds(min: -1, max: 1);
    }

    final range = maxY - minY;
    if (range.abs() < 1e-9) {
      final pad = max(minY.abs() * 0.05, 1e-3);
      return _YAxisBounds(
        min: minY - pad,
        max: maxY + pad,
      );
    }

    final pad = max(range * 0.1, 1e-6);
    return _YAxisBounds(
      min: minY - pad,
      max: maxY + pad,
    );
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

class _YAxisBounds {
  final double min;
  final double max;

  const _YAxisBounds({
    required this.min,
    required this.max,
  });
}
