import 'package:flutter/material.dart';
import 'package:open_earable/ble/ble_controller.dart';
import 'package:open_earable/sensor_data_tab/earable_3d_model.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart';
import 'package:open_earable/sensor_data_tab/sensor_chart.dart';
import 'package:provider/provider.dart';

class SensorDataTab extends StatefulWidget {
  const SensorDataTab({super.key});

  @override
  State<SensorDataTab> createState() => _SensorDataTabState();
}

class _SensorDataTabState extends State<SensorDataTab>
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
        child: Selector<BluetoothController, bool>(
          selector: (context, controller) => controller.isV2,
          builder: (context, isV2, child) {
            return isV2 ? v2TabBar() : v1TabBar();
          },
        ),
      ),
      body: Selector<BluetoothController, bool>(
        selector: (context, controller) => controller.isV2,
        builder: (context, isV2, child) {
          return isV2 ? v2TabBarView() : v1TabBarView();
        },
      ),
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
    return Selector<BluetoothController, OpenEarable>(
      selector: (_, controller) => controller.currentOpenEarable,
      shouldRebuild: (previous, current) => previous != current,
      builder: (_, currentOpenEarable, __) {
        return TabBarView(
          controller: _v1TabController,
          children: [
            EarableDataChart(
              openEarable: currentOpenEarable,
              sensorName: 'ACC',
              chartTitle: 'Accelerometer',
            ),
            EarableDataChart(
              openEarable: currentOpenEarable,
              sensorName: 'GYRO',
              chartTitle: 'Gyroscope',
            ),
            EarableDataChart(
              openEarable: currentOpenEarable,
              sensorName: 'MAG',
              chartTitle: 'Magnetometer',
            ),
            EarableDataChart(
              openEarable: currentOpenEarable,
              sensorName: 'BARO',
              chartTitle: 'Pressure',
            ),
            EarableDataChart(
              openEarable: currentOpenEarable,
              sensorName: 'TEMP',
              chartTitle: 'Temperature (Ambient)',
            ),
            Earable3DModel(currentOpenEarable),
          ],
        );
      },
    );
  }

  Widget v2TabBarView() {
    return Selector<BluetoothController, OpenEarable>(
      selector: (_, controller) => controller.currentOpenEarable,
      shouldRebuild: (previous, current) => previous != current,
      builder: (_, currentOpenEarable, __) {
        return TabBarView(
          controller: _tabController,
          children: [
            EarableDataChart(
              openEarable: currentOpenEarable,
              sensorName: 'ACC',
              chartTitle: 'Accelerometer',
            ),
            EarableDataChart(
              openEarable: currentOpenEarable,
              sensorName: 'GYRO',
              chartTitle: 'Gyroscope',
            ),
            EarableDataChart(
              openEarable: currentOpenEarable,
              sensorName: 'MAG',
              chartTitle: 'Magnetometer',
            ),
            EarableDataChart(
              openEarable: currentOpenEarable,
              sensorName: 'BARO',
              chartTitle: 'Pressure',
            ),
            EarableDataChart(
              openEarable: currentOpenEarable,
              sensorName: 'TEMP',
              chartTitle: 'Temperature (Ambient)',
            ),
            EarableDataChart(
              openEarable: currentOpenEarable,
              sensorName: 'OPTTEMP',
              chartTitle: 'Temperature (Surface)',
            ),
            EarableDataChart(
              openEarable: currentOpenEarable,
              sensorName: 'PULSOX',
              chartTitle: 'Heart Rate',
            ),
            EarableDataChart(
              openEarable: currentOpenEarable,
              sensorName: 'PULSOX',
              chartTitle: 'SpO2',
            ),
            EarableDataChart(
              openEarable: currentOpenEarable,
              sensorName: 'PPG',
              chartTitle: 'PPG',
            ),
            Earable3DModel(currentOpenEarable),
          ],
        );
      },
    );
  }
}
