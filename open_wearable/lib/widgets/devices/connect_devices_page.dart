import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart' hide logger;
import 'package:open_wearable/models/this_device_wearable.dart';
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
  DiscoveredDevice? _thisDeviceEntry;

  @override
  void initState() {
    super.initState();
    _startScanning();
    _addThisDeviceToDiscovered();
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
    final connectedIds =
        wearablesProvider.wearables.map((wearable) => wearable.deviceId).toSet();
    List<Widget> discoveredDevicesWidgets = discoveredDevices
        .where((device) => !connectedIds.contains(device.id))
        .map((device) {
      return PlatformListTile(
        title: PlatformText(device.name),
        subtitle: PlatformText(device.id),
        trailing: _buildTrailingWidget(device.id),
        onTap: () {
          if (_thisDeviceEntry?.id == device.id) {
            _connectToThisDevice(context);
          } else {
            _connectToDevice(device, context);
          }
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

  Future<void> _addThisDeviceToDiscovered() async {
    if (_thisDeviceEntry != null) return;
    final profile = await DeviceProfile.fetch();
    if (!mounted) return;

    final thisDevice = DiscoveredDevice(
      id: profile.deviceId,
      name: profile.displayName,
      manufacturerData: Uint8List(0),
      rssi: 0,
      serviceUuids: const [],
    );

    setState(() {
      _thisDeviceEntry = thisDevice;
      if (!discoveredDevices.any((device) => device.id == thisDevice.id)) {
        discoveredDevices.insert(0, thisDevice);
      }
    });
  }

  Future<void> _connectToThisDevice(BuildContext context) async {
    final device = _thisDeviceEntry;
    if (device == null) return;

    setState(() {
      connectingDevices[device.id] = true;
    });

    try {
      final wearable = await ThisDeviceWearable.create(
        disconnectNotifier: WearableDisconnectNotifier(),
      );
      if (!context.mounted) return;
      context.read<WearablesProvider>().addWearable(wearable);
      context.read<SensorRecorderProvider>().addWearable(wearable);
      setState(() {
        discoveredDevices.removeWhere((d) => d.id == device.id);
      });
    } finally {
      if (context.mounted) {
        setState(() {
          connectingDevices.remove(device.id);
        });
      }
    }
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
