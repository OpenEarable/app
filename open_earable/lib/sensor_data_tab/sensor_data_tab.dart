import 'dart:async';

import 'package:flutter/material.dart';
import 'package:open_earable/sensor_data_tab/earable_3d_model.dart';
import 'package:open_earable_flutter/src/open_earable_flutter.dart';
import 'package:open_earable/sensor_data_tab/sensor_chart.dart';

class SensorDataTab extends StatefulWidget {
  final OpenEarable _openEarable;
  SensorDataTab(this._openEarable);
  @override
  _SensorDataTabState createState() => _SensorDataTabState(_openEarable);
}

class _SensorDataTabState extends State<SensorDataTab>
    with SingleTickerProviderStateMixin {
  //late EarableModel _earableModel;
  final OpenEarable _openEarable;
  late TabController _tabController;

  StreamSubscription? _batteryLevelSubscription;
  StreamSubscription? _buttonStateSubscription;
  List<SensorData> accelerometerData = [];
  List<SensorData> gyroscopeData = [];
  List<SensorData> magnetometerData = [];
  List<SensorData> barometerData = [];

  _SensorDataTabState(this._openEarable);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(vsync: this, length: 9);
    if (_openEarable.bleManager.connected) {
      _setupListeners();
    }
  }

  int lastTimestamp = 0;
  _setupListeners() {
    _batteryLevelSubscription =
        _openEarable.sensorManager.getBatteryLevelStream().listen((data) {
      print("Battery level is ${data[0]}");
    });
    _buttonStateSubscription =
        _openEarable.sensorManager.getButtonStateStream().listen((data) {
      print("Button State is ${data[0]}");
    });
  }

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
        preferredSize: Size.fromHeight(kToolbarHeight), // Default AppBar height
        child: TabBar(
          isScrollable: true,
          controller: _tabController,
          indicatorColor: Colors.white, // Color of the underline indicator
          labelColor: Colors.white, // Color of the active tab label
          unselectedLabelColor: Colors.grey, // Color of the inactive tab labels
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
      body: TabBarView(
        controller: _tabController,
        children: [
          EarableDataChart(_openEarable, 'Accelerometer'),
          EarableDataChart(_openEarable, 'Gyroscope'),
          EarableDataChart(_openEarable, 'Magnetometer'),
          EarableDataChart(_openEarable, 'Pressure'),
          EarableDataChart(_openEarable, 'Temperature'),
          EarableDataChart(_openEarable, 'Heart Rate'),
          EarableDataChart(_openEarable, 'SpO2'),
          EarableDataChart(_openEarable, 'PPG'),
          Earable3DModel(_openEarable),
        ],
      ),
    );
  }
}
