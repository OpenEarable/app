import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:open_earable/ble/ble_controller.dart';
import 'package:open_earable_flutter/src/open_earable_flutter.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:open_earable/ble/ble_connect_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ConnectCard extends StatefulWidget {
  final OpenEarable _openEarable;
  ConnectCard(this._openEarable);

  @override
  _ConnectCard createState() => _ConnectCard(this._openEarable);
}

class _ConnectCard extends State<ConnectCard> {
  final OpenEarable _openEarable;
  bool _autoConnectEnabled = false;
  late SharedPreferences prefs;
  int selectedButton = 0;

  _ConnectCard(this._openEarable);

  void selectButton(int index) {
    setState(() {
      selectedButton = index;
    });
  }

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
      Provider.of<BluetoothController>(context, listen: false).startScanning();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 0.0),
      child: Card(
        color: Platform.isIOS
            ? CupertinoTheme.of(context).primaryContrastingColor
            : Theme.of(context).colorScheme.primary,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Consumer<BluetoothController>(
              builder: (context, bleController, child) {
            List<DiscoveredDevice> devices = bleController.discoveredDevices;
            _tryAutoconnect(devices, bleController);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Devices',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18.0,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Row(
                  children: [
                    Platform.isIOS
                        ? CupertinoCheckbox(
                            value: _autoConnectEnabled,
                            onChanged: (value) => {
                              setState(() {
                                _autoConnectEnabled = value ?? false;
                                _startAutoConnectScan();
                                if (value != null)
                                  prefs.setBool("autoConnectEnabled", value);
                              })
                            },
                            activeColor: _autoConnectEnabled
                                ? CupertinoTheme.of(context).primaryColor
                                : CupertinoTheme.of(context)
                                    .primaryContrastingColor,
                            checkColor: CupertinoTheme.of(context)
                                .primaryContrastingColor,
                          )
                        : Checkbox(
                            checkColor: Theme.of(context).colorScheme.primary,
                            //fillColor: Theme.of(context).colorScheme.primary,
                            value: _autoConnectEnabled,
                            onChanged: (value) => {
                              setState(() {
                                _autoConnectEnabled = value ?? false;
                                _startAutoConnectScan();
                                if (value != null)
                                  prefs.setBool("autoConnectEnabled", value);
                              })
                            },
                          ),
                    Text(
                      "Connect to OpenEarable automatically",
                      style: TextStyle(
                        color: Color.fromRGBO(168, 168, 172, 1.0),
                      ),
                    )
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: <Widget>[
                    Expanded(
                        child: Column(children: [
                      _getEarableSelectButton(
                        imagePath:
                            "assets/OpenEarableV2-L.png", // path to your image asset
                        isSelected: selectedButton == 0,
                        onPressed: () => selectButton(0),
                        bleController: bleController,
                      ),
                      SizedBox(height: 8),
                      _getConnectButton(context),
                    ])),
                    SizedBox(width: 8),
                    Expanded(
                        child: Column(children: [
                      _getEarableSelectButton(
                        imagePath: "assets/OpenEarableV2-R.png",
                        isSelected: selectedButton == 1,
                        onPressed: () => selectButton(1),
                        bleController: bleController,
                      ),
                      SizedBox(height: 8),
                      _getConnectButton(context),
                    ])),
                  ],
                ),
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
      return " (XX%)";
    } else {
      return " ($percentage%)";
    }
  }

  Widget _getConnectButton(BuildContext context) {
    return Container(
      height: 37,
      width: double.infinity,
      child: !Platform.isIOS
          ? ElevatedButton(
              onPressed: () => _connectButtonAction(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xff77F2A1),
                foregroundColor: Colors.black,
              ),
              child: Text("Connect"),
            )
          : CupertinoButton(
              padding: EdgeInsets.zero,
              color: CupertinoTheme.of(context).primaryColor,
              child: Text("Connect"),
              onPressed: () => _connectButtonAction(context)),
    );
  }

  _connectButtonAction(BuildContext context) {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (context) => BLEPage(_openEarable)));
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

  Widget _getEarableSelectButton({
    required String imagePath,
    required bool isSelected,
    required onPressed,
    required bleController,
  }) {
    if (Platform.isIOS) {
      return CupertinoButton(
        color: Color.fromARGB(255, 83, 81, 91),
        onPressed: onPressed,
        padding:
            EdgeInsets.zero, // Remove padding to use the entire container space
        child: Container(
          padding: EdgeInsets.all(8.0), // Internal padding within the button
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(
                7.0), // Slightly smaller radius for the inner border
            border: Border.all(
              color: isSelected
                  ? CupertinoTheme.of(context).primaryColor
                  : Colors.transparent,
              width: 3,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "${_openEarable.bleManager.connectedDevice?.name ?? "OpenEarable-XXXX"}${_batteryPercentageString(bleController)}",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15.0,
                ),
              ),
              SizedBox(height: 8),
              Image.asset(imagePath, fit: BoxFit.fill),
              SizedBox(height: 8),
              Text(
                "Firmware: ${_openEarable.deviceFirmwareVersion ?? "X.X.X"}",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15.0,
                ),
              ),
              Text(
                "Hardware: ${_openEarable.deviceHardwareVersion ?? "X.X.X"}",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15.0,
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      return ElevatedButton(
        onPressed: onPressed,
        style: ButtonStyle(
          backgroundColor: MaterialStateProperty.all(
              Color.fromARGB(255, 83, 81, 91)), // Adjust the color as needed
          shape: MaterialStateProperty.all<RoundedRectangleBorder>(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10.0),
              side: BorderSide(
                color: isSelected
                    ? Theme.of(context).colorScheme.secondary
                    : Colors.transparent,
                width: 3,
              ),
            ),
          ),
          padding: MaterialStateProperty.all(
              EdgeInsets.zero), // Adjust padding if necessary
        ),
        child: Container(
          padding: EdgeInsets.all(8.0), // Padding inside the button for content
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "${_openEarable.bleManager.connectedDevice?.name ?? "OpenEarable-XXXX"}${_batteryPercentageString(bleController)}", // Assuming _openEarable and bleController are accessible
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15.0,
                ),
              ),
              SizedBox(height: 8),
              Image.asset(imagePath, fit: BoxFit.fill),
              SizedBox(height: 8),
              Text(
                "Firmware: ${_openEarable.deviceFirmwareVersion ?? "X.X.X"}",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15.0,
                ),
              ),
              Text(
                "Hardware: ${_openEarable.deviceHardwareVersion ?? "X.X.X"}",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15.0,
                ),
              ),
            ],
          ),
        ),
      );
    }
  }
}
