import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:open_earable/controls_tab/models/open_earable_settings_v2.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import 'package:universal_ble/universal_ble.dart';

import 'package:flutter_reactive_ble/flutter_reactive_ble.dart' as reactive;

class BluetoothController extends ChangeNotifier {
  late SharedPreferences prefs;

  String _openEarableName = "OpenEarable";
  OpenEarable get openEarableLeft => _openEarableLeft;
  OpenEarable get openEarableRight => _openEarableRight;
  OpenEarable _openEarableLeft = OpenEarable();
  OpenEarable _openEarableRight = OpenEarable();

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

  
  /*Future<void> startScanning(OpenEarable openEarable) async {
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
  }*/

Future<void> requestPermissions() async {
  if (await Permission.bluetooth.isDenied) {
    print("Bluetooth permission denied -- requesting");
    await Permission.bluetooth.request();
  }

  if (await Permission.bluetoothScan.isDenied) {
    print("Bluetooth scan permission denied -- requesting");
    await Permission.bluetoothScan.request();
  }

  if (await Permission.bluetoothConnect.isDenied) {
    print("Bluetooth connect permission denied -- requesting");
    await Permission.bluetoothConnect.request();
  }

  if (await Permission.location.isDenied) {
    print("Location permission denied -- requesting");
    await Permission.location.request();
  }
}

/*
Future<void> _checkConnectionStatus(DiscoveredDevice device) async {
    final connection = _ble.connectToDevice(id: device.id, servicesWithCharacteristicsToDiscover: {}).listen(null);
    connection.onDone(() async {
      // Check the connection status after attempting to connect
      final connectedDevices = await _ble.connectedDevices;
      if (connectedDevices.any((d) => d.id == device.id)) {
        setState(() {
          _connectedDevices.add(device);
        });
      }
      // Cancel the connection attempt
      connection.cancel();
    });
  }*/

  Future<void> startScanning(OpenEarable openEarable) async {
    await requestPermissions();
    _scanSubscription?.cancel();
    //_scanning = true;
    _discoveredDevices = [];

    /*FlutterReactiveBle _reactiveBle = FlutterReactiveBle();
    Stream<ConnectionStateUpdate> conn = _reactiveBle.connectedDeviceStream;*/

    //conn.listen(onData)

    List<BluetoothDevice> pairedDevices = await FlutterBluePlus.bondedDevices;
    print("Paired devices: ${pairedDevices}");

    reactive.FlutterReactiveBle _ble = reactive.FlutterReactiveBle();

    List<BleDevice> connectedDevices = await UniversalBle.getSystemDevices(withServices: []);
    for (final device in connectedDevices) {
      if (openEarable.bleManager.connectedDevice != null && openEarable.bleManager.connectedDevice!.id == device.deviceId) continue;
      if (device.isPaired!) {
        int rssi = await _ble.readRssi(device.deviceId);
        DiscoveredDevice d = DiscoveredDevice(id: device.deviceId, name: device.name!, //serviceData: {}, // Populate with actual service data if available
        manufacturerData: device.manufacturerData!, // Populate with actual manufacturer data if available
        rssi: rssi, // Assuming BleDevice has an rssi field
        serviceUuids: []); //, connectable: reactive.Connectable.available);
        print("device: ${device.name}");
        discoveredDevices.add(d);
        notifyListeners();
      }
    }

    if (openEarable.bleManager.connectedDevice != null) {
        print("Already connected device found: ${openEarable.bleManager.connectedDevice}");
        discoveredDevices.add(openEarable.bleManager.connectedDevice!);
        notifyListeners();
    }

    try {
        await openEarable.bleManager.startScan();
    } catch (error) {
        print("Error starting scan: $error");
        return;
    }

    _scanSubscription = openEarable.bleManager.scanStream.listen((incomingDevice) async {
        //List<BluetoothDevice> connectedDevices = await FlutterBluePlus.connectedDevices;
        //print("Connected devices: ${connectedDevices}");

        /*List<BleDevice> connectedDevices = await UniversalBle.getSystemDevices(withServices: []);
        for (final device in connectedDevices) {
          if (device.isPaired!) {
            int rssi = await _ble.readRssi(device.deviceId);
            //print("Connected devices: ${device.name}");
            DiscoveredDevice d = DiscoveredDevice(id: device.deviceId, name: device.name!, serviceData: {}, // Populate with actual service data if available
            manufacturerData: device.manufacturerData!, // Populate with actual manufacturer data if available
            rssi: rssi, // Assuming BleDevice has an rssi field
            serviceUuids: [], connectable: Connectable.available);
            print("Connected device: ${d}");
          }
        }*/

        //print("Discovered device: ${incomingDevice}");

        if (incomingDevice.name.isNotEmpty &&
            incomingDevice.name.contains(_openEarableName) &&
            !discoveredDevices.any((device) => device.id == incomingDevice.id)) {
              print("Discovered device: ${incomingDevice.name}, ${incomingDevice.id}");
            discoveredDevices.add(incomingDevice);
            notifyListeners();
        }
    });
}

  void connectToDevice(device, OpenEarable openEarable, int earableIndex) {
    if (device.name == openEarable.bleManager.connectedDevice?.name ||
        device.name == openEarable.bleManager.connectingDevice?.name) {
      return;
    }
    _scanSubscription?.cancel();
    openEarable.bleManager.connectToDevice(device);
    print("connect to device .................. ${device.name}");
    String side = earableIndex == 0 ? "Left" : "Right";
    String otherSide = earableIndex != 0 ? "Left" : "Right";
    if (prefs.getString("lastConnectedDeviceName" + otherSide) == device.name) {
      prefs.setString("lastConnectedDeviceName" + otherSide, "");
    }
    prefs.setString("lastConnectedDeviceName" + side, device.name);
    Future.microtask(() {
      notifyListeners();
    });
  }
}
