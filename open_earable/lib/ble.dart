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
  String _openEarableName = "OpenEarable";
  late OpenEarable _openEarable;
  StreamSubscription? _scanSubscription;
  StreamSubscription? _connectionStateStream;
  List discoveredDevices = [];

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
  }

  void _setupListeners() async {
    _connectionStateStream =
        _openEarable.bleManager.connectionStateStream.listen((connected) {
      setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
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
                  margin: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                  decoration: BoxDecoration(
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
                              selectedTileColor: Colors.grey,
                              title: Text(device.name),
                              titleTextStyle: const TextStyle(fontSize: 16),
                              visualDensity: const VisualDensity(
                                  horizontal: -4, vertical: -4),
                              trailing: _buildTrailingWidget(device.id),
                              onTap: () {
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
          Center(
              child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    (_openEarable.bleManager.deviceIdentifier != null &&
                            _openEarable.bleManager.deviceFirmwareVersion !=
                                null)
                        ? "Connected to ${_openEarable.bleManager.deviceIdentifier} ${_openEarable.bleManager.deviceFirmwareVersion}"
                        : "If your OpenEarable device is not shown here, try restarting it",
                    style: const TextStyle(fontSize: 16),
                    textAlign: TextAlign.center,
                  ))),
          Center(
            child: ElevatedButton(
              onPressed: _startScanning,
              style: ButtonStyle(
                foregroundColor: MaterialStateProperty.all(
                    Theme.of(context).colorScheme.primary),
                backgroundColor: MaterialStateProperty.all(
                    Theme.of(context).colorScheme.secondary),
              ),
              child: const Text('Restart Scan'),
            ),
          )
        ],
      )),
    );
  }

  Widget _buildTrailingWidget(String id) {
    if (_openEarable.bleManager.connectedDevice?.id == id) {
      return Icon(
          size: 24,
          Icons.check,
          color: Theme.of(context).colorScheme.secondary);
    } else if (_openEarable.bleManager.connectingDevice?.id == id) {
      return const SizedBox(
          height: 24,
          width: 24,
          child: CircularProgressIndicator(strokeWidth: 2));
    }
    return const SizedBox.shrink();
  }

  void _startScanning() async {
    discoveredDevices = [];
    if (_openEarable.bleManager.connectedDevice != null) {
      discoveredDevices.add(_openEarable.bleManager.connectedDevice);
    }
    setState(() {}); // Update UI
    await _openEarable.bleManager.startScan();
    _scanSubscription?.cancel();
    _scanSubscription =
        _openEarable.bleManager.scanStream.listen((incomingDevice) {
      if (incomingDevice.name.isNotEmpty &&
          incomingDevice.name.contains(_openEarableName) &&
          !discoveredDevices.any((device) => device.id == incomingDevice.id)) {
        setState(() {
          discoveredDevices.add(incomingDevice);
        });
      }
    });
  }

  void _connectToDevice(device) {
    _scanSubscription?.cancel();
    _openEarable.bleManager.connectToDevice(device);
  }
}
