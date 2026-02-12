import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:community_charts_flutter/community_charts_flutter.dart'
    as charts;

class RollingChart extends StatefulWidget {
  final Stream<(int, double)> dataSteam;
  final int timestampExponent; // e.g., 6 for microseconds to milliseconds
  final int timeWindow; // in seconds

  const RollingChart({
    super.key,
    required this.dataSteam,
    required this.timestampExponent,
    required this.timeWindow,
  });

  @override
  State<RollingChart> createState() => _RollingChartState();
}

class _RollingChartState extends State<RollingChart> {
  List<charts.Series<_ChartPoint, num>> _seriesList = [];
  final List<_RawChartPoint> _rawData = [];
  List<_ChartPoint> _normalizedData = [];
  StreamSubscription? _subscription;

  @override
  void initState() {
    super.initState();
    _listenToStream();
  }

  @override
  void didUpdateWidget(RollingChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.dataSteam != widget.dataSteam) {
      _subscription?.cancel();
      _listenToStream();
    }
  }

  void _listenToStream() {
    _subscription = widget.dataSteam.listen((event) {
      final (timestamp, value) = event;

      setState(() {
        _rawData.add(_RawChartPoint(timestamp, value));

        // Remove old data outside time window
        final ticksPerSecond = pow(10, -widget.timestampExponent).toDouble();
        final cutoffTime =
            timestamp - (widget.timeWindow * ticksPerSecond).round();
        _rawData.removeWhere((data) => data.timestamp < cutoffTime);

        _updateSeries();
      });
    });
  }

  void _updateSeries() {
    if (_rawData.isEmpty) {
      _normalizedData = [];
      _seriesList = [];
      return;
    }

    final firstTimestamp = _rawData.first.timestamp;
    final secondsPerTick = pow(10, widget.timestampExponent).toDouble();

    _normalizedData = _rawData
        .map(
          (point) => _ChartPoint(
            (point.timestamp - firstTimestamp) * secondsPerTick,
            point.value,
          ),
        )
        .toList(growable: false);

    _seriesList = [
      charts.Series<_ChartPoint, num>(
        id: 'Live Data',
        colorFn: (_, __) => charts.MaterialPalette.red.shadeDefault,
        domainFn: (_ChartPoint point, _) => point.timeSeconds,
        measureFn: (_ChartPoint point, _) => point.value,
        data: _normalizedData,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final filteredPoints = _normalizedData;

    final xValues = filteredPoints.map((e) => e.timeSeconds).toList();
    final yValues = filteredPoints.map((e) => e.value).toList();

    final double xMin = 0;
    final double xMax = max(
      widget.timeWindow.toDouble(),
      xValues.isNotEmpty ? xValues.reduce((a, b) => a > b ? a : b) : 0,
    );

    final double? yMin =
        yValues.isNotEmpty ? yValues.reduce((a, b) => a < b ? a : b) : null;
    final double? yMax =
        yValues.isNotEmpty ? yValues.reduce((a, b) => a > b ? a : b) : null;

    return charts.LineChart(
      _seriesList,
      animate: false,
      domainAxis: charts.NumericAxisSpec(
        viewport: charts.NumericExtents(xMin, xMax),
        tickFormatterSpec: charts.BasicNumericTickFormatterSpec((num? value) {
          if (value == null) return '';
          final rounded = value.roundToDouble();
          if ((value - rounded).abs() < 0.05) {
            return '${rounded.toInt()}s';
          }
          return '${value.toStringAsFixed(1)}s';
        }),
      ),
      primaryMeasureAxis: charts.NumericAxisSpec(
        viewport: yMin != null && yMax != null
            ? charts.NumericExtents(yMin, yMax)
            : null,
      ),
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

class _RawChartPoint {
  final int timestamp;
  final double value;

  _RawChartPoint(this.timestamp, this.value);
}

class _ChartPoint {
  final double timeSeconds;
  final double value;

  _ChartPoint(this.timeSeconds, this.value);
}
