import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart';
import 'package:open_wearable/widgets/devices/battery_state.dart';
import 'package:open_wearable/widgets/devices/device_detail/audio_mode_widget.dart';
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

    if (widget.device.hasCapability<DeviceFirmwareVersion>()) {
      final firmware = widget.device.requireCapability<DeviceFirmwareVersion>();
      _firmwareVersionFuture = firmware.readDeviceFirmwareVersion();
      _firmwareSupportFuture = firmware.checkFirmwareSupport();
    } else {
      _firmwareVersionFuture = null;
      _firmwareSupportFuture = null;
    }

    _hardwareVersionFuture =
        widget.device.hasCapability<DeviceHardwareVersion>()
            ? widget.device
                .requireCapability<DeviceHardwareVersion>()
                .readDeviceHardwareVersion()
            : null;
  }

  bool get _canForgetDevice {
    return widget.device.hasCapability<SystemDevice>() &&
        widget.device.requireCapability<SystemDevice>().isConnectedViaSystem;
  }

  void _showForgetDialog() {
    showPlatformDialog(
      context: context,
      builder: (_) => PlatformAlertDialog(
        title: const Text('Forget device'),
        content: const Text(
          'To disconnect this device permanently, remove it from your system Bluetooth settings.',
        ),
        actions: <Widget>[
          PlatformDialogAction(
            cupertino: (_, __) => CupertinoDialogActionData(
              isDefaultAction: true,
            ),
            child: const Text('OK'),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  void _disconnectDevice() {
    widget.device.disconnect();
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
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
    final wearableIconPath = widget.device.getWearableIconPath();

    final statusPills = <Widget>[
      if (widget.device.hasCapability<BatteryLevelStatus>() ||
          widget.device.hasCapability<BatteryLevelStatusService>())
        BatteryStateView(device: widget.device),
      if (widget.device.hasCapability<StereoDevice>())
        StereoPosLabel(
          device: widget.device.requireCapability<StereoDevice>(),
        ),
      if (_firmwareVersionFuture != null)
        _FirmwareMetadataBubble(
          versionFuture: _firmwareVersionFuture!,
          supportFuture: _firmwareSupportFuture,
        ),
      if (_hardwareVersionFuture != null)
        _HardwareMetadataBubble(
          versionFuture: _hardwareVersionFuture!,
        ),
    ];

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
                if (wearableIconPath != null)
                  SizedBox(
                    width: 56,
                    height: 56,
                    child:
                        SvgPicture.asset(wearableIconPath, fit: BoxFit.contain),
                  ),
                if (wearableIconPath != null) const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              widget.device.name,
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
                        _buildHeaderPillLine(statusPills),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            if (_firmwareVersionFuture != null) ...[
              const SizedBox(height: 10),
              _FirmwareUpdateCallout(
                versionFuture: _firmwareVersionFuture!,
                supportFuture: _firmwareSupportFuture,
                onTap: _openFirmwareUpdate,
              ),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (_canForgetDevice)
                  OutlinedButton.icon(
                    onPressed: _showForgetDialog,
                    icon:
                        const Icon(Icons.bluetooth_disabled_rounded, size: 18),
                    label: const Text('Forget'),
                  ),
                FilledButton.icon(
                  onPressed: _disconnectDevice,
                  icon: const Icon(Icons.link_off_rounded, size: 18),
                  label: const Text('Disconnect'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderPillLine(List<Widget> pills) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: BoxConstraints(minWidth: constraints.maxWidth),
          child: Row(
            children: [
              for (var i = 0; i < pills.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                pills[i],
              ],
            ],
          ),
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

class _FirmwareUpdateCallout extends StatelessWidget {
  final Future<Object?> versionFuture;
  final Future<FirmwareSupportStatus>? supportFuture;
  final VoidCallback onTap;

  const _FirmwareUpdateCallout({
    required this.versionFuture,
    required this.supportFuture,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(10, 9, 10, 10),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.24),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: colorScheme.primary.withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.system_update_alt_rounded,
                size: 16,
                color: colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Firmware updater',
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          FutureBuilder<Object?>(
            future: versionFuture,
            builder: (context, versionSnapshot) {
              final versionText =
                  versionSnapshot.connectionState == ConnectionState.waiting
                      ? 'Version ...'
                      : versionSnapshot.hasError
                          ? 'Version unavailable'
                          : 'Version ${versionSnapshot.data ?? '--'}';

              if (supportFuture == null) {
                return Text(
                  '$versionText • Open updater to install firmware.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                );
              }

              return FutureBuilder<FirmwareSupportStatus>(
                future: supportFuture,
                builder: (context, supportSnapshot) {
                  final statusText = switch (supportSnapshot.data) {
                    FirmwareSupportStatus.tooOld => 'Update recommended.',
                    FirmwareSupportStatus.tooNew => 'Newer than app support.',
                    FirmwareSupportStatus.unsupported =>
                      'Firmware unsupported.',
                    _ => 'Open updater to install firmware.',
                  };
                  return Text(
                    '$versionText • $statusText',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  );
                },
              );
            },
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: onTap,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                minimumSize: const Size(0, 34),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              icon: const Icon(Icons.open_in_new_rounded, size: 16),
              label: const Text('Open updater'),
            ),
          ),
        ],
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

    return OutlinedButton.icon(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        minimumSize: const Size(0, 34),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        side: BorderSide(
          color: colorScheme.primary.withValues(alpha: 0.5),
        ),
      ),
      icon: Icon(
        Icons.system_update_alt_rounded,
        size: 15,
        color: colorScheme.primary,
      ),
      label: Text(
        'Update',
        style: theme.textTheme.labelSmall?.copyWith(
          color: colorScheme.primary,
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

class _FirmwareMetadataBubble extends StatelessWidget {
  final Future<Object?> versionFuture;
  final Future<FirmwareSupportStatus>? supportFuture;

  const _FirmwareMetadataBubble({
    required this.versionFuture,
    required this.supportFuture,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Object?>(
      future: versionFuture,
      builder: (context, versionSnapshot) {
        if (versionSnapshot.connectionState == ConnectionState.waiting) {
          return const _MetadataBubble(label: 'FW', isLoading: true);
        }

        final versionText = versionSnapshot.hasError
            ? '--'
            : (versionSnapshot.data?.toString() ?? '--');

        if (supportFuture == null) {
          return _MetadataBubble(
            label: 'FW',
            value: versionText,
          );
        }

        return FutureBuilder<FirmwareSupportStatus>(
          future: supportFuture,
          builder: (context, supportSnapshot) {
            IconData? statusIcon;
            Color? statusColor;

            switch (supportSnapshot.data) {
              case FirmwareSupportStatus.tooOld:
              case FirmwareSupportStatus.tooNew:
                statusIcon = Icons.warning_rounded;
                statusColor = Colors.orange;
                break;
              case FirmwareSupportStatus.unknown:
                statusIcon = Icons.help_rounded;
                statusColor = Theme.of(context).colorScheme.onSurfaceVariant;
                break;
              default:
                break;
            }

            return _MetadataBubble(
              label: 'FW',
              value: versionText,
              trailingIcon: statusIcon,
              foregroundColor: statusColor,
            );
          },
        );
      },
    );
  }
}

class _HardwareMetadataBubble extends StatelessWidget {
  final Future<Object?> versionFuture;

  const _HardwareMetadataBubble({required this.versionFuture});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Object?>(
      future: versionFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _MetadataBubble(label: 'HW', isLoading: true);
        }

        final versionText =
            snapshot.hasError ? '--' : (snapshot.data?.toString() ?? '--');

        return _MetadataBubble(
          label: 'HW',
          value: versionText,
        );
      },
    );
  }
}

class _MetadataBubble extends StatelessWidget {
  final String label;
  final String? value;
  final bool isLoading;
  final IconData? trailingIcon;
  final Color? foregroundColor;

  const _MetadataBubble({
    required this.label,
    this.value,
    this.isLoading = false,
    this.trailingIcon,
    this.foregroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final defaultForeground = Theme.of(context).colorScheme.primary;
    final resolvedForeground = foregroundColor ?? defaultForeground;
    final backgroundColor = resolvedForeground.withValues(alpha: 0.12);
    final borderColor = resolvedForeground.withValues(alpha: 0.24);
    final displayText =
        isLoading ? '$label ...' : (value == null ? label : '$label $value');

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!isLoading && trailingIcon != null)
            Icon(
              trailingIcon,
              size: 14,
              color: resolvedForeground,
            ),
          if (!isLoading && trailingIcon != null) const SizedBox(width: 6),
          Text(
            displayText,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: resolvedForeground,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.1,
                ),
          ),
        ],
      ),
    );
  }
}
