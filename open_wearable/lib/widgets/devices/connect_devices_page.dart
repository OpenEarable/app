import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart' hide logger;
import 'package:open_wearable/models/mock_wearable.dart';
import 'package:open_wearable/view_models/sensor_recorder_provider.dart';
import 'package:open_wearable/view_models/wearables_provider.dart';
import 'package:provider/provider.dart';

import '../../models/logger.dart';
import '../../models/wearable_connector.dart';

/// Page for connecting to devices
///
/// All BLE devices are listed and tapping on it will connect to the device.
/// Connected Wearables are added to the [WearablesProvider].
class ConnectDevicesPage extends StatefulWidget {
  const ConnectDevicesPage({super.key});

  @override
  State<ConnectDevicesPage> createState() => _ConnectDevicesPageState();
}

class _ConnectDevicesPageState extends State<ConnectDevicesPage> {
  final WearableManager _wearableManager = WearableManager();
  StreamSubscription? _scanSubscription;

  List<DiscoveredDevice> discoveredDevices = [];
  Map<String, bool> connectingDevices = {};

  @override
  void initState() {
    super.initState();
    _startScanning();
  }

  @override
  Widget build(BuildContext context) {
    final WearablesProvider wearablesProvider =
        Provider.of<WearablesProvider>(context);

    List<Widget> connectedDevicesWidgets =
        wearablesProvider.wearables.map((wearable) {
      return PlatformListTile(
        title: PlatformText(wearable.name),
        subtitle: PlatformText(wearable.deviceId),
        trailing: Icon(PlatformIcons(context).checkMark),
      );
    }).toList();
    List<Widget> discoveredDevicesWidgets = discoveredDevices.map((device) {
      return PlatformListTile(
        title: PlatformText(device.name),
        subtitle: PlatformText(device.id),
        trailing: _buildTrailingWidget(device.id),
        onTap: () {
          _connectToDevice(device, context);
        },
      );
    }).toList();

    return PlatformScaffold(
      appBar: PlatformAppBar(
        title: PlatformText('Connect Devices'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(10.0),
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: PlatformText(
                'Connected Devices',
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            ...connectedDevicesWidgets,
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: PlatformText(
                'Discovered Devices',
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            ...discoveredDevicesWidgets,
            PlatformElevatedButton(
              onPressed: _startScanning,
              child: PlatformText('Scan'),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: PlatformElevatedButton(
                onPressed: () {
                  final mockWearable = MockWearable(
                    disconnectNotifier: WearableDisconnectNotifier(),
                  );
                  context.read<WearablesProvider>().addWearable(mockWearable);
                  context
                      .read<SensorRecorderProvider>()
                      .addWearable(mockWearable);
                },
                child: PlatformText('Simulate Device'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrailingWidget(String id) {
    if (connectingDevices[id] == true) {
      return SizedBox(
        height: 24,
        width: 24,
        child: PlatformCircularProgressIndicator(),
      );
    }
    return const SizedBox.shrink();
  }

  void _startScanning() async {
    _wearableManager.startScan();
    _scanSubscription?.cancel();
    _scanSubscription = _wearableManager.scanStream.listen((incomingDevice) {
      if (incomingDevice.name.isNotEmpty &&
          !discoveredDevices.any((device) => device.id == incomingDevice.id)) {
        logger.d('Discovered device: ${incomingDevice.name}');
        setState(() {
          discoveredDevices.add(incomingDevice);
        });
      }
    });
  }

  Future<void> _connectToDevice(
    DiscoveredDevice device,
    BuildContext context,
  ) async {
    setState(() {
      connectingDevices[device.id] = true;
    });

    try {
      WearableConnector connector = context.read<WearableConnector>();
      await connector.connect(device);
      setState(() {
        discoveredDevices.remove(device);
      });
    } catch (e) {
      String message = _wearableManager.deviceErrorMessage(e, device.name);
      logger.e('Failed to connect to device: ${device.name}, error: $message');
      if (context.mounted) {
        showPlatformDialog(
          context: context,
          builder: (context) => PlatformAlertDialog(
            title: PlatformText('Connection Error'),
            content: PlatformText(message),
            actions: [
              PlatformDialogAction(
                onPressed: () => Navigator.of(context).pop(),
                child: PlatformText('OK'),
              ),
            ],
          ),
        );
      }
    } finally {
      setState(() {
        connectingDevices.remove(device.id);
      });
    }
  }

  @override
  void dispose() {
    _scanSubscription?.cancel();
    super.dispose();
  }
}
