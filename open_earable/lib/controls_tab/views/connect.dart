import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:open_earable/ble/ble_controller.dart';
import 'package:open_earable/controls_tab/models/open_earable_settings_v2.dart';
import 'package:open_earable_flutter/src/open_earable_flutter.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:open_earable/ble/ble_connect_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ConnectCard extends StatefulWidget {
  ConnectCard();

  @override
  _ConnectCard createState() => _ConnectCard();
}

class _ConnectCard extends State<ConnectCard> {
  late OpenEarable _openEarableLeft;
  late OpenEarable _openEarableRight;
  bool _autoConnectEnabled = false;
  late SharedPreferences prefs;

  _ConnectCard();

  void selectButton(int index) {
    setState(() {
      OpenEarableSettingsV2().selectedButtonIndex = index;
    });
    Provider.of<BluetoothController>(context, listen: false)
        .updateCurrentOpenEarable();
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
    _autoConnectEnabled = false;
    prefs = await SharedPreferences.getInstance();
    setState(() {
      _autoConnectEnabled = prefs.getBool("autoConnectEnabled") ?? false;
    });
    _startAutoConnectScan();
  }

  void _startAutoConnectScan() async {
    if (_autoConnectEnabled) {
      Provider.of<BluetoothController>(context, listen: false).startScanning(
          _openEarableLeft); // Scanning on one earable is sufficient to connect to both
    }
  }

  @override
  Widget build(BuildContext context) {
    _openEarableLeft = Provider.of<BluetoothController>(context, listen: false)
        .openEarableLeft;
    _openEarableRight = Provider.of<BluetoothController>(context, listen: false)
        .openEarableRight;
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
                            onChanged: (value) {
                              setState(() {
                                _autoConnectEnabled = value ?? false;
                              });
                              _startAutoConnectScan();
                              if (value != null)
                                prefs.setBool("autoConnectEnabled", value);
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
                            onChanged: (value) {
                              setState(() {
                                _autoConnectEnabled = value ?? false;
                              });
                              _startAutoConnectScan();
                              if (value != null)
                                prefs.setBool("autoConnectEnabled", value);
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
                          isSelected:
                              OpenEarableSettingsV2().selectedButtonIndex == 0,
                          onPressed: () => selectButton(0),
                          bleController: bleController,
                          openEarable: _openEarableLeft,
                          percentage: bleController.earableSOCLeft),
                      SizedBox(height: 8),
                      _getConnectButton(context, "Left"),
                    ])),
                    SizedBox(width: 8),
                    Expanded(
                        child: Column(children: [
                      _getEarableSelectButton(
                        imagePath: "assets/OpenEarableV2-R.png",
                        isSelected:
                            OpenEarableSettingsV2().selectedButtonIndex == 1,
                        onPressed: () => selectButton(1),
                        bleController: bleController,
                        openEarable: _openEarableRight,
                        percentage: bleController.earableSOCRight,
                      ),
                      SizedBox(height: 8),
                      _getConnectButton(context, "Right"),
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

  String _batteryPercentageString(int? percentage) {
    if (percentage == null) {
      return " (XX%)";
    } else {
      return " ($percentage%)";
    }
  }

  Widget _getConnectButton(BuildContext context, String side) {
    return Container(
      height: 37,
      width: double.infinity,
      child: !Platform.isIOS
          ? ElevatedButton(
              onPressed: () => _connectButtonAction(context, side),
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
              onPressed: () => _connectButtonAction(context, side)),
    );
  }

  _connectButtonAction(BuildContext context, String side) {
    Navigator.of(context).push(MaterialPageRoute(
        builder: (context) =>
            BLEPage(side == "Left" ? _openEarableLeft : _openEarableRight)));
  }

  void _tryAutoconnect(
      List<DiscoveredDevice> devices, BluetoothController bleController) async {
    if (_autoConnectEnabled != true || devices.isEmpty) {
      return;
    }
    String? lastConnectedDeviceNameLeft =
        prefs.getString("lastConnectedDeviceNameLeft");
    String? lastConnectedDeviceNameRight =
        prefs.getString("lastConnectedDeviceNameRight");
    DiscoveredDevice? deviceToConnectLeft = devices.firstWhere(
        (device) => device.name == lastConnectedDeviceNameLeft,
        orElse: () => devices.first);
    DiscoveredDevice? deviceToConnectRight = devices.firstWhere(
        (device) => device.name == lastConnectedDeviceNameRight,
        orElse: () => devices.last);
    if (_openEarableLeft.bleManager.connectingDevice?.name !=
        deviceToConnectLeft.name) {
      bleController.connectToDevice(deviceToConnectLeft, _openEarableLeft);
    }
    if (deviceToConnectLeft != deviceToConnectRight &&
        _openEarableRight.bleManager.connectingDevice?.name !=
            deviceToConnectRight) {
      bleController.connectToDevice(deviceToConnectRight, _openEarableRight);
    }
  }

  Widget _getEarableSelectButton({
    required OpenEarable openEarable,
    required String imagePath,
    required bool isSelected,
    required onPressed,
    required BluetoothController bleController,
    required int? percentage,
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
                "${openEarable.bleManager.connectedDevice?.name ?? "OpenEarable-XXXX"}${_batteryPercentageString(percentage)}",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15.0,
                ),
              ),
              SizedBox(height: 8),
              Image.asset(imagePath, fit: BoxFit.fill),
              SizedBox(height: 8),
              Text(
                "Firmware: ${openEarable.deviceFirmwareVersion ?? "X.X.X"}",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15.0,
                ),
              ),
              Text(
                "Hardware: ${openEarable.deviceHardwareVersion ?? "X.X.X"}",
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
                "${openEarable.bleManager.connectedDevice?.name ?? "OpenEarable-XXXX"}${_batteryPercentageString(percentage)}", // Assuming _openEarable and bleController are accessible
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15.0,
                ),
              ),
              SizedBox(height: 8),
              Image.asset(imagePath, fit: BoxFit.fill),
              SizedBox(height: 8),
              Text(
                "Firmware: ${openEarable.deviceFirmwareVersion ?? "X.X.X"}",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15.0,
                ),
              ),
              Text(
                "Hardware: ${openEarable.deviceHardwareVersion ?? "X.X.X"}",
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
