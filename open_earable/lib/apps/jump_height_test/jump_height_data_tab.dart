import 'dart:async';

import 'package:flutter/material.dart';
import 'package:open_earable/sensor_data_tab/earable_3d_model.dart';
import 'package:open_earable_flutter/src/open_earable_flutter.dart';
import 'package:open_earable/sensor_data_tab/sensor_chart.dart';

class JumpHeightDataTab extends StatefulWidget {
  final OpenEarable _openEarable;
  JumpHeightDataTab(this._openEarable);
  @override
  _SensorDataTabState createState() => _SensorDataTabState(_openEarable);
}

class _SensorDataTabState extends State<JumpHeightDataTab>
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


}
