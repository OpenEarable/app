import 'package:flutter/material.dart';
import 'package:open_earable/ble/ble_controller.dart';
import 'package:open_earable/sensor_data_tab/earable_3d_model.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart';
import 'package:open_earable/sensor_data_tab/sensor_chart.dart';
import 'package:provider/provider.dart';

class SensorDataTab extends StatelessWidget {
  const SensorDataTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Selector<BluetoothController, bool>(
      selector: (context, controller) => controller.isV2,
      builder: (context, isV2, child) {
        return Selector<BluetoothController, OpenEarable>(
          selector: (_, controller) => controller.currentOpenEarable,
          shouldRebuild: (previous, current) => previous != current,
          builder: (_, currentOpenEarable, __) {
            return _InternalSensorDataTab(
              openEarable: currentOpenEarable,
              isV2: isV2,
            );
          },
        );
      },
    );
  }
}

class _InternalSensorDataTab extends StatefulWidget {
  final OpenEarable openEarable;
  final bool isV2;

  const _InternalSensorDataTab({
    required this.openEarable,
    required this.isV2,
  });

  @override
  State<_InternalSensorDataTab> createState() => _InternalSensorDataTabState();
}

class _InternalSensorDataTabState extends State<_InternalSensorDataTab>
    with TickerProviderStateMixin {
  late TabController _tabController;

  late List<EarableDataChart> dataCharts;

  @override
  void initState() {
    super.initState();

    dataCharts = EarableDataChart.getAvailableDataCharts(
      widget.openEarable,
      widget.isV2,
    );
    _tabController = TabController(
      vsync: this,
      length: dataCharts.length + 1,
    );
  }

  @override
  void didUpdateWidget(covariant _InternalSensorDataTab oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.openEarable == widget.openEarable &&
        oldWidget.isV2 == widget.isV2) {
      return;
    }

    dataCharts = EarableDataChart.getAvailableDataCharts(
      widget.openEarable,
      widget.isV2,
    );
    _tabController = TabController(
      vsync: this,
      length: dataCharts.length + 1,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(kToolbarHeight), // Default AppBar height
        child: TabBar(
          isScrollable: true,
          controller: _tabController,
          // Color of the underline indicator
          indicatorColor: Colors.white,
          // Color of the active tab label
          labelColor: Colors.white,
          // Color of the inactive tab labels
          unselectedLabelColor: Colors.grey,
          tabs: [
            ...dataCharts.map((e) => Tab(text: e.shortTitle)),
            Tab(text: '3D'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          ...dataCharts,
          Earable3DModel(widget.openEarable),
        ],
      ),
    );
  }
}
