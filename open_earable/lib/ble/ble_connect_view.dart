import 'package:flutter/material.dart';
import 'package:open_earable/ble/ble_controller.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart';
import 'package:provider/provider.dart';

class BLEPage extends StatefulWidget {
  final OpenEarable openEarable;
  final int earableIndex;

  const BLEPage(this.openEarable, this.earableIndex, {super.key});

  @override
  State<BLEPage> createState() => _BLEPageState();
}

class _BLEPageState extends State<BLEPage> {
  late OpenEarable _openEarable;

  @override
  void initState() {
    super.initState();
    _openEarable = widget.openEarable;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<BluetoothController>(context, listen: false)
          .startScanning(_openEarable);
    });
  }

  @override
  Widget build(BuildContext context) {
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
                    physics: const NeverScrollableScrollPhysics(),
                    // Disable scrolling,
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
                                  horizontal: -4, vertical: -4,),
                              trailing: _buildTrailingWidget(device.id),
                              onTap: () {
                                controller.connectToDevice(
                                    device, _openEarable, widget.earableIndex,);
                              },
                            ),),
                        if (index != controller.discoveredDevices.length - 1)
                          const Divider(
                            height: 1.0,
                            thickness: 1.0,
                            color: Colors.grey,
                            indent: 16.0,
                            endIndent: 0.0,
                          ),
                      ],);
                    },
                  ),),);
        },),
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
                ),),),
        Center(
          child: ElevatedButton(
            onPressed: () =>
                Provider.of<BluetoothController>(context, listen: false)
                    .startScanning(_openEarable),
            style: ButtonStyle(
              foregroundColor: WidgetStateProperty.all(
                  Theme.of(context).colorScheme.primary,),
              backgroundColor: WidgetStateProperty.all(
                  Theme.of(context).colorScheme.secondary,),
            ),
            child: const Text('Restart Scan'),
          ),
        ),
      ],
    ),);
  }

  Widget _buildTrailingWidget(String id) {
    if (_openEarable.bleManager.connectedDevice?.id == id) {
      return Icon(
          size: 24,
          Icons.check,
          color: Theme.of(context).colorScheme.secondary,);
    } else if (_openEarable.bleManager.connectingDevice?.id == id) {
      return SizedBox(
          height: 24,
          width: 24,
          child: CircularProgressIndicator(strokeWidth: 2),);
    }
    return const SizedBox.shrink();
  }
}
