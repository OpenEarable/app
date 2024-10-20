import 'dart:async';
import 'package:flutter/material.dart';
import 'package:open_earable/ble/ble_controller.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart';
import 'package:provider/provider.dart';
import 'package:open_earable/ble/ble_connect_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

class V1ConnectCard extends StatefulWidget {
  const V1ConnectCard({super.key});

  @override
  State<V1ConnectCard> createState() => _ConnectCard();
}

class _ConnectCard extends State<V1ConnectCard> {
  bool _autoConnectEnabled = false;
  late OpenEarable _openEarable;
  late SharedPreferences prefs;

  _ConnectCard();

  @override
  void initState() {
    super.initState();
    _getPrefs();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _getPrefs() async {
    prefs = await SharedPreferences.getInstance();
    setState(() {
      _autoConnectEnabled = prefs.getBool("autoConnectEnabled") ?? false;
    });
    _startAutoConnectScan();
  }

  void _startAutoConnectScan() {
    if (_autoConnectEnabled == true) {
      Provider.of<BluetoothController>(context, listen: false)
          .startScanning(_openEarable);
    }
  }

  @override
  Widget build(BuildContext context) {
    _openEarable = Provider.of<BluetoothController>(context, listen: false)
        .openEarableLeft;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 5.0),
      child: Card(
        color: Theme.of(context).colorScheme.primary,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Consumer<BluetoothController>(
            builder: (context, bleController, child) {
              List<DiscoveredDevice> devices = bleController.discoveredDevices;
              _tryAutoconnect(devices, bleController);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Device',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18.0,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Row(
                    children: [
                      Checkbox(
                        checkColor: Theme.of(context).colorScheme.primary,
                        //fillColor: Theme.of(context).colorScheme.primary,
                        value: _autoConnectEnabled,
                        onChanged: (value) => {
                          setState(() {
                            _autoConnectEnabled = value ?? false;
                            _startAutoConnectScan();
                            if (value != null) {
                              prefs.setBool("autoConnectEnabled", value);
                            }
                          }),
                        },
                      ),
                      Text(
                        "Connect to OpenEarable automatically",
                        style: TextStyle(
                          color: Color.fromRGBO(168, 168, 172, 1.0),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 5),
                  _getEarableInfo(bleController),
                  _getConnectButton(context),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  String _batteryPercentageString(BluetoothController bleController) {
    int? percentage = bleController.earableSOCLeft;
    if (percentage == null) {
      return " (...%)";
    } else {
      return " ($percentage%)";
    }
  }

  Widget _getEarableInfo(BluetoothController bleController) {
    return Row(
      children: [
        if (_openEarable.bleManager.connected)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "${_openEarable.bleManager.connectedDevice?.name ?? ""}${_batteryPercentageString(bleController)}",
                style: TextStyle(
                  color: Color.fromRGBO(168, 168, 172, 1.0),
                  fontSize: 15.0,
                ),
              ),
              Text(
                "Firmware: ${_openEarable.deviceFirmwareVersion ?? "not available"}",
                style: TextStyle(
                  color: Color.fromRGBO(168, 168, 172, 1.0),
                  fontSize: 15.0,
                ),
              ),
              Text(
                "Hardware: ${_openEarable.deviceHardwareVersion ?? "not available"}",
                style: TextStyle(
                  color: Color.fromRGBO(168, 168, 172, 1.0),
                  fontSize: 15.0,
                ),
              ),
            ],
          )
        else
          Text(
            "OpenEarable not connected.",
            style: TextStyle(
              color: Color.fromRGBO(168, 168, 172, 1.0),
              fontSize: 15.0,
              fontStyle: FontStyle.italic,
            ),
          ),
      ],
    );
  }

  Widget _getConnectButton(BuildContext context) {
    return Visibility(
      visible: !_openEarable.bleManager.connected,
      child: SizedBox(
        height: 37,
        width: double.infinity,
        child: ElevatedButton(
          onPressed: () => _connectButtonAction(context),
          style: ElevatedButton.styleFrom(
            backgroundColor: !_openEarable.bleManager.connected
                ? Color(0xff77F2A1)
                : Color(0xfff27777),
            foregroundColor: Colors.black,
          ),
          child: Text("Connect"),
        ),
      ),
    );
  }

  void _connectButtonAction(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Theme.of(context).colorScheme.surface,
          appBar: AppBar(
            title: Text("Bluetooth Devices"),
          ),
          body: BLEPage(_openEarable, 0),
        ),
      ),
    );
  }

  void _tryAutoconnect(
    List<DiscoveredDevice> devices,
    BluetoothController bleController,
  ) async {
    if (_autoConnectEnabled != true ||
        devices.isEmpty ||
        bleController.connected) {
      return;
    }
    String? lastConnectedDeviceName =
        prefs.getString("lastConnectedDeviceName");
    DiscoveredDevice? deviceToConnect = devices.firstWhere(
      (device) => device.name == lastConnectedDeviceName,
      orElse: () => devices[0],
    );
    if (_openEarable.bleManager.connectingDevice?.name !=
        deviceToConnect.name) {
      bleController.connectToDevice(deviceToConnect, _openEarable, 0);
    }
  }
}
