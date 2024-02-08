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
  OpenEarable? _openEarable;
  StreamSubscription? _scanSubscription;
  StreamSubscription? _connectionStateSubscription;
  StreamSubscription? _batteryLevelSubscription;

  List<DiscoveredDevice> _discoveredDevices = [];
  List<DiscoveredDevice> get discoveredDevices => _discoveredDevices;

  bool _scanning = false;

  bool _connected = false;
  bool get connected => _connected;

  int? _earableSOC = null;
  int? get earableSOC => _earableSOC;

  Future<void> _initializeSharedPreferences() async {
    prefs = await SharedPreferences.getInstance();
  }

  void set openEarable(OpenEarable openEarable) {
    _openEarable = openEarable;
    _connectionStateSubscription?.cancel();

    _connectionStateSubscription =
        _openEarable?.bleManager.connectionStateStream.listen((connected) {
      _connected = connected;
      if (connected) {
        _getSOC();
      }
      notifyListeners();
    });
  }

  @override
  void dispose() {
    super.dispose();
    _scanSubscription?.cancel();
    _connectionStateSubscription?.cancel();
    _batteryLevelSubscription?.cancel();
  }

  void _getSOC() {
    _batteryLevelSubscription = _openEarable?.sensorManager
        .getBatteryLevelStream()
        .listen((batteryLevel) {
      _earableSOC = batteryLevel[0].toInt();
      notifyListeners();
    });
  }

  Future<void> startScanning() async {
    if (_scanning) {
      return;
    }
    _scanning = true;
    _discoveredDevices = [];
    if (_openEarable == null) {
      return;
    }
    if (_openEarable?.bleManager.connectedDevice != null) {
      discoveredDevices.add((_openEarable?.bleManager.connectedDevice)!);
    }
    await _openEarable?.bleManager.startScan();
    _scanSubscription?.cancel();
    _scanning = false;
    _scanSubscription =
        _openEarable?.bleManager.scanStream.listen((incomingDevice) {
      if (incomingDevice.name.isNotEmpty &&
          incomingDevice.name.contains(_openEarableName) &&
          !discoveredDevices.any((device) => device.id == incomingDevice.id)) {
        discoveredDevices.add(incomingDevice);
        notifyListeners();
      }
    });
  }

  void connectToDevice(device) {
    if (device.name == _openEarable?.bleManager.connectedDevice?.name) {
      return;
    }
    _scanSubscription?.cancel();
    _scanning = false;
    _openEarable?.bleManager.connectToDevice(device);
    prefs.setString("lastConnectedDeviceName", device.name);
  }
}
