import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:open_earable_flutter/src/open_earable_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BluetoothController extends ChangeNotifier {
  late SharedPreferences prefs;

  BluetoothController() {
    _initializeSharedPreferences();
  }

  String _openEarableName = "OpenEarable";
  OpenEarable get openEarableLeft => _openEarableLeft;
  OpenEarable get openEarableRight => _openEarableRight;
  OpenEarable _openEarableLeft = OpenEarable();
  OpenEarable _openEarableRight = OpenEarable();
  StreamSubscription? _scanSubscription;
  StreamSubscription? _connectionStateSubscriptionLeft;
  StreamSubscription? _connectionStateSubscriptionRight;

  StreamSubscription? _batteryLevelSubscriptionLeft;
  StreamSubscription? _batteryLevelSubscriptionRight;

  List<DiscoveredDevice> _discoveredDevices = [];
  List<DiscoveredDevice> get discoveredDevices => _discoveredDevices;

  //bool _scanning = false;

  bool get connected => _connectedLeft || _connectedRight;

  bool _connectedLeft = false;
  bool get connectedLeft => _connectedLeft;

  bool _connectedRight = false;
  bool get connectedRight => _connectedRight;

  int? _earableSOCLeft = null;
  int? get earableSOCLeft => _earableSOCLeft;

  int? _earableSOCRight = null;
  int? get earableSOCRight => _earableSOCRight;

  Future<void> _initializeSharedPreferences() async {
    prefs = await SharedPreferences.getInstance();
  }

  void setupListeners() {
    _connectionStateSubscriptionLeft?.cancel();
    _connectionStateSubscriptionRight?.cancel();

    _connectionStateSubscriptionLeft =
        _openEarableLeft.bleManager.connectionStateStream.listen((connected) {
      _connectedLeft = connected;
      if (connected) {
        _getSOCLeft();
      } else {
        //startScanning(_openEarableLeft);
      }
      notifyListeners();
    });

    _connectionStateSubscriptionRight =
        _openEarableRight.bleManager.connectionStateStream.listen((connected) {
      _connectedRight = connected;
      if (connected) {
        _getSOCRight();
      } else {
        //startScanning(_openEarableRight);
      }
      notifyListeners();
    });
  }

  @override
  void dispose() {
    super.dispose();
    _scanSubscription?.cancel();
    //_scanning = false;
    _connectionStateSubscriptionLeft?.cancel();
    _connectionStateSubscriptionRight?.cancel();
    _batteryLevelSubscriptionLeft?.cancel();
    _batteryLevelSubscriptionRight?.cancel();
  }

  void _getSOCLeft() {
    _batteryLevelSubscriptionLeft = _openEarableLeft.sensorManager
        .getBatteryLevelStream()
        .listen((batteryLevel) {
      _earableSOCLeft = batteryLevel[0].toInt();
      notifyListeners();
    });
  }

  void _getSOCRight() {
    _batteryLevelSubscriptionRight = _openEarableRight.sensorManager
        .getBatteryLevelStream()
        .listen((batteryLevel) {
      _earableSOCRight = batteryLevel[0].toInt();
      notifyListeners();
    });
  }

  Future<StreamSubscription> startScanning(OpenEarable openEarable) async {
    _scanSubscription?.cancel();
    //_scanning = true;
    _discoveredDevices = [];

    if (openEarable.bleManager.connectedDevice != null) {
      discoveredDevices.add((openEarable.bleManager.connectedDevice)!);
    }
    await openEarable.bleManager.startScan();
    return openEarable.bleManager.scanStream.listen((incomingDevice) {
      if (incomingDevice.name.isNotEmpty &&
          incomingDevice.name.contains(_openEarableName) &&
          !discoveredDevices.any((device) => device.id == incomingDevice.id)) {
        discoveredDevices.add(incomingDevice);
        notifyListeners();
      }
    });
  }

  void connectToDevice(device, OpenEarable openEarable) {
    if (device.name == openEarable.bleManager.connectedDevice?.name ||
        device.name == openEarable.bleManager.connectingDevice?.name) {
      return;
    }

    //_scanning = false;
    openEarable.bleManager.connectToDevice(device);
    prefs.setString("lastConnectedDeviceName", device.name);
  }
}
