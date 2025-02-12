import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:open_earable_flutter/open_earable_flutter.dart';
import 'package:open_wearable/view_models/wearables_provider.dart';
import 'package:open_wearable/widgets/devices/battery_state.dart';
import 'package:open_wearable/widgets/devices/connect_devices_page.dart';
import 'package:open_wearable/widgets/devices/device_detail_page.dart';
import 'package:provider/provider.dart';

/// On this page the user can see all connected devices.
/// 
/// Tapping on a device will navigate to the [DeviceDetailPage].
class DevicesPage extends StatelessWidget {
  const DevicesPage({super.key});

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
    if (wearablesProvider.wearables.isEmpty) {
      return Center(
        child: Text("No devices connected", style: Theme.of(context).textTheme.titleLarge),
      );
    }

    return Padding(
      padding: EdgeInsets.all(10),
      child: ListView.builder(
        itemCount: wearablesProvider.wearables.length,
        itemBuilder: (context, index) {
          return DeviceRow(device: wearablesProvider.wearables[index]);
        },
      ),
    );
  }

  Widget _buildLargeScreenLayout(BuildContext context, WearablesProvider wearablesProvider) {
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
              color: Theme.of(context).colorScheme.surfaceTint.withValues(alpha: 0.2),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(PlatformIcons(context).add, color: Theme.of(context).colorScheme.surfaceTint),
                    Text(
                      "Connect Device",
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Theme.of(context).colorScheme.surfaceTint),
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

class DeviceRow extends StatelessWidget {
  final Wearable _device;

  const DeviceRow({super.key, required Wearable device}): _device = device;

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
                        Text(
                          _device.name,
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        BatteryStateView(device: _device)
                      ],
                    ),
                  Spacer(),
                  if (_device is DeviceIdentifier)
                    FutureBuilder(
                      future: (_device as DeviceIdentifier).readDeviceIdentifier(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return PlatformCircularProgressIndicator();
                        }
                        if (snapshot.hasError) {
                          return Text("Error: ${snapshot.error}");
                        }
                        return Text(snapshot.data.toString());
                      },
                    )
                  else Text(_device.deviceId),
                ],
              ),
              if (_device is DeviceFirmwareVersion)
                Row(
                  children: [
                    Text("Firmware Version: "),
                    FutureBuilder(
                      future: (_device as DeviceFirmwareVersion).readDeviceFirmwareVersion(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return PlatformCircularProgressIndicator();
                        }
                        if (snapshot.hasError) {
                          return Text("Error: ${snapshot.error}");
                        }
                        return Text(snapshot.data.toString());
                      },
                    ),
                  ],
                ),
              if (_device is DeviceHardwareVersion)
                Row(
                  children: [
                    Text("Hardware Version: "),
                    FutureBuilder(
                      future: (_device as DeviceHardwareVersion).readDeviceHardwareVersion(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return PlatformCircularProgressIndicator();
                        }
                        if (snapshot.hasError) {
                          return Text("Error: ${snapshot.error}");
                        }
                        return Text(snapshot.data.toString());
                      },
                    ),
                  ],
                ),
            ],
          )
        )
      )
    );
  }
}
