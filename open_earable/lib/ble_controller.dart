import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:open_earable_flutter/src/open_earable_flutter.dart';

class BluetoothController extends ChangeNotifier {
  String _openEarableName = "OpenEarable";
  OpenEarable? _openEarable;
  StreamSubscription? _scanSubscription;
  StreamSubscription? _connectionStateSubscription;

  List<DiscoveredDevice> _discoveredDevices = [];
  List<DiscoveredDevice> get discoveredDevices => _discoveredDevices;

  void set openEarable(OpenEarable openEarable) {
    _openEarable = openEarable;
    _connectionStateSubscription?.cancel();
    _connectionStateSubscription =
        _openEarable?.bleManager.connectionStateStream.listen((event) {
      notifyListeners();
      print("Connections tate stream");
      print(event);
    });
  }

  @override
  void dispose() {
    super.dispose();
    _scanSubscription?.cancel();
    _connectionStateSubscription?.cancel();
  }

  Future<void> startScanning() async {
    _discoveredDevices = [];
    print("START SCAN");
    if (_openEarable == null) {
      return;
    }
    if (_openEarable?.bleManager.connectedDevice != null) {
      discoveredDevices.add((_openEarable?.bleManager.connectedDevice)!);
    }
    await _openEarable?.bleManager.startScan();
    _scanSubscription?.cancel();
    _scanSubscription =
        _openEarable?.bleManager.scanStream.listen((incomingDevice) {
      if (incomingDevice.name.isNotEmpty &&
          incomingDevice.name.contains(_openEarableName) &&
          !discoveredDevices.any((device) => device.id == incomingDevice.id)) {
        discoveredDevices.add(incomingDevice);
        print("NEW DEVICE");
        notifyListeners();
      }
    });
  }

  void connectToDevice(device) {
    _openEarable?.bleManager.connectToDevice(device);
    notifyListeners();
  }
}
