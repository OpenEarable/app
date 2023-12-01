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
  List<XYZValue> accelerometerData = [];
  List<XYZValue> gyroscopeData = [];
  List<XYZValue> magnetometerData = [];
  List<BarometerValue> barometerData = [];

  _SensorDataTabState(this._openEarable);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(vsync: this, length: 5);
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
    if (!_openEarable.bleManager.connected) {
      return _notConnectedWidget();
    } else {
      return _buildSensorDataTabs();
    }
  }

  Widget _notConnectedWidget() {
    return Stack(
      fit: StackFit.expand,
      children: [
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.warning,
                size: 48,
                color: Colors.red,
              ),
              SizedBox(height: 16),
              Center(
                child: Text(
                  "Not connected to\nOpenEarable device",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSensorDataTabs() {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(kToolbarHeight), // Default AppBar height
        child: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white, // Color of the underline indicator
          labelColor: Colors.white, // Color of the active tab label
          unselectedLabelColor: Colors.grey, // Color of the inactive tab labels
          tabs: [
            Tab(text: 'Accel.'),
            Tab(text: 'Gyro.'),
            Tab(text: 'Magnet.'),
            Tab(text: 'Pressure'),
            Tab(text: '3D'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          EarableDataChart(_openEarable, 'Accelerometer Data'),
          EarableDataChart(_openEarable, 'Gyroscope Data'),
          EarableDataChart(_openEarable, 'Magnetometer Data'),
          EarableDataChart(_openEarable, 'Pressure Data'),
          Earable3DModel(_openEarable),
        ],
      ),
    );
  }
}
