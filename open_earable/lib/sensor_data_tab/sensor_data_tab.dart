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
  late TabController _v1TabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(vsync: this, length: 10);
    _v1TabController = TabController(vsync: this, length: 6);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(kToolbarHeight), // Default AppBar height
        child: widget.isV2 ? v2TabBar() : v1TabBar(),
      ),
      body: widget.isV2 ? v2TabBarView() : v1TabBarView(),
    );
  }

  Widget v1TabBar() {
    return TabBar(
      isScrollable: true,
      controller: _v1TabController,
      // Color of the underline indicator
      indicatorColor: Colors.white,
      // Color of the active tab label
      labelColor: Colors.white,
      // Color of the inactive tab labels
      unselectedLabelColor: Colors.grey,
      tabs: [
        Tab(text: 'Acc.'),
        Tab(text: 'Gyro.'),
        Tab(text: 'Magn.'),
        Tab(text: 'Press.'),
        Tab(text: 'Temp. (A.)'),
        Tab(text: '3D'),
      ],
    );
  }

  Widget v2TabBar() {
    return TabBar(
      isScrollable: true,
      controller: _tabController,
      indicatorColor: Colors.white,
      // Color of the underline indicator
      labelColor: Colors.white,
      // Color of the active tab label
      unselectedLabelColor: Colors.grey,
      // Color of the inactive tab labels
      tabs: [
        Tab(text: 'Acc.'),
        Tab(text: 'Gyro.'),
        Tab(text: 'Magn.'),
        Tab(text: 'Press.'),
        Tab(text: 'Temp. (A.)'),
        Tab(text: 'Temp. (S.)'),
        Tab(text: 'HR'),
        Tab(text: 'SpO2'),
        Tab(text: 'PPG'),
        Tab(text: '3D'),
      ],
    );
  }

  Widget v1TabBarView() {
    return TabBarView(
      controller: _v1TabController,
      children: [
        EarableDataChart(
          openEarable: widget.openEarable,
          sensorName: 'ACC',
          chartTitle: 'Accelerometer',
          shortTitle: 'Acc.',
        ),
        EarableDataChart(
          openEarable: widget.openEarable,
          sensorName: 'GYRO',
          chartTitle: 'Gyroscope',
          shortTitle: 'Gyro.',
        ),
        EarableDataChart(
          openEarable: widget.openEarable,
          sensorName: 'MAG',
          chartTitle: 'Magnetometer',
          shortTitle: 'Magn.',
        ),
        EarableDataChart(
          openEarable: widget.openEarable,
          sensorName: 'BARO',
          chartTitle: 'Pressure',
          shortTitle: 'Press.',
        ),
        EarableDataChart(
          openEarable: widget.openEarable,
          sensorName: 'TEMP',
          chartTitle: 'Temperature (Ambient)',
          shortTitle: 'Temp. (A.)',
        ),
        Earable3DModel(widget.openEarable),
      ],
    );
  }

  Widget v2TabBarView() {
    return TabBarView(
      controller: _tabController,
      children: [
        EarableDataChart(
          openEarable: widget.openEarable,
          sensorName: 'ACC',
          chartTitle: 'Accelerometer',
          shortTitle: 'Acc.',
        ),
        EarableDataChart(
          openEarable: widget.openEarable,
          sensorName: 'GYRO',
          chartTitle: 'Gyroscope',
          shortTitle: 'Gyro.',
        ),
        EarableDataChart(
          openEarable: widget.openEarable,
          sensorName: 'MAG',
          chartTitle: 'Magnetometer',
          shortTitle: 'Magn.',
        ),
        EarableDataChart(
          openEarable: widget.openEarable,
          sensorName: 'BARO',
          chartTitle: 'Pressure',
          shortTitle: 'Press.',
        ),
        EarableDataChart(
          openEarable: widget.openEarable,
          sensorName: 'TEMP',
          chartTitle: 'Temperature (Ambient)',
          shortTitle: 'Temp. (A.)',
        ),
        EarableDataChart(
          openEarable: widget.openEarable,
          sensorName: 'OPTTEMP',
          chartTitle: 'Temperature (Surface)',
          shortTitle: 'Temp. (S.)',
        ),
        EarableDataChart(
          openEarable: widget.openEarable,
          sensorName: 'PULSOX',
          chartTitle: 'Heart Rate',
          shortTitle: 'HR',
        ),
        EarableDataChart(
          openEarable: widget.openEarable,
          sensorName: 'PULSOX',
          chartTitle: 'SpO2',
          shortTitle: 'SpO2',
        ),
        EarableDataChart(
          openEarable: widget.openEarable,
          sensorName: 'PPG',
          chartTitle: 'PPG',
          shortTitle: 'PPG',
        ),
        Earable3DModel(widget.openEarable),
      ],
    );
  }
}
