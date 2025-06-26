import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart';
import 'package:open_wearable/widgets/devices/battery_state.dart';
import 'package:open_wearable/widgets/devices/device_detail/audio_mode_widget.dart';
import 'package:open_wearable/widgets/fota/firmware_update.dart';
import 'package:provider/provider.dart';

import 'rgb_control.dart';
import 'microphone_selection_widget.dart';
import 'status_led_widget.dart';

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
  Microphone? selectedMicrophone;

  @override
  void initState() {
    super.initState();
    _initSelectedMicrophone();
  }

  Future<void> _initSelectedMicrophone() async {
    if (widget.device is MicrophoneManager) {
      final mic = await (widget.device as MicrophoneManager).getMicrophone();
      setState(() {
        selectedMicrophone = mic;
      });
    }
  }

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
                Text(
                  widget.device.name,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                BatteryStateView(device: widget.device),
                if (wearableIconPath != null)
                  SvgPicture.asset(wearableIconPath, width: 100, height: 100),
                PlatformElevatedButton(
                  child: Text("Disconnect"),
                  onPressed: () {
                    widget.device.disconnect();
                    Navigator.of(context).pop();
                  },
                ),
              ],
            ),
            // MARK: Audio Mode
            if (widget.device is AudioModeManager)
              AudioModeWidget(device: widget.device as AudioModeManager),
            // MARK: Microphone Control
            if (widget.device is MicrophoneManager)
              MicrophoneSelectionWidget(
                device: widget.device as MicrophoneManager,
              ),
            // MARK: Device info
            Text("Device Info", style: Theme.of(context).textTheme.titleSmall),
            PlatformListTile(
              title: Text(
                "Bluetooth Address",
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              subtitle: Text(widget.device.deviceId),
            ),
            // MARK: Device Identifier
            if (widget.device is DeviceIdentifier)
              PlatformListTile(
                title: Text(
                  "Device Identifier",
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                subtitle: FutureBuilder(
                  future: (widget.device as DeviceIdentifier)
                      .readDeviceIdentifier(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.done) {
                      return Text(snapshot.data.toString());
                    } else {
                      return Align(
                        alignment: Alignment.centerLeft,
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: PlatformCircularProgressIndicator(),
                        ),
                      );
                    }
                  },
                ),
              ),
            // MARK: Device Firmware Version
            if (widget.device is DeviceFirmwareVersion)
              PlatformListTile(
                title: Text(
                  "Firmware Version",
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                subtitle: FutureBuilder(
                  future: (widget.device as DeviceFirmwareVersion)
                      .readDeviceFirmwareVersion(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.done) {
                      return Text(snapshot.data.toString());
                    } else {
                      return Align(
                        alignment: Alignment.centerLeft,
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: PlatformCircularProgressIndicator(),
                        ),
                      );
                    }
                  },
                ),
                trailing: PlatformIconButton(
                  icon: Icon(Icons.upload),
                  onPressed: () {
                    Provider.of<FirmwareUpdateRequestProvider>(
                      context,
                      listen: false,
                    ).setPeripheral(
                      SelectedPeripheral(
                        name: widget.device.name,
                        identifier: widget.device.deviceId,
                      ),
                    );
                    // Show the firmware update dialog
                    // Navigate to your firmware update screen
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => PlatformScaffold(
                          appBar: PlatformAppBar(
                            title: Text("Update Firmware"),
                          ),
                          body: Material(child: FirmwareUpdateWidget()),
                        ),
                      ),
                    );
                  },
                ),
              ),
            // MARK: Device Hardware Version
            if (widget.device is DeviceHardwareVersion)
              PlatformListTile(
                title: Text(
                  "Hardware Version",
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                subtitle: FutureBuilder(
                  future: (widget.device as DeviceHardwareVersion)
                      .readDeviceHardwareVersion(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.done) {
                      return Text(snapshot.data.toString());
                    } else {
                      return Align(
                        alignment: Alignment.centerLeft,
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: PlatformCircularProgressIndicator(),
                        ),
                      );
                    }
                  },
                ),
              ),

            // MARK: Status LED control
            if (widget.device is StatusLed) ...[
              Text(
                "Control Status LED",
                style: Theme.of(context).textTheme.titleSmall,
              ),
              StatusLEDControlWidget(
                statusLED: widget.device as StatusLed,
                rgbLed: widget.device as RgbLed,
              ),
            ] else if (widget.device is RgbLed &&
                widget.device is! StatusLed) ...[
              Text(
                "Control RGB LED",
                style: Theme.of(context).textTheme.titleSmall,
              ),
              PlatformListTile(
                title: Text(
                  "LED Color",
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                trailing: RgbControlView(rgbLed: widget.device as RgbLed),
              ),
            ],

            // MARK: Device Battery State
            if (widget.device is BatteryEnergyStatusService) ...[
              Text(
                "Battery Energy Status",
                style: Theme.of(context).textTheme.titleSmall,
              ),
              StreamBuilder<BatteryEnergyStatus>(
                stream: (widget.device as BatteryEnergyStatusService)
                    .energyStatusStream,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Align(
                      alignment: Alignment.centerLeft,
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: PlatformCircularProgressIndicator(),
                      ),
                    );
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
                          subtitle: Text(
                            "${energyStatus.voltage.toStringAsFixed(1)} V",
                          ),
                        ),
                        PlatformListTile(
                          title: Text("Charge Rate"),
                          subtitle: Text(
                            "${energyStatus.chargeRate.toStringAsFixed(3)} W",
                          ),
                        ),
                        PlatformListTile(
                          title: Text("Battery Capacity"),
                          subtitle: Text(
                            "${energyStatus.availableCapacity.toStringAsFixed(2)} Wh",
                          ),
                        ),
                      ],
                    );
                  }
                },
              ),
            ],

            // MARK: Battery Health
            if (widget.device is BatteryHealthStatusService) ...[
              Text(
                "Battery Health Status",
                style: Theme.of(context).textTheme.titleSmall,
              ),
              StreamBuilder<BatteryHealthStatus>(
                stream: (widget.device as BatteryHealthStatusService)
                    .healthStatusStream,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Align(
                      alignment: Alignment.centerLeft,
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: PlatformCircularProgressIndicator(),
                      ),
                    );
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
                          subtitle:
                              Text("${healthStatus.currentTemperature} °C"),
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
