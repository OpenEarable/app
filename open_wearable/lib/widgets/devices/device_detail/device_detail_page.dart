import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart';
import 'package:open_wearable/models/auto_connect_preferences.dart';
import 'package:open_wearable/models/device_name_formatter.dart';
import 'package:open_wearable/models/wearable_status_cache.dart';
import 'package:open_wearable/widgets/app_toast.dart';
import 'package:open_wearable/widgets/devices/device_detail/audio_mode_widget.dart';
import 'package:open_wearable/widgets/devices/device_status_pills.dart';
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
        content: Text(
          _opensBluetoothScreenDirectly
              ? 'To fully forget this device, remove it in your phone Bluetooth settings. '
                  'You can open Bluetooth settings directly from here.'
              : 'To fully forget this device, remove it in your phone Bluetooth settings. '
                  'You can open Settings from here.',
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

    try {
      final prefs = await SharedPreferences.getInstance();
      await AutoConnectPreferences.forgetDeviceName(prefs, device.name);
    } catch (_) {
      // Disconnect should continue even if preference cleanup fails.
    }

    device.disconnect();
    if (shouldPop) {
      navigator.pop();
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
        _SectionCard(
          title: 'Status LED',
          subtitle: 'Customize the status indicator behavior.',
          child: StatusLEDControlWidget(
            statusLED: widget.device.requireCapability<StatusLed>(),
            rgbLed: widget.device.requireCapability<RgbLed>(),
          ),
        )
      else if (widget.device.hasCapability<RgbLed>())
        _SectionCard(
          title: 'RGB LED',
          subtitle: 'Set a custom color for the RGB LED.',
          child: _ActionSurface(
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
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
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
                    child: _DeviceHeaderWearableIcon(device: widget.device),
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
                if (_canForgetDevice) ...[
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _showForgetDialog,
                      icon: const Icon(
                        Icons.bluetooth_disabled_rounded,
                        size: 18,
                      ),
                      label: const Text('Forget'),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _disconnectDevice,
                    icon: const Icon(Icons.link_off_rounded, size: 18),
                    label: const Text('Disconnect'),
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

    return _SectionCard(
      title: 'Device Information',
      subtitle: 'Identifiers and software versions.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _DetailInfoRow(
            label: 'Bluetooth Address',
            value: Text(widget.device.deviceId),
            showDivider: hasIdentifier || hasFirmware || hasHardware,
          ),
          if (hasIdentifier)
            _DetailInfoRow(
              label: 'Device Identifier',
              value: _AsyncValueText(
                future: _deviceIdentifierFuture!,
              ),
              showDivider: hasFirmware || hasHardware,
            ),
          if (hasFirmware)
            _DetailInfoRow(
              label: 'Firmware Version',
              value: _buildFirmwareVersionValue(),
              trailing: _FirmwareTableUpdateHint(
                onTap: _openFirmwareUpdate,
              ),
              showDivider: hasHardware,
            ),
          if (hasHardware)
            _DetailInfoRow(
              label: 'Hardware Version',
              value: _AsyncValueText(
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
          child: _AsyncValueText(
            future: _firmwareVersionFuture!,
          ),
        ),
        if (_firmwareSupportFuture != null) ...[
          const SizedBox(width: 6),
          _FirmwareSupportIndicator(
            supportFuture: _firmwareSupportFuture!,
          ),
        ],
      ],
    );
  }

  Widget _buildBatteryCard(BuildContext context) {
    final hasEnergy = widget.device.hasCapability<BatteryEnergyStatusService>();
    final hasHealth = widget.device.hasCapability<BatteryHealthStatusService>();

    return _SectionCard(
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
          return const _InlineLoading();
        }
        if (snapshot.hasError) {
          return const _InlineError(
            text: 'Unable to read battery energy status.',
          );
        }
        final energyStatus = snapshot.data;
        if (energyStatus == null) {
          return const _InlineHint(text: 'No battery energy data available.');
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _DetailInfoRow(
              label: 'Battery Voltage',
              value: Text('${energyStatus.voltage.toStringAsFixed(1)} V'),
            ),
            _DetailInfoRow(
              label: 'Charge Rate',
              value: Text('${energyStatus.chargeRate.toStringAsFixed(3)} W'),
            ),
            _DetailInfoRow(
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
          return const _InlineLoading();
        }
        if (snapshot.hasError) {
          return const _InlineError(
            text: 'Unable to read battery health status.',
          );
        }
        final healthStatus = snapshot.data;
        if (healthStatus == null) {
          return const _InlineHint(text: 'No battery health data available.');
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _DetailInfoRow(
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

class _DeviceHeaderWearableIcon extends StatefulWidget {
  final Wearable device;

  const _DeviceHeaderWearableIcon({required this.device});

  @override
  State<_DeviceHeaderWearableIcon> createState() =>
      _DeviceHeaderWearableIconState();
}

class _DeviceHeaderWearableIconState extends State<_DeviceHeaderWearableIcon> {
  static final Expando<Future<DevicePosition?>> _positionFutureCache =
      Expando<Future<DevicePosition?>>();

  Future<DevicePosition?>? _positionFuture;

  @override
  void initState() {
    super.initState();
    _configurePositionFuture();
  }

  @override
  void didUpdateWidget(covariant _DeviceHeaderWearableIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.device, widget.device)) {
      _configurePositionFuture();
    }
  }

  void _configurePositionFuture() {
    if (!widget.device.hasCapability<StereoDevice>()) {
      _positionFuture = null;
      return;
    }

    final stereoDevice = widget.device.requireCapability<StereoDevice>();
    _positionFuture =
        _positionFutureCache[stereoDevice] ??= stereoDevice.position;
  }

  WearableIconVariant _variantForPosition(DevicePosition? position) {
    return switch (position) {
      DevicePosition.left => WearableIconVariant.left,
      DevicePosition.right => WearableIconVariant.right,
      _ => WearableIconVariant.single,
    };
  }

  String? _resolveIconPath(WearableIconVariant variant) {
    final variantPath = widget.device.getWearableIconPath(variant: variant);
    if (variantPath != null && variantPath.isNotEmpty) {
      return variantPath;
    }

    if (variant != WearableIconVariant.single) {
      final fallbackPath = widget.device.getWearableIconPath();
      if (fallbackPath != null && fallbackPath.isNotEmpty) {
        return fallbackPath;
      }
    }

    return null;
  }

  Widget _buildIcon(WearableIconVariant variant) {
    final iconPath = _resolveIconPath(variant);
    if (iconPath == null) {
      return const SizedBox.shrink();
    }

    if (iconPath.toLowerCase().endsWith('.svg')) {
      return SvgPicture.asset(iconPath, fit: BoxFit.contain);
    }

    return Image.asset(
      iconPath,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => const Icon(Icons.watch_outlined),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_positionFuture == null) {
      return _buildIcon(WearableIconVariant.single);
    }

    return FutureBuilder<DevicePosition?>(
      future: _positionFuture,
      builder: (context, snapshot) {
        return _buildIcon(_variantForPosition(snapshot.data));
      },
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;

  const _SectionCard({
    required this.title,
    this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }
}

class _ActionSurface extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget trailing;

  const _ActionSurface({
    required this.title,
    required this.subtitle,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.55),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          trailing,
        ],
      ),
    );
  }
}

class _DetailInfoRow extends StatelessWidget {
  final String label;
  final Widget value;
  final Widget? trailing;
  final bool showDivider;

  const _DetailInfoRow({
    required this.label,
    required this.value,
    this.trailing,
    this.showDivider = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    DefaultTextStyle(
                      style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ) ??
                          const TextStyle(),
                      child: value,
                    ),
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 10),
                trailing!,
              ],
            ],
          ),
          if (showDivider) ...[
            const SizedBox(height: 8),
            Divider(
              height: 1,
              color: colorScheme.outlineVariant.withValues(alpha: 0.55),
            ),
          ],
        ],
      ),
    );
  }
}

