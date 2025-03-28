import 'dart:async';
import 'package:flutter/material.dart';
import 'package:community_charts_flutter/community_charts_flutter.dart' as charts;
import 'package:logger/logger.dart';

Logger _logger = Logger();

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
  List<charts.Series<_ChartPoint, DateTime>> _seriesList = [];
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
      _logger.d("Received data: $event");
      final (timestamp, value) = event;
      final scaledTimestamp = timestamp ~/ (10 ^ widget.timestampExponent);
      final pointTime = DateTime.fromMillisecondsSinceEpoch(scaledTimestamp);
    
      setState(() {
        _data.add(_ChartPoint(pointTime, value));
    
        // Remove old data outside time window
        final cutoff = pointTime.subtract(Duration(seconds: widget.timeWindow));
        _data.removeWhere((point) => point.time.isBefore(cutoff));
    
        _logger.d("Data points: ${_data.length}");
    
        _updateSeries();
      });
    });
  }

  void _updateSeries() {
    _seriesList = [
        charts.Series<_ChartPoint, DateTime>(
          id: 'Live Data',
          colorFn: (_, __) => charts.MaterialPalette.blue.shadeDefault,
          domainFn: (_ChartPoint point, _) => point.time,
          measureFn: (_ChartPoint point, _) => point.value,
          data: List.of(_data),
      )
    ];

    _logger.d("Series List: ${_seriesList.length}");
  }

  @override
  Widget build(BuildContext context) {
    final filteredPoints = _data;

    final xValues = filteredPoints.map((e) => e.time).toList();
    final yValues = filteredPoints.map((e) => e.value).toList();

    final DateTime? xMin = xValues.isNotEmpty ? xValues.reduce((a, b) => a.isBefore(b) ? a : b) : null;
    final DateTime? xMax = xValues.isNotEmpty ? xValues.reduce((a, b) => a.isAfter(b) ? a : b) : null;

    final double? yMin = yValues.isNotEmpty ? yValues.reduce((a, b) => a < b ? a : b) : null;
    final double? yMax = yValues.isNotEmpty ? yValues.reduce((a, b) => a > b ? a : b) : null;

    return charts.TimeSeriesChart(
      _seriesList,
      animate: false,
      domainAxis: charts.DateTimeAxisSpec(
        viewport: xMin != null && xMax != null
          ? charts.DateTimeExtents(start: xMin, end: xMax)
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
  final DateTime time;
  final double value;

  _ChartPoint(this.time, this.value);
}