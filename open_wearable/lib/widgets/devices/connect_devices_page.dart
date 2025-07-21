import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:logger/logger.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart';
import 'package:open_wearable/view_models/sensor_recorder_provider.dart';
import 'package:open_wearable/view_models/wearables_provider.dart';
import 'package:open_wearable/widgets/fota/firmware_update.dart';
import 'package:provider/provider.dart';

Logger _logger = Logger();

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

  List discoveredDevices = [];
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
        _logger.d('Discovered device: ${incomingDevice.name}');
        setState(() {
          discoveredDevices.add(incomingDevice);
        });
      }
    });
  }

  Future<void> _connectToDevice(device, context) async {
    setState(() {
      connectingDevices[device.id] = true;
    });

    try {
      Wearable wearable = await _wearableManager.connectToDevice(device);
      Provider.of<WearablesProvider>(context, listen: false)
          .addWearable(wearable);
      Provider.of<SensorRecorderProvider>(context, listen: false)
          .addWearable(wearable);
      setState(() {
        discoveredDevices.remove(device);
      });
      checkForNewerFirmware(wearable);
    } catch (e) {
      _logger.e('Failed to connect to device: ${device.name}, error: $e');
    } finally {
      setState(() {
        connectingDevices.remove(device.id);
      });
    }
  }

  void checkForNewerFirmware(Wearable wearable) async {
    _logger.d('Checking for newer firmware for ${wearable.name}');
    if (wearable is DeviceFirmwareVersion) {
      final currentVersion =
          await (wearable as DeviceFirmwareVersion).readDeviceFirmwareVersion();
      if (currentVersion == null || currentVersion.isEmpty) {
        return;
      }
      final firmwareImageRepository = FirmwareImageRepository();
      var latestVersion = await firmwareImageRepository
          .getLatestFirmwareVersion()
          .then((version) => version.toString());
      if (firmwareImageRepository.isNewerVersion(
        latestVersion,
        currentVersion,
      )) {
        print("Checking");
        if (!mounted) return;
        showDialog(
          context: context,
          builder: (context) => PlatformAlertDialog(
            title: PlatformText('Firmware Update Available'),
            content: PlatformText(
              'A newer firmware version ($latestVersion) is available. You are using version $currentVersion.',
            ),
            actions: [
              PlatformTextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: PlatformText('Later'),
              ),
              PlatformTextButton(
                onPressed: () {
                  Provider.of<FirmwareUpdateRequestProvider>(
                    context,
                    listen: false,
                  ).setSelectedPeripheral(wearable);
                  Navigator.of(context).pop();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const FirmwareUpdateWidget(),
                    ),
                  );
                },
                child: PlatformText('Update Now'),
              ),
            ],
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _scanSubscription?.cancel();
    super.dispose();
  }
}
