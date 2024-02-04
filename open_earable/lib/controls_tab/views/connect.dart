import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:open_earable/ble_controller.dart';
import 'package:open_earable_flutter/src/open_earable_flutter.dart';
import 'package:provider/provider.dart';
import '../../ble.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ConnectCard extends StatefulWidget {
  final OpenEarable _openEarable;
  ConnectCard(this._openEarable);

  @override
  _ConnectCard createState() => _ConnectCard(this._openEarable);
}

class _ConnectCard extends State<ConnectCard> {
  final OpenEarable _openEarable;
  bool? _autoConnectEnabled = false;
  late SharedPreferences prefs;

  _ConnectCard(this._openEarable);

  @override
  void initState() {
    super.initState();
    _getPrefs();
    _startAutoConnectScan();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _getPrefs() async {
    prefs = await SharedPreferences.getInstance();
    setState(() {
      _autoConnectEnabled = prefs.getBool("autoConnectEnabled");
    });
  }

  void _startAutoConnectScan() {
    if (_autoConnectEnabled == true) {
      Provider.of<BluetoothController>(context, listen: false).startScanning();
    }
  }

  @override
  Widget build(BuildContext context) {
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
                          _autoConnectEnabled = value;
                          _startAutoConnectScan();
                          if (value != null)
                            prefs.setBool("autoConnectEnabled", value);
                        })
                      },
                    ),
                    Text("Connect to OpenEarable automatically")
                  ],
                ),
                SizedBox(height: 5),
                _getEarableInfo(bleController),
                _getConnectButton(context),
              ],
            );
          }),
        ),
      ),
    );
  }

  String _batteryPercentageString(BluetoothController bleController) {
    int? percentage = bleController.earableSOC;
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
                "Firmware ${_openEarable.deviceFirmwareVersion ?? "0.0.0"}",
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
      child: Column(
        children: [
          SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 37.0,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).push(MaterialPageRoute(
                          builder: (context) => BLEPage(_openEarable)));
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: !_openEarable.bleManager.connected
                          ? Color(0xff77F2A1)
                          : Color(0xfff27777),
                      foregroundColor: Colors.black,
                    ),
                    child: Text("Connect"),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _tryAutoconnect(
      List<DiscoveredDevice> devices, BluetoothController bleController) async {
    if (_autoConnectEnabled != true ||
        devices.isEmpty ||
        bleController.connected) {
      return;
    }
    String? lastConnectedDeviceName =
        prefs.getString("lastConnectedDeviceName");
    DiscoveredDevice? deviceToConnect = devices.firstWhere(
        (device) => device.name == lastConnectedDeviceName,
        orElse: () => devices[0]);
    if (_openEarable.bleManager.connectingDevice?.name !=
        deviceToConnect.name) {
      bleController.connectToDevice(deviceToConnect);
    }
  }
}
