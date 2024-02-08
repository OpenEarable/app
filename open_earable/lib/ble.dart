import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:open_earable/ble_controller.dart';
import 'package:open_earable_flutter/src/open_earable_flutter.dart';
import 'package:provider/provider.dart';

class BLEPage extends StatefulWidget {
  final OpenEarable openEarable;

  BLEPage(this.openEarable);

  @override
  _BLEPageState createState() => _BLEPageState();
}

class _BLEPageState extends State<BLEPage> {
  final String _pageTitle = "Bluetooth Devices";
  late OpenEarable _openEarable;
  @override
  void initState() {
    super.initState();
    _openEarable = widget.openEarable;
    Provider.of<BluetoothController>(context, listen: false).startScanning();
  }

  @override
  Widget build(BuildContext context) {
    return Platform.isIOS
        ? CupertinoPageScaffold(
            navigationBar: CupertinoNavigationBar(middle: Text(_pageTitle)),
            child: SafeArea(
              child: _getBody(),
            ))
        : Scaffold(
            backgroundColor: Theme.of(context).colorScheme.background,
            appBar: AppBar(
              title: Text(_pageTitle),
            ),
            body: _getBody());
  }

  Widget _getBody() {
    return SingleChildScrollView(
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
        Consumer<BluetoothController>(builder: (context, controller, child) {
          return Visibility(
              visible: controller.discoveredDevices.isNotEmpty,
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
                    itemCount: controller.discoveredDevices.length,
                    itemBuilder: (BuildContext context, int index) {
                      final device = controller.discoveredDevices[index];
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
                                controller.connectToDevice(device);
                              },
                            )),
                        if (index != controller.discoveredDevices.length - 1)
                          const Divider(
                            height: 1.0,
                            thickness: 1.0,
                            color: Colors.grey,
                            indent: 16.0,
                            endIndent: 0.0,
                          ),
                      ]);
                    },
                  )));
        }),
        Center(
            child: Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  (_openEarable.bleManager.deviceIdentifier != null &&
                          _openEarable.bleManager.deviceFirmwareVersion != null)
                      ? "Connected to ${_openEarable.bleManager.deviceIdentifier} ${_openEarable.bleManager.deviceFirmwareVersion}"
                      : "If your OpenEarable device is not shown here, try restarting it",
                  style: const TextStyle(fontSize: 16),
                  textAlign: TextAlign.center,
                ))),
        Center(
          child: ElevatedButton(
            onPressed: Provider.of<BluetoothController>(context, listen: false)
                .startScanning,
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
    ));
  }

  Widget _buildTrailingWidget(String id) {
    if (_openEarable.bleManager.connectedDevice?.id == id) {
      return Icon(
          size: 24,
          Platform.isIOS ? CupertinoIcons.check_mark : Icons.check,
          color: Platform.isIOS
              ? CupertinoTheme.of(context).primaryColor
              : Theme.of(context).colorScheme.secondary);
    } else if (_openEarable.bleManager.connectingDevice?.id == id) {
      return SizedBox(
          height: 24,
          width: 24,
          child: Platform.isIOS
              ? CupertinoActivityIndicator()
              : CircularProgressIndicator(strokeWidth: 2));
    }
    return const SizedBox.shrink();
  }
}
