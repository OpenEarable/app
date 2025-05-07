import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart';
import 'package:open_wearable/widgets/devices/battery_state.dart';
import 'package:open_wearable/widgets/devices/rgb_control.dart';

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
    String? wearableIconPath = widget.device.getWearableIconPath();

    return PlatformScaffold(
      appBar: PlatformAppBar(
        title: Text("Device details"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(10.0),
        child: ListView(
          children: [
            // MARK: Device name, icon and battery state
            Column(
              children: [
                Text(widget.device.name, style: Theme.of(context).textTheme.titleLarge),
                BatteryStateView(device: widget.device),
                if (wearableIconPath != null)
                  SvgPicture.asset(wearableIconPath, width: 100, height: 100),
                PlatformElevatedButton(
                  child: Text("Disconnect"),
                  onPressed: () {
                    widget.device.disconnect();
                    Navigator.of(context).pop();
                  },
                )
              ],
            ),
            Text("Device Info", style: Theme.of(context).textTheme.titleSmall),
            PlatformListTile(
              title: Text("Bluetooth Address", style: Theme.of(context).textTheme.bodyLarge),
              subtitle: Text(widget.device.deviceId),
            ),
            // MARK: Device Identifier
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
            // MARK: Device Firmware Version
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
            // MARK: Device Hardware Version
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

            // MARK: Status LED control
            if (widget.device is StatusLed)
              ...[
                Text("Control Status LED", style: Theme.of(context).textTheme.titleSmall),
                StatusLEDControlWidget(statusLED: widget.device as StatusLed, rgbLed: widget.device as RgbLed),
              ]
            else if (widget.device is RgbLed && widget.device is! StatusLed)
              ...[
                Text("Control RGB LED", style: Theme.of(context).textTheme.titleSmall),
                PlatformListTile(
                  title: Text("LED Color", style: Theme.of(context).textTheme.bodyLarge),
                  trailing: RgbControlView(rgbLed: widget.device as RgbLed),
                ),
              ],

            // MARK: Device Battery State
            if (widget.device is BatteryEnergyStatusService)
              ...[
                Text("Battery Energy Status", style: Theme.of(context).textTheme.titleSmall),
                StreamBuilder<BatteryEnergyStatus>(
                  stream: (widget.device as BatteryEnergyStatusService).energyStatusStream,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return PlatformCircularProgressIndicator();
                    } else if (snapshot.hasError) {
                      return Text("Error: ${snapshot.error}");
                    } else if (!snapshot.hasData) {
                      return Text("No data available");
                    } else {
                      final energyStatus = snapshot.data!;
                      return Column(
                        children: [
                          PlatformListTile(
                            title: Text("Battery Voltage"),
                            subtitle: Text("${energyStatus.voltage} V"),
                          ),
                          PlatformListTile(
                            title: Text("Charge Rate"),
                            subtitle: Text("${energyStatus.chargeRate} A"),
                          ),
                          PlatformListTile(
                            title: Text("Battery Capacity"),
                            subtitle: Text("${energyStatus.availableCapacity} Ah"),
                          ),
                        ],
                      );
                    }
                  },
                ),
              ],

            // MARK: Battery Health
            if (widget.device is BatteryHealthStatusService)
              ...[
                Text("Battery Health Status", style: Theme.of(context).textTheme.titleSmall),
                StreamBuilder<BatteryHealthStatus>(
                  stream: (widget.device as BatteryHealthStatusService).healthStatusStream,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return PlatformCircularProgressIndicator();
                    } else if (snapshot.hasError) {
                      return Text("Error: ${snapshot.error}");
                    } else if (!snapshot.hasData) {
                      return Text("No data available");
                    } else {
                      final healthStatus = snapshot.data!;
                      return Column(
                        children: [
                          PlatformListTile(
                            title: Text("Battery Temperature"),
                            subtitle: Text("${healthStatus.currentTemperature} °C"),
                          ),
                          PlatformListTile(
                            title: Text("Battery Cycle Count"),
                            subtitle: Text("${healthStatus.cycleCount} cycles"),
                          ),
                        ],
                      );
                    }
                  },
                ),
              ],
          ],
        ),
      ),
    );
  }
}

// MARK: - Status LED Widget
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
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_overrideColor)
            RgbControlView(rgbLed: widget.rgbLed),
          PlatformSwitch(
            value: _overrideColor,
            onChanged: (value) async {
              setState(() {
                _overrideColor = value;
              });
              widget.statusLED.showStatus(!value);
            },
          ),
        ],
      )
    );
  }
}