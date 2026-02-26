import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart';
import 'package:open_wearable/models/auto_connect_preferences.dart';
import 'package:open_wearable/models/device_name_formatter.dart';
import 'package:open_wearable/models/wearable_status_cache.dart';
import 'package:open_wearable/view_models/wearables_provider.dart';
import 'package:open_wearable/widgets/app_toast.dart';
import 'package:open_wearable/widgets/common/app_section_card.dart';
import 'package:open_wearable/widgets/devices/device_detail/audio_mode_widget.dart';
import 'package:open_wearable/widgets/devices/device_detail/device_detail_shared_widgets.dart';
import 'package:open_wearable/widgets/devices/device_status_pills.dart';
import 'package:open_wearable/widgets/devices/wearable_icon.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  static const MethodChannel _systemSettingsChannel = MethodChannel(
    'edu.kit.teco.open_wearable/system_settings',
  );

  Future<Object?>? _deviceIdentifierFuture;
  Future<Object?>? _firmwareVersionFuture;
  Future<FirmwareSupportStatus>? _firmwareSupportFuture;
  Future<Object?>? _hardwareVersionFuture;

  @override
  void initState() {
    super.initState();
    _prepareAsyncData();
  }

  @override
  void didUpdateWidget(covariant DeviceDetailPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.device != widget.device) {
      _prepareAsyncData();
    }
  }

  void _prepareAsyncData() {
    _deviceIdentifierFuture = widget.device.hasCapability<DeviceIdentifier>()
        ? widget.device
            .requireCapability<DeviceIdentifier>()
            .readDeviceIdentifier()
        : null;

    final statusCache = WearableStatusCache.instance;
    _firmwareVersionFuture = statusCache.ensureFirmwareVersion(widget.device);
    _firmwareSupportFuture = statusCache.ensureFirmwareSupport(widget.device);
    _hardwareVersionFuture = statusCache.ensureHardwareVersion(widget.device);
  }

  bool get _canForgetDevice {
    return widget.device.hasCapability<SystemDevice>() &&
        widget.device.requireCapability<SystemDevice>().isConnectedViaSystem;
  }

  bool get _opensBluetoothScreenDirectly {
    return defaultTargetPlatform == TargetPlatform.android;
  }

  Future<void> _openBluetoothSettings() async {
    bool opened = false;
    try {
      opened = await _systemSettingsChannel.invokeMethod<bool>(
            'openBluetoothSettings',
          ) ??
          false;
    } catch (_) {
      opened = false;
    }

    if (!mounted || opened) {
      return;
    }

    AppToast.show(
      context,
      message: _opensBluetoothScreenDirectly
          ? 'Could not open Bluetooth settings.'
          : 'Could not open Settings.',
      type: AppToastType.error,
      icon: Icons.bluetooth_disabled_rounded,
    );
  }

  void _showForgetDialog() {
    showPlatformDialog(
      context: context,
      builder: (_) => PlatformAlertDialog(
        title: const Text('Forget device'),
        content: const Text(
          "To forget this device, remove it from your phone's Bluetooth devices.",
        ),
        actions: <Widget>[
          PlatformDialogAction(
            child: const Text('Cancel'),
            onPressed: () => Navigator.of(context).pop(),
          ),
          PlatformDialogAction(
            cupertino: (_, __) => CupertinoDialogActionData(
              isDefaultAction: true,
            ),
            child: Text(
              _opensBluetoothScreenDirectly
                  ? 'Open Bluetooth Settings'
                  : 'Open Settings',
            ),
            onPressed: () {
              Navigator.of(context).pop();
              _openBluetoothSettings();
            },
          ),
        ],
      ),
    );
  }

  Future<void> _disconnectDevice() async {
    final navigator = Navigator.of(context);
    final shouldPop = navigator.canPop();
    final device = widget.device;
    final wearablesProvider = context.read<WearablesProvider>();

    await wearablesProvider.turnOffSensorsForDevice(device);

    try {
      final prefs = await SharedPreferences.getInstance();
      await AutoConnectPreferences.forgetDeviceName(prefs, device.name);
    } catch (_) {
      // Disconnect should continue even if preference cleanup fails.
    }

    try {
      await device.disconnect();
      if (shouldPop) {
        navigator.pop();
      }
    } catch (_) {
      if (!mounted) {
        return;
      }
      AppToast.show(
        context,
        message: 'Could not disconnect device.',
        type: AppToastType.error,
        icon: Icons.link_off_rounded,
      );
    }
  }

  void _openFirmwareUpdate() {
    Provider.of<FirmwareUpdateRequestProvider>(
      context,
      listen: false,
    ).setSelectedPeripheral(widget.device);
    context.push('/fota');
  }

  @override
  Widget build(BuildContext context) {
    final sections = <Widget>[
      _buildHeaderCard(context),
      if (widget.device.hasCapability<AudioModeManager>())
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: AudioModeWidget(
              device: widget.device,
              applyScope: AudioModeApplyScope.individualOnly,
            ),
          ),
        ),
      if (widget.device.hasCapability<MicrophoneManager>())
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: MicrophoneSelectionWidget(
              device: widget.device.requireCapability<MicrophoneManager>(),
            ),
          ),
        ),
      _buildInfoCard(context),
      if (widget.device.hasCapability<StatusLed>() &&
          widget.device.hasCapability<RgbLed>())
        AppSectionCard(
          title: 'Status LED',
          subtitle: 'Customize the status indicator behavior.',
          child: StatusLEDControlWidget(
            statusLED: widget.device.requireCapability<StatusLed>(),
            rgbLed: widget.device.requireCapability<RgbLed>(),
          ),
        )
      else if (widget.device.hasCapability<RgbLed>())
        AppSectionCard(
          title: 'RGB LED',
          subtitle: 'Set a custom color for the RGB LED.',
          child: ActionSurface(
            title: 'LED Color',
            subtitle: 'Choose the active color shown on the device.',
            trailing: RgbControlView(
              rgbLed: widget.device.requireCapability<RgbLed>(),
            ),
          ),
        ),
      if (widget.device.hasCapability<BatteryEnergyStatusService>() ||
          widget.device.hasCapability<BatteryHealthStatusService>())
        _buildBatteryCard(context),
    ];

    return PlatformScaffold(
      appBar: PlatformAppBar(
        title: const Text('Device details'),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          12,
          10,
          12,
          14 + MediaQuery.paddingOf(context).bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < sections.length; i++) ...[
              sections[i],
              if (i < sections.length - 1) const SizedBox(height: 10),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCard(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final hasWearableIcon = widget.device.getWearableIconPath() != null;

    final statusPills = buildDeviceStatusPills(
      wearable: widget.device,
      showStereoPosition: true,
      batteryLiveUpdates: true,
    );

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (hasWearableIcon)
                  SizedBox(
                    width: 56,
                    height: 56,
                    child: WearableIcon(
                      wearable: widget.device,
                      initialVariant: WearableIconVariant.single,
                      fallback: const Icon(Icons.watch_outlined),
                    ),
                  ),
                if (hasWearableIcon) const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              formatWearableDisplayName(widget.device.name),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodyLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 170),
                            child: Text(
                              widget.device.deviceId,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.right,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (statusPills.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        DevicePillLine(pills: statusPills),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _canForgetDevice
                        ? _showForgetDialog
                        : _disconnectDevice,
                    style: OutlinedButton.styleFrom(
                      backgroundColor: colorScheme.primary,
                      foregroundColor: Colors.white,
                      side: BorderSide.none,
                    ),
                    icon: const Icon(
                      Icons.bluetooth_disabled_rounded,
                      size: 18,
                    ),
                    label: const Text('Forget'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(BuildContext context) {
    final hasIdentifier = _deviceIdentifierFuture != null;
    final hasFirmware = _firmwareVersionFuture != null;
    final hasHardware = _hardwareVersionFuture != null;

    return AppSectionCard(
      title: 'Device Information',
      subtitle: 'Identifiers and software versions.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DetailInfoRow(
            label: 'Bluetooth Address',
            value: Text(widget.device.deviceId),
            showDivider: hasIdentifier || hasFirmware || hasHardware,
          ),
          if (hasIdentifier)
            DetailInfoRow(
              label: 'Device Identifier',
              value: AsyncValueText(
                future: _deviceIdentifierFuture!,
              ),
              showDivider: hasFirmware || hasHardware,
            ),
          if (hasFirmware)
            DetailInfoRow(
              label: 'Firmware Version',
              value: _buildFirmwareVersionValue(),
              trailing: FirmwareTableUpdateHint(
                onTap: _openFirmwareUpdate,
              ),
              showDivider: hasHardware,
            ),
          if (hasHardware)
            DetailInfoRow(
              label: 'Hardware Version',
              value: AsyncValueText(
                future: _hardwareVersionFuture!,
              ),
              showDivider: false,
            ),
        ],
      ),
    );
  }

  Widget _buildFirmwareVersionValue() {
    return Row(
      children: [
        Flexible(
          child: AsyncValueText(
            future: _firmwareVersionFuture!,
          ),
        ),
        if (_firmwareSupportFuture != null) ...[
          const SizedBox(width: 6),
          FirmwareSupportIndicator(
            supportFuture: _firmwareSupportFuture!,
          ),
        ],
      ],
    );
  }

  Widget _buildBatteryCard(BuildContext context) {
    final hasEnergy = widget.device.hasCapability<BatteryEnergyStatusService>();
    final hasHealth = widget.device.hasCapability<BatteryHealthStatusService>();

    return AppSectionCard(
      title: 'Battery',
      subtitle: hasEnergy && hasHealth
          ? 'Live energy and health metrics.'
          : hasEnergy
              ? 'Live electrical measurements.'
              : 'Lifecycle and thermal status.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (hasEnergy)
            _buildBatteryEnergyContent(
              showTrailingDivider: hasHealth,
            ),
          if (hasHealth) _buildBatteryHealthContent(),
        ],
      ),
    );
  }

  Widget _buildBatteryEnergyContent({
    bool showTrailingDivider = false,
  }) {
    return StreamBuilder<BatteryEnergyStatus>(
      stream: widget.device
          .requireCapability<BatteryEnergyStatusService>()
          .energyStatusStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const InlineLoading();
        }
        if (snapshot.hasError) {
          return const InlineError(
            text: 'Unable to read battery energy status.',
          );
        }
        final energyStatus = snapshot.data;
        if (energyStatus == null) {
          return const InlineHint(text: 'No battery energy data available.');
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DetailInfoRow(
              label: 'Battery Voltage',
              value: Text('${energyStatus.voltage.toStringAsFixed(1)} V'),
            ),
            DetailInfoRow(
              label: 'Charge Rate',
              value: Text('${energyStatus.chargeRate.toStringAsFixed(3)} W'),
            ),
            DetailInfoRow(
              label: 'Battery Capacity',
              value: Text(
                '${energyStatus.availableCapacity.toStringAsFixed(2)} Wh',
              ),
              showDivider: showTrailingDivider,
            ),
          ],
        );
      },
    );
  }

  Widget _buildBatteryHealthContent({
    bool showTrailingDivider = false,
  }) {
    return StreamBuilder<BatteryHealthStatus>(
      stream: widget.device
          .requireCapability<BatteryHealthStatusService>()
          .healthStatusStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const InlineLoading();
        }
        if (snapshot.hasError) {
          return const InlineError(
            text: 'Unable to read battery health status.',
          );
        }
        final healthStatus = snapshot.data;
        if (healthStatus == null) {
          return const InlineHint(text: 'No battery health data available.');
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DetailInfoRow(
              label: 'Battery Temperature',
              value: Text('${healthStatus.currentTemperature} °C'),
              showDivider: showTrailingDivider,
            ),
          ],
        );
      },
    );
  }
}
