import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:community_charts_flutter/community_charts_flutter.dart' as charts;

class RollingChart extends StatefulWidget {
  final Stream<(int, double)> dataSteam;
  final int timestampExponent; // e.g., 6 for microseconds to milliseconds
  final int timeWindow; // in milliseconds

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
  List<charts.Series<_ChartPoint, int>> _seriesList = [];
  final List<_ChartPoint> _data = [];
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
        _data.add(_ChartPoint(timestamp, value));
    
        // Remove old data outside time window
        int cutoffTime = timestamp - (widget.timeWindow * pow(10, -widget.timestampExponent) as int);
        _data.removeWhere((data) => data.time < cutoffTime);
    
        _updateSeries();
      });
    });
  }

  void _updateSeries() {
    _seriesList = [
        charts.Series<_ChartPoint, int>(
          id: 'Live Data',
          colorFn: (_, __) => charts.MaterialPalette.red.shadeDefault,
          domainFn: (_ChartPoint point, _) => point.time,
          measureFn: (_ChartPoint point, _) => point.value,
          data: List.of(_data),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final filteredPoints = _data;

    final xValues = filteredPoints.map((e) => e.time).toList();
    final yValues = filteredPoints.map((e) => e.value).toList();

    final int? xMin = xValues.isNotEmpty ? xValues.reduce((a, b) => a < b ? a : b) : null;
    final int? xMax = xValues.isNotEmpty ? xValues.reduce((a, b) => a > b ? a : b) : null;

    final double? yMin = yValues.isNotEmpty ? yValues.reduce((a, b) => a < b ? a : b) : null;
    final double? yMax = yValues.isNotEmpty ? yValues.reduce((a, b) => a > b ? a : b) : null;

    return charts.LineChart(
      _seriesList,
      animate: false,
      domainAxis: charts.NumericAxisSpec(
        viewport: xMin != null && xMax != null
          ? charts.NumericExtents(xMin, xMax)
          : null,
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

class _ChartPoint {
  final int time;
  final double value;

  _ChartPoint(this.time, this.value);
}
