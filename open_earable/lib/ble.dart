import 'dart:async';

import 'package:flutter/material.dart';
import 'package:open_earable_flutter/src/open_earable_flutter.dart';

class BLEPage extends StatefulWidget {
  final OpenEarable openEarable;

  BLEPage(this.openEarable);

  @override
  _BLEPageState createState() => _BLEPageState();
}

class _BLEPageState extends State<BLEPage> {
  late OpenEarable _openEarable;
  StreamSubscription? _scanSubscription;
  StreamSubscription? _connectionStateStream;
  List dummyDevices = [];
  List discoveredDevices = [];
  bool _connectedToEarable = false;
  bool _waitingToConnect = false;
  String? _deviceIdentifier;
  String? _deviceGeneration;

  void _readDeviceInfo() async {
    String? deviceIdentifier = await _openEarable.readDeviceIdentifier();
    String? deviceGeneration = await _openEarable.readDeviceGeneration();
    setState(() {
      _deviceIdentifier = deviceIdentifier;
      _deviceGeneration = deviceGeneration;
    });
  }

  @override
  void dispose() {
    _scanSubscription?.cancel();
    _connectionStateStream?.cancel();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _openEarable = widget.openEarable;
    _startScanning();
    _setupListeners();
    for (int i = 0; i < 10; i++) {
      setState(() {
        //dummyDevices.add(DummyDevice("$i", "Device number $i"));
      });
    }
  }

  void _setupListeners() async {
    _connectionStateStream =
        _openEarable.bleManager.connectionStateStream.listen((connectionState) {
      if (connectionState) {
        _readDeviceInfo();
        _writeSensorConfig();
        setState(() {
          _waitingToConnect = false;
        });
      }
      setState(() {
        _connectedToEarable = connectionState;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Bluetooth Devices'),
        ),
        body: SingleChildScrollView(
            child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(33, 16, 0, 0),
              child: Text(
                "SCANNED DEVICES",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12.0,
                ),
              ),
            ),
            Visibility(
                visible: discoveredDevices.isNotEmpty,
                child: Container(
                    margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(
                        color: Colors.grey,
                        width: 1.0,
                      ),
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                    child: ListView.builder(
                      padding: EdgeInsets.zero,
                      physics:
                          const NeverScrollableScrollPhysics(), // Disable scrolling,
                      shrinkWrap: true,
                      itemCount: discoveredDevices.length,
                      itemBuilder: (BuildContext context, int index) {
                        final device = discoveredDevices[index];
                        return Column(children: [
                          Material(
                              type: MaterialType.transparency,
                              child: ListTile(
                                textColor: Colors.black,
                                selectedTileColor: Colors.grey,
                                title: Text(device.name),
                                titleTextStyle: const TextStyle(fontSize: 16),
                                visualDensity: const VisualDensity(
                                    horizontal: -4, vertical: -4),
                                trailing: _buildTrailingWidget(device.id),
                                onTap: () {
                                  setState(() => _waitingToConnect = true);
                                  _connectToDevice(device);
                                },
                              )),
                          if (index != discoveredDevices.length - 1)
                            const Divider(
                              height: 1.0,
                              thickness: 1.0,
                              color: Colors.grey,
                              indent: 16.0,
                              endIndent: 0.0,
                            ),
                        ]);
                      },
                    ))),
            Visibility(
                visible: _deviceIdentifier != null && _connectedToEarable,
                child: Padding(
                    padding: EdgeInsets.fromLTRB(33, 8, 0, 8),
                    child: Text(
                      "Connected to $_deviceIdentifier $_deviceGeneration",
                      style: const TextStyle(fontSize: 16),
                    ))),
            Center(
              child: ElevatedButton(
                onPressed: _startScanning,
                child: const Text('Restart Scan'),
              ),
            )
          ],
        )),
      ),
    );
  }

  Widget _buildTrailingWidget(String id) {
    if (_openEarable.bleManager.connectedDevice?.id != id) {
      return const SizedBox.shrink();
    } else if (_connectedToEarable) {
      return const Icon(size: 24, Icons.check, color: Colors.green);
    } else if (_waitingToConnect) {
      return const SizedBox(
          height: 24,
          width: 24,
          child: CircularProgressIndicator(strokeWidth: 2));
    }
    return const SizedBox.shrink();
  }

  void _startScanning() async {
    discoveredDevices.removeWhere(
        (device) => device.id != _openEarable.bleManager.connectedDevice?.id);
    _openEarable.bleManager.startScan();
    _scanSubscription?.cancel();
    _scanSubscription =
        _openEarable.bleManager.scanStream.listen((incomingDevice) {
      if (incomingDevice.name.isNotEmpty &&
          !discoveredDevices.any((device) => device.id == incomingDevice.id)) {
        setState(() {
          discoveredDevices.add(incomingDevice);
        });
      }
    });
  }

  Future<void> _connectToDevice(device) async {
    _scanSubscription?.cancel();
    _openEarable.sensorManager.disposeAllSensorDataControllers();
    try {
      await _openEarable.bleManager.connectToDevice(device);
    } catch (e) {
      // Handle connection error.
    }
  }

  Future<void> _writeSensorConfig() async {
    OpenEarableSensorConfig config =
        OpenEarableSensorConfig(sensorId: 4, samplingRate: 8, latency: 0);
    _openEarable.sensorManager.writeSensorConfig(config);
    _openEarable.sensorManager.readScheme();
    //_openEarable.sensorManager.subscribeToSensorData(0).listen((data) {
    //  print(data);
    //});
    //_openEarable.sensorManager.getButtonStateStream().listen((event) {});
    //await _openEarable.rgbLed.setLEDstate(0);
  }
}
