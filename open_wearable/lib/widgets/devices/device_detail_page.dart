import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart';

/// A page that displays the details of a device.
/// 
/// If the device has additional features, they will be displayed and configurable as well.
/// Sensors are not shown here.
class DeviceDetailPage extends StatefulWidget {
  final Wearable device;
  const DeviceDetailPage({super.key, required this.device});

  @override
  State<DeviceDetailPage> createState() => _DeviceDetailPageState();
}

class _DeviceDetailPageState extends State<DeviceDetailPage> {
  bool showStatusLED = true;

  @override
  Widget build(BuildContext context) {
    return PlatformScaffold(
      appBar: PlatformAppBar(
        title: Text(widget.device.name),
      ),
      body: Padding(
        padding: const EdgeInsets.all(10.0),
        child: ListView(
          children: [
            Text("Device Info", style: Theme.of(context).textTheme.titleSmall),
            PlatformListTile(
              title: Text("Bluetooth Address", style: Theme.of(context).textTheme.bodyLarge),
              subtitle: Text(widget.device.deviceId),
            ),
            if (widget.device is DeviceIdentifier)
              PlatformListTile(
                title: Text("Device Identifier", style: Theme.of(context).textTheme.bodyLarge),
                subtitle: FutureBuilder(
                  future: (widget.device as DeviceIdentifier).readDeviceIdentifier(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.done) {
                      return Text(snapshot.data.toString());
                    } else {
                      return PlatformCircularProgressIndicator();
                    }
                  },
                ),
              ),
            if (widget.device is DeviceFirmwareVersion)
              PlatformListTile(
                title: Text("Firmware Version", style: Theme.of(context).textTheme.bodyLarge),
                subtitle: FutureBuilder(
                  future: (widget.device as DeviceFirmwareVersion).readDeviceFirmwareVersion(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.done) {
                      return Text(snapshot.data.toString());
                    } else {
                      return PlatformCircularProgressIndicator();
                    }
                  },
                ),
              ),
            if (widget.device is DeviceHardwareVersion)
              PlatformListTile(
                title: Text("Hardware Version", style: Theme.of(context).textTheme.bodyLarge),
                subtitle: FutureBuilder(
                  future: (widget.device as DeviceHardwareVersion).readDeviceHardwareVersion(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.done) {
                      return Text(snapshot.data.toString());
                    } else {
                      return PlatformCircularProgressIndicator();
                    }
                  },
                ),
              ),
            
            if (widget.device is ExtendedBatteryService)
              ...[
                Text("Battery Info", style: Theme.of(context).textTheme.titleSmall),
                PlatformListTile(
                  title: Text("Battery Level", style: Theme.of(context).textTheme.bodyLarge),
                  subtitle: StreamBuilder(
                    stream: (widget.device as ExtendedBatteryService).batteryPercentageStream,
                    builder: (context, snapshot) {
                      if (snapshot.hasData) {
                        return Text("${snapshot.data}%");
                      } else {
                        return PlatformCircularProgressIndicator();
                      }
                    },
                  )
                )
              ],

            if (widget.device is StatusLed)
              ...[
                Text("Control Status LED", style: Theme.of(context).textTheme.titleSmall),
                StatusLEDControlWidget(statusLED: widget.device as StatusLed, rgbLed: widget.device as RgbLed),
              ],
          ],
        ),
      ),
    );
  }
}

class StatusLEDControlWidget extends StatefulWidget {
  final StatusLed statusLED;
  final RgbLed rgbLed;
  const StatusLEDControlWidget({super.key, required this.statusLED, required this.rgbLed});

  @override
  State<StatusLEDControlWidget> createState() => _StatusLEDControlWidgetState();
}

class _StatusLEDControlWidgetState extends State<StatusLEDControlWidget> {
  bool _overrideColor = false;

  @override
  Widget build(BuildContext context) {
    return PlatformListTile(
      title: Text("Override LED Color", style: Theme.of(context).textTheme.bodyLarge),
      subtitle: Text("Override the LED color to a custom color, otherwise the status of the device will be displayed."),
      trailing: PlatformSwitch(
        value: _overrideColor,
        onChanged: (value) {
          widget.statusLED.showStatus(!value);
          setState(() {
            _overrideColor = value;
          });
        },
      ),
    );
  }
}