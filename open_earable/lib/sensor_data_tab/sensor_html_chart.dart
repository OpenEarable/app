import 'dart:convert';
import 'package:universal_html/html.dart' as html;
import 'package:universal_html/js.dart' as js;
import 'dart:ui_web';
import 'package:flutter/foundation.dart';
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

  const ChartJsWidget({
    super.key,
    required this.chartType,
    required this.seriesList,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) {
      return Center(
        child: Text("Chart.js is only supported on Flutter Web."),
      );
    }

    // Generate a unique chart ID
    final String chartId = 'chart-$title';

    // Register a view for the HTML element (CanvasElement)
    platformViewRegistry.registerViewFactory(
      chartId,
      (int viewId) => html.CanvasElement()..id = chartId,
    );

    // Extract labels and datasets after the widget has been built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final labels = seriesList[0]
          .data
          .map((data) => seriesList[0].getDomainFn(data, null).toString())
          .toList();
      final datasets = seriesList.map((series) {
        return {
          'label': series.label,
          'data': series.data
              .map((data) => series.getMeasureFn(data, null))
              .toList(),
          'borderColor':
              series.getColorFn(series.data[0], null), // Use colorFn for color
          'backgroundColor': series.getColorFn(series.data[0], null) +
              '33', // With transparency
        };
      }).toList();

      // Call the JavaScript function to render the Chart.js chart
      js.context.callMethod('renderChartJS', [
        chartId,
        chartType,
        jsonEncode(labels),
        jsonEncode(datasets),
      ]);
    });

    return HtmlElementView(viewType: chartId);
  }
}
