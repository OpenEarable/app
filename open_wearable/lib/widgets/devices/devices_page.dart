import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:open_earable_flutter/open_earable_flutter.dart';
import 'package:open_wearable/view_models/wearables_provider.dart';
import 'package:open_wearable/widgets/devices/battery_state.dart';
import 'package:open_wearable/widgets/devices/connect_devices_page.dart';
import 'package:open_wearable/widgets/devices/device_detail/device_detail_page.dart';
import 'package:provider/provider.dart';

import '../../view_models/sensor_recorder_provider.dart';
import 'device_detail/stereo_pos_label.dart';

/// On this page the user can see all connected devices.
///
/// Tapping on a device will navigate to the [DeviceDetailPage].
class DevicesPage extends StatefulWidget {
  const DevicesPage({super.key});

  @override
  State<DevicesPage> createState() => _DevicesPageState();
}

class _DevicesPageState extends State<DevicesPage> {
  @override
  void initState() {
    super.initState();

    _startBluetooth();
  }

  Future<void> _startBluetooth() async {
    if (!await WearableManager().hasPermissions() && !Platform.isIOS) {
      if (mounted) {
        // show a dialog to request permissions
        await showPlatformDialog(
          context: context,
          builder: (context) {
            return PlatformAlertDialog(
              title: PlatformText("Permissions Required"),
              content: PlatformText(
                "This app requires Bluetooth and Location permissions to function properly.\n"
                "Location access is needed for Bluetooth scanning to work. Please enable both "
                "Bluetooth and Location services and grant the necessary permissions.\n"
                "No data will be collected or sent to any server and will remain only on your device.",
              ),
              actions: [
                PlatformDialogAction(
                  child: PlatformText("OK"),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
              ],
            );
          },
        );
      }
    }

    WearableManager().connectToSystemDevices().then((wearables) {
      if (!mounted) return;
      final provider = Provider.of<WearablesProvider>(context, listen: false);
      final sensorRecorderProvider =
          Provider.of<SensorRecorderProvider>(context, listen: false);
      for (var wearable in wearables) {
        provider.addWearable(wearable);
        sensorRecorderProvider.addWearable(wearable);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<WearablesProvider>(
      builder: (context, wearablesProvider, child) {
        return LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < 600) {
              return _buildSmallScreenLayout(context, wearablesProvider);
            } else {
              return _buildLargeScreenLayout(context, wearablesProvider);
            }
          },
        );
      },
    );
  }

  Widget _buildSmallScreenLayout(BuildContext context, WearablesProvider wearablesProvider) {
    return PlatformScaffold(
      appBar: PlatformAppBar(
        title: PlatformText("Devices"),
        trailingActions: [
            PlatformIconButton(
            icon: Icon(context.platformIcons.bluetooth),
            onPressed: () {
              Navigator.of(context).push(
                platformPageRoute(
                  context: context,
                  builder: (context) => const ConnectDevicesPage(),
                ),
              );
            },
          ),
        ],
      ),
      body: _buildSmallScreenContent(context, wearablesProvider),
    );
  }

  Widget _buildSmallScreenContent(BuildContext context, WearablesProvider wearablesProvider) {
    if (wearablesProvider.wearables.isEmpty) {
      return RefreshIndicator(
        onRefresh: () async {
          await _startBluetooth();
        },
        child: ListView(
          children: [
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.8,
              child: Center(
                child: PlatformText(
                  "No devices connected",
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () {
        return WearableManager().connectToSystemDevices().then((wearables) {
          for (var wearable in wearables) {
            wearablesProvider.addWearable(wearable);
          }
        });
      },
      child: Padding(
        padding: EdgeInsets.all(10),
        child: ListView.builder(
          itemCount: wearablesProvider.wearables.length,
          itemBuilder: (context, index) {
            return DeviceRow(device: wearablesProvider.wearables[index]);
          },
        ),
      ),
    );
  }

  Widget _buildLargeScreenLayout(
    BuildContext context,
    WearablesProvider wearablesProvider,
  ) {
    return GridView.builder(
      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 500,
        childAspectRatio: 3,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      itemCount: wearablesProvider.wearables.length + 1,
      itemBuilder: (context, index) {
        if (index == wearablesProvider.wearables.length) {
          return GestureDetector(
            onTap: () {
              showPlatformModalSheet(
                context: context,
                builder: (context) => ConnectDevicesPage(),
              );
            },
            child: Card(
              color: Theme.of(context)
                  .colorScheme
                  .surfaceTint
                  .withValues(alpha: 0.2),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      PlatformIcons(context).add,
                      color: Theme.of(context).colorScheme.surfaceTint,
                    ),
                    PlatformText(
                      "Connect Device",
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: Theme.of(context).colorScheme.surfaceTint,
                          ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
        return DeviceRow(device: wearablesProvider.wearables[index]);
      },
    );
  }
}


// MARK: DeviceRow

/// This widget represents a single device in the list/grid.
/// Tapping on it will navigate to the [DeviceDetailPage].
class DeviceRow extends StatelessWidget {
  final Wearable _device;

  const DeviceRow({super.key, required Wearable device}) : _device = device;

  @override
  Widget build(BuildContext context) {
    String? wearableIconPath = _device.getWearableIconPath();

    return GestureDetector(
      onTap: () {
        bool isLargeScreen = MediaQuery.of(context).size.width > 600;
        if (isLargeScreen) {
          showGeneralDialog(
            context: context,
            pageBuilder: (context, animation1, animation2) {
              return Center(
                child: SizedBox(
                  width: MediaQuery.of(context).size.width * 0.5,
                  height: MediaQuery.of(context).size.height * 0.5,
                  child: DeviceDetailPage(device: _device),
                ),
              );
            },
          );
          return;
        }
        Navigator.of(context).push(
          platformPageRoute(
            context: context,
            builder: (context) => DeviceDetailPage(device: _device),
          ),
        );
      },
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(10.0),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (wearableIconPath != null)
                    SvgPicture.asset(
                      wearableIconPath,
                      width: 50,
                      height: 50,
                    ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      PlatformText(
                        _device.name,
                        style: Theme.of(context)
                            .textTheme
                            .bodyLarge
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      Row(children: [
                        BatteryStateView(device: _device),
                        if (_device is StereoDevice)
                          Padding(
                            padding: EdgeInsets.only(left: 8.0),
                            child: StereoPosLabel(device: _device as StereoDevice),
                          ),
                      ],
                    ),
                  ],
                ),
                Spacer(),
                if (_device is DeviceIdentifier)
                    FutureBuilder(
                      future:
                          (_device as DeviceIdentifier).readDeviceIdentifier(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return PlatformCircularProgressIndicator();
                        }
                        if (snapshot.hasError) {
                          return PlatformText("Error: ${snapshot.error}");
                        }
                        return PlatformText(snapshot.data.toString());
                      },
                    )
                  else
                    PlatformText(_device.deviceId),
                ],
              ),
              if (_device is DeviceFirmwareVersion)
                Row(
                  children: [
                    PlatformText("Firmware Version: "),
                    FutureBuilder(
                      future: (_device as DeviceFirmwareVersion)
                          .readDeviceFirmwareVersion(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return PlatformCircularProgressIndicator();
                        }
                        if (snapshot.hasError) {
                          return PlatformText("Error: ${snapshot.error}");
                        }
                        return PlatformText(snapshot.data.toString());
                      },
                    ),
                  ],
                ),
              if (_device is DeviceHardwareVersion)
                Row(
                  children: [
                    PlatformText("Hardware Version: "),
                    FutureBuilder(
                      future: (_device as DeviceHardwareVersion)
                          .readDeviceHardwareVersion(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return PlatformCircularProgressIndicator();
                        }
                        if (snapshot.hasError) {
                          return PlatformText("Error: ${snapshot.error}");
                        }
                        return PlatformText(snapshot.data.toString());
                      },
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
