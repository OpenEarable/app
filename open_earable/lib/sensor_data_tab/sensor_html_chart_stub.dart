import 'package:flutter/material.dart';
import 'package:open_earable/sensor_data_tab/sensor_chart.dart';

class ChartSeries {
  final String id;
  final String label;
  final Function(SensorData, int?) getDomainFn;
  final Function(SensorData, int?) getMeasureFn;
  final Function(SensorData, String?) getColorFn;

  final List<SensorData> data;

  ChartSeries({
    required this.id,
    required this.label,
    required this.getDomainFn,
    required this.getMeasureFn,
    required this.getColorFn,
    required this.data,
  });
}


class ChartJsWidget extends StatelessWidget {
  final String chartType;
  final List<ChartSeries> seriesList;

  final String title;

  const ChartJsWidget({super.key, 
    required this.chartType,
    required this.seriesList,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text("Chart.js is not supported on this platform."),
    );
  }
}
