import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';

import 'package:open_earable_flutter/open_earable_flutter.dart';
import 'package:open_wearable/view_models/wearables_provider.dart';
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
        return Padding(
          padding: EdgeInsets.all(10),
          child: ListView.builder(
            itemCount: wearablesProvider.wearables.length,
            itemBuilder: (context, index) {
              return DeviceRow(device: wearablesProvider.wearables[index]);
            },
          )
        );
      },
    );
  }
}

class DeviceRow extends StatelessWidget {
  final Wearable _device;

  const DeviceRow({super.key, required Wearable device}): _device = device;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
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
                  Text(_device.name, style: Theme.of(context).textTheme.bodyLarge,),
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