class _AsyncValueText extends StatelessWidget {
  final Future<Object?> future;

  const _AsyncValueText({
    required this.future,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return FutureBuilder<Object?>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: colorScheme.primary,
            ),
          );
        }

        final valueText =
            snapshot.hasError ? '--' : (snapshot.data?.toString() ?? '--');
        return Text(
          valueText,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        );
      },
    );
  }
}

class _InlineLoading extends StatelessWidget {
  const _InlineLoading();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: SizedBox(
        width: 22,
        height: 22,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: colorScheme.primary,
        ),
      ),
    );
  }
}

class _InlineHint extends StatelessWidget {
  final String text;

  const _InlineHint({required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
    );
  }
}

class _InlineError extends StatelessWidget {
  final String text;

  const _InlineError({required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.error,
            fontWeight: FontWeight.w600,
          ),
    );
  }
}

class _FirmwareTableUpdateHint extends StatelessWidget {
  final VoidCallback onTap;

  const _FirmwareTableUpdateHint({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return FilledButton.icon(
      onPressed: onTap,
      style: FilledButton.styleFrom(
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        minimumSize: const Size(0, 34),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        backgroundColor: colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      icon: Icon(
        Icons.system_update_alt_rounded,
        size: 15,
        color: Colors.white,
      ),
      label: Text(
        'Update',
        style: theme.textTheme.labelSmall?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _FirmwareSupportIndicator extends StatelessWidget {
  final Future<FirmwareSupportStatus> supportFuture;

  const _FirmwareSupportIndicator({required this.supportFuture});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<FirmwareSupportStatus>(
      future: supportFuture,
      builder: (context, snapshot) {
        final support = snapshot.data;
        if (support == null || support == FirmwareSupportStatus.supported) {
          return const SizedBox.shrink();
        }

        final colorScheme = Theme.of(context).colorScheme;

        IconData icon = Icons.help_rounded;
        Color color = colorScheme.onSurfaceVariant;
        String tooltip = 'Firmware support status is unknown';

        switch (support) {
          case FirmwareSupportStatus.tooOld:
            icon = Icons.warning_rounded;
            color = Colors.orange;
            tooltip = 'Firmware is too old';
            break;
          case FirmwareSupportStatus.tooNew:
            icon = Icons.warning_rounded;
            color = Colors.orange;
            tooltip = 'Firmware is newer than supported';
            break;
          case FirmwareSupportStatus.unknown:
            icon = Icons.help_rounded;
            color = colorScheme.onSurfaceVariant;
            tooltip = 'Firmware support is unknown';
            break;
          case FirmwareSupportStatus.unsupported:
            icon = Icons.error_outline_rounded;
            color = colorScheme.error;
            tooltip = 'Firmware is unsupported';
            break;
          case FirmwareSupportStatus.supported:
            return const SizedBox.shrink();
        }

        return Tooltip(
          message: tooltip,
          child: Icon(
            icon,
            size: 16,
            color: color,
          ),
        );
      },
    );
  }
}
