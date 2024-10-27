import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:open_earable/controls_tab/models/open_earable_settings_v2.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BluetoothController extends ChangeNotifier {
  late SharedPreferences prefs;

  final String _openEarableName = "OpenEarable";

  OpenEarable get openEarableLeft => _openEarableLeft;

  OpenEarable get openEarableRight => _openEarableRight;
  final OpenEarable _openEarableLeft = OpenEarable();
  final OpenEarable _openEarableRight = OpenEarable();

  bool _isV2 = false;

  bool get isV2 => _isV2;

  late OpenEarable _currentOpenEarable;

  OpenEarable get currentOpenEarable => _currentOpenEarable;

  StreamSubscription? _scanSubscription;
  StreamSubscription? _connectionStateSubscriptionLeft;
  StreamSubscription? _connectionStateSubscriptionRight;

  StreamSubscription? _batteryLevelSubscriptionLeft;
  StreamSubscription? _batteryLevelSubscriptionRight;

  List<DiscoveredDevice> _discoveredDevices = [];

  List<DiscoveredDevice> get discoveredDevices => _discoveredDevices;

  BluetoothController() {
    _initializeSharedPreferences();
    updateCurrentOpenEarable();
  }

  void updateCurrentOpenEarable() {
    _currentOpenEarable = OpenEarableSettingsV2().selectedButtonIndex == 0
        ? _openEarableLeft
        : _openEarableRight;
    notifyListeners();
  }

  //bool _scanning = false;

  bool get connected => _connectedLeft || _connectedRight;

  bool _connectedLeft = false;

  bool get connectedLeft => _connectedLeft;

  bool _connectedRight = false;

  bool get connectedRight => _connectedRight;

  int? _earableSOCLeft;

  int? get earableSOCLeft => _earableSOCLeft;

  int? _earableSOCRight;

  int? get earableSOCRight => _earableSOCRight;

  Future<void> _initializeSharedPreferences() async {
    prefs = await SharedPreferences.getInstance();
  }

  void setupListeners() {
    _connectionStateSubscriptionLeft?.cancel();
    _connectionStateSubscriptionRight?.cancel();

    _connectionStateSubscriptionLeft =
        _openEarableLeft.bleManager.connectionStateStream.listen((connected) {
      _isV2 = _openEarableLeft.deviceHardwareVersion?.substring(0, 1) == "2";
      _connectedLeft = connected;
      if (connected) {
        _getSOCLeft();
      } else {
        _earableSOCLeft = null;
        startScanning(_openEarableLeft);
      }
      notifyListeners();
    });

    _connectionStateSubscriptionRight =
        _openEarableRight.bleManager.connectionStateStream.listen((connected) {
      _connectedRight = connected;
      if (connected) {
        _getSOCRight();
      } else {
        _earableSOCRight = null;
        startScanning(_openEarableRight);
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

  Future<void> startScanning(OpenEarable openEarable) async {
    _scanSubscription?.cancel();
    //_scanning = true;
    _discoveredDevices = [];

    if (openEarable.bleManager.connectedDevice != null) {
      discoveredDevices.add((openEarable.bleManager.connectedDevice)!);
      notifyListeners();
    }
    await openEarable.bleManager.startScan();
    _scanSubscription =
        openEarable.bleManager.scanStream.listen((incomingDevice) {
      if (incomingDevice.name.isNotEmpty &&
          incomingDevice.name.contains(_openEarableName) &&
          !discoveredDevices.any((device) => device.id == incomingDevice.id)) {
        discoveredDevices.add(incomingDevice);
        notifyListeners();
      }
    });
  }

  Future<void> connectToDevice(
    device,
    OpenEarable openEarable,
    int earableIndex,
  ) async {
    if (device.name == openEarable.bleManager.connectedDevice?.name ||
        device.name == openEarable.bleManager.connectingDevice?.name) {
      return;
    }
    _scanSubscription?.cancel();
    await openEarable.bleManager.connectToDevice(device);
    String side = earableIndex == 0 ? "Left" : "Right";
    String otherSide = earableIndex != 0 ? "Left" : "Right";
    if (prefs.getString("lastConnectedDeviceName$otherSide") == device.name) {
      prefs.setString("lastConnectedDeviceName$otherSide", "");
    }
    prefs.setString("lastConnectedDeviceName$side", device.name);
    Future.microtask(notifyListeners);
  }
}
