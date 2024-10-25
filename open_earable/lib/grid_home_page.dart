import 'package:flutter/material.dart';
import 'package:open_earable/ble/ble_controller.dart';
import 'package:open_earable/ble/ble_tab_bar_page.dart';
import 'package:open_earable/controls_tab/models/open_earable_settings_v2.dart';
import 'package:open_earable/controls_tab/views/audio_and_led.dart';
import 'package:open_earable/controls_tab/views/connect_and_configure.dart';
import 'package:open_earable/sensor_data_tab/earable_3d_model.dart';
import 'package:open_earable/shared/square_children_grid.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart';
import 'package:open_earable/sensor_data_tab/sensor_chart.dart';
import 'package:provider/provider.dart';

class GridHomePage extends StatelessWidget {
  final int? precalculatedRows;
  final int? precalculatedColumns;

  const GridHomePage({
    this.precalculatedRows,
    this.precalculatedColumns,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<BluetoothController>(
      builder: (context, bleController, child) {
        return _InternalGridHomePage(
          openEarable: bleController.currentOpenEarable,
          isV2: bleController.isV2,
          precalculatedRows: precalculatedRows,
          precalculatedColumns: precalculatedColumns,
        );
      },
    );
  }
}

class _InternalGridHomePage extends StatelessWidget {
  final OpenEarable openEarable;
  final bool isV2;
  final int? precalculatedRows;
  final int? precalculatedColumns;

  const _InternalGridHomePage({
    required this.openEarable,
    required this.isV2,
    this.precalculatedRows,
    this.precalculatedColumns,
  });

  final double minWidgetHeight = 320;
  final double minWidgetWidth = 370;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(width: 50),
              Image.asset(
                'assets/earable_logo.png',
                width: 24,
                height: 24,
              ),
              SizedBox(width: 8),
              Text('OpenEarable'),
            ],
          ),
        ),
        actions: <Widget>[
          IconButton(
            icon: Icon(
              Icons.bluetooth,
              color: Theme.of(context).colorScheme.secondary,
            ),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => BLETabBarPage(
                    index: OpenEarableSettingsV2().selectedButtonIndex,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: SquareChildrenGrid(
        precalculatedRows: precalculatedRows,
        precalculatedColumns: precalculatedColumns,
        children: [
          Expanded(child: ConnectAndConfigure()),
          Expanded(child: AudioAndLed()),
          ...EarableDataChart.getAvailableDataCharts(
            openEarable,
            isV2,
          ),
          Earable3DModel(openEarable),
        ],
      ),
    );
  }
}
