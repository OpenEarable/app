import 'dart:async';

import 'package:flutter/material.dart';
import 'package:open_earable/ble/ble_controller.dart';
import 'package:open_earable/controls_tab/models/open_earable_settings_v2.dart';
import 'package:open_earable/sensor_data_tab/earable_3d_model.dart';
import 'package:open_earable_flutter/src/open_earable_flutter.dart';
import 'package:open_earable/sensor_data_tab/sensor_chart.dart';
import 'package:provider/provider.dart';

class SensorDataTab extends StatefulWidget {
  @override
  _SensorDataTabState createState() => _SensorDataTabState();
}

class _SensorDataTabState extends State<SensorDataTab>
    with SingleTickerProviderStateMixin {
  //late EarableModel _earableModel;
  late TabController _tabController;

  StreamSubscription? _batteryLevelSubscription;
  StreamSubscription? _buttonStateSubscription;
  List<SensorData> accelerometerData = [];
  List<SensorData> gyroscopeData = [];
  List<SensorData> magnetometerData = [];
  List<SensorData> barometerData = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(vsync: this, length: 9);
  }

  int lastTimestamp = 0;
  /*
  _setupListeners() {
    _buttonStateSubscription =
        _currentOpenEarable.sensorManager.getButtonStateStream().listen((data) {
      print("Button State is ${data[0]}");
    });
  }
  */

  @override
  void dispose() {
    super.dispose();
    _buttonStateSubscription?.cancel();
    _batteryLevelSubscription?.cancel();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: Theme.of(context).colorScheme.background,
        appBar: PreferredSize(
          preferredSize:
              Size.fromHeight(kToolbarHeight), // Default AppBar height
          child: TabBar(
            isScrollable: true,
            controller: _tabController,
            indicatorColor: Colors.white, // Color of the underline indicator
            labelColor: Colors.white, // Color of the active tab label
            unselectedLabelColor:
                Colors.grey, // Color of the inactive tab labels
            tabs: [
              Tab(text: 'Acc.'),
              Tab(text: 'Gyro.'),
              Tab(text: 'Magn.'),
              Tab(text: 'Press.'),
              Tab(text: 'Temp.'),
              Tab(text: 'HR'),
              Tab(text: 'SpO2'),
              Tab(text: 'PPG'),
              Tab(text: '3D'),
            ],
          ),
        ),
        body: Selector<BluetoothController, OpenEarable>(
            selector: (_, controller) => controller.currentOpenEarable,
            shouldRebuild: (previous, current) => previous != current,
            builder: (_, currentOpenEarable, __) {
              return TabBarView(
                controller: _tabController,
                children: [
                  EarableDataChart(currentOpenEarable, 'Accelerometer'),
                  EarableDataChart(currentOpenEarable, 'Gyroscope'),
                  EarableDataChart(currentOpenEarable, 'Magnetometer'),
                  EarableDataChart(currentOpenEarable, 'Pressure'),
                  EarableDataChart(currentOpenEarable, 'Temperature'),
                  EarableDataChart(currentOpenEarable, 'Heart Rate'),
                  EarableDataChart(currentOpenEarable, 'SpO2'),
                  EarableDataChart(currentOpenEarable, 'PPG'),
                  Earable3DModel(currentOpenEarable),
                ],
              );
            }));
  }
}
