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
import 'stereo_pos_label.dart';

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
        title: PlatformText("Device details"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(10.0),
        child: ListView(
          children: [
            // MARK: Device name, icon and battery state
            Column(
              children: [
                PlatformText(
                  widget.device.name,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    BatteryStateView(device: widget.device),
                    if (widget.device is StereoDevice)
                      Padding(
                        padding: const EdgeInsets.only(left: 8.0),
                        child: StereoPosLabel(device: widget.device as StereoDevice),
                      ),
                  ],
                ),
                if (wearableIconPath != null)
                  SvgPicture.asset(wearableIconPath, width: 100, height: 100),
                PlatformElevatedButton(
                  child: PlatformText("Disconnect"),
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
            PlatformText("Device Info", style: Theme.of(context).textTheme.titleSmall),
            PlatformListTile(
              title: PlatformText(
                "Bluetooth Address",
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              subtitle: PlatformText(widget.device.deviceId),
            ),
            // MARK: Device Identifier
            if (widget.device is DeviceIdentifier)
              PlatformListTile(
                title: PlatformText(
                  "Device Identifier",
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                subtitle: FutureBuilder(
                  future: (widget.device as DeviceIdentifier)
                      .readDeviceIdentifier(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.done) {
                      return PlatformText(snapshot.data.toString());
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
                title: PlatformText(
                  "Firmware Version",
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                subtitle: FutureBuilder(
                  future: (widget.device as DeviceFirmwareVersion)
                      .readDeviceFirmwareVersion(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.done) {
                      return PlatformText(snapshot.data.toString());
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
                    ).setSelectedPeripheral(widget.device);
                    // Show the firmware update dialog
                    // Navigate to your firmware update screen
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const FirmwareUpdateWidget(),
                      ),
                    );
                  },
                ),
              ),
            // MARK: Device Hardware Version
            if (widget.device is DeviceHardwareVersion)
              PlatformListTile(
                title: PlatformText(
                  "Hardware Version",
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                subtitle: FutureBuilder(
                  future: (widget.device as DeviceHardwareVersion)
                      .readDeviceHardwareVersion(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.done) {
                      return PlatformText(snapshot.data.toString());
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
              PlatformText(
                "Control Status LED",
                style: Theme.of(context).textTheme.titleSmall,
              ),
              StatusLEDControlWidget(
                statusLED: widget.device as StatusLed,
                rgbLed: widget.device as RgbLed,
              ),
            ] else if (widget.device is RgbLed &&
                widget.device is! StatusLed) ...[
              PlatformText(
                "Control RGB LED",
                style: Theme.of(context).textTheme.titleSmall,
              ),
              PlatformListTile(
                title: PlatformText(
                  "LED Color",
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                trailing: RgbControlView(rgbLed: widget.device as RgbLed),
              ),
            ],

            // MARK: Device Battery State
            if (widget.device is BatteryEnergyStatusService) ...[
              PlatformText(
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
                    return PlatformText("Error: ${snapshot.error}");
                  } else if (!snapshot.hasData) {
                    return PlatformText("No data available");
                  } else {
                    final energyStatus = snapshot.data!;
                    return Column(
                      children: [
                        PlatformListTile(
                          title: PlatformText("Battery Voltage"),
                          subtitle: PlatformText(
                            "${energyStatus.voltage.toStringAsFixed(1)} V",
                          ),
                        ),
                        PlatformListTile(
                          title: PlatformText("Charge Rate"),
                          subtitle: PlatformText(
                            "${energyStatus.chargeRate.toStringAsFixed(3)} W",
                          ),
                        ),
                        PlatformListTile(
                          title: PlatformText("Battery Capacity"),
                          subtitle: PlatformText(
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
              PlatformText(
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
                    return PlatformText("Error: ${snapshot.error}");
                  } else if (!snapshot.hasData) {
                    return PlatformText("No data available");
                  } else {
                    final healthStatus = snapshot.data!;
                    return Column(
                      children: [
                        PlatformListTile(
                          title: PlatformText("Battery Temperature"),
                          subtitle:
                              PlatformText("${healthStatus.currentTemperature} °C"),
                        ),
                        PlatformListTile(
                          title: PlatformText("Battery Cycle Count"),
                          subtitle: PlatformText("${healthStatus.cycleCount} cycles"),
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
