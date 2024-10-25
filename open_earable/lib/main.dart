import 'package:flutter/material.dart';
import 'package:open_earable/grid_home_page.dart';
import 'package:open_earable/sensor_data_tab/sensor_chart.dart';
import 'package:open_earable/shared/square_children_grid.dart';
import 'package:open_earable/tabbed_home_page.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart';
import 'package:provider/provider.dart';
import 'package:open_earable/ble/ble_controller.dart';
import 'shared/global_theme.dart';

void main() => runApp(
      ChangeNotifierProvider(
        create: (context) => BluetoothController(),
        child: MyApp(),
      ),
    );

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '🦻 OpenEarable',
      theme: materialTheme,
      home: MyHomePage(),
    );
  }
}

class MyHomePage extends StatelessWidget {
  final double minWidgetWidth = 380;
  final double minWidgetHeight = 410;

  const MyHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Selector<BluetoothController, bool>(
      selector: (context, controller) => controller.isV2,
      builder: (context, isV2, child) {
        return Selector<BluetoothController, OpenEarable>(
          selector: (_, controller) => controller.currentOpenEarable,
          shouldRebuild: (previous, current) => previous != current,
          builder: (_, currentOpenEarable, __) {
            int dataChartCount = EarableDataChart.getAvailableDataChartsCount(
              currentOpenEarable,
              isV2,
            );
            int threeDWidgetCount = 1;
            int configurationWidgetCount = 1;

            int widgetCount =
                dataChartCount + threeDWidgetCount + configurationWidgetCount;

            return LayoutBuilder(
              builder: (context, constraints) {
                double width = constraints.maxWidth;
                double height = constraints.maxHeight;
                (int, int) rowColumnDimension =
                    SquareChildrenGrid.calculateColumnsAndRows(
                  width,
                  height,
                  widgetCount,
                );
                int cols = rowColumnDimension.$1;
                int rows = rowColumnDimension.$2;

                double chartWidth = width / cols;
                double chartHeight = height / rows;

                if (chartHeight >= minWidgetHeight &&
                    chartWidth >= minWidgetWidth) {
                  return GridHomePage(
                    precalculatedColumns: cols,
                    precalculatedRows: rows,
                  );
                }

                return TabbedHomePage();
              },
            );
          },
        );
      },
    );
  }
}
