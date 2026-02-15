import 'package:flutter/material.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart';
import 'package:open_wearable/models/wearable_status_cache.dart';
import 'package:open_wearable/widgets/devices/battery_state.dart';

List<Widget> buildDeviceStatusPills({
  required Wearable wearable,
  String? sideLabel,
  bool showStereoPosition = false,
  bool batteryLiveUpdates = true,
  bool batteryShowBackground = true,
  bool showFirmware = true,
  bool showHardware = true,
}) {
  final hasBatteryStatus = wearable.hasCapability<BatteryLevelStatus>() ||
      wearable.hasCapability<BatteryLevelStatusService>();

  return <Widget>[
    if (sideLabel != null)
      DeviceMetadataBubble(
        label: sideLabel,
        highlighted: true,
      )
    else if (showStereoPosition && wearable.hasCapability<StereoDevice>())
      DeviceStereoPositionPill(wearable: wearable),
    if (hasBatteryStatus)
      BatteryStateView(
        device: wearable,
        liveUpdates: batteryLiveUpdates,
        showBackground: batteryShowBackground,
      ),
    if (showFirmware && wearable.hasCapability<DeviceFirmwareVersion>())
      DeviceFirmwarePill(wearable: wearable),
    if (showHardware && wearable.hasCapability<DeviceHardwareVersion>())
      DeviceHardwarePill(wearable: wearable),
  ];
}

class DevicePillLine extends StatelessWidget {
  final List<Widget> pills;

  const DevicePillLine({
    super.key,
    required this.pills,
  });

  @override
  Widget build(BuildContext context) {
    if (pills.isEmpty) {
      return const SizedBox.shrink();
    }

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
}

class DeviceStereoPositionPill extends StatelessWidget {
  final Wearable wearable;
  final bool highlighted;
  final bool showUnknownLabel;

  const DeviceStereoPositionPill({
    super.key,
    required this.wearable,
    this.highlighted = true,
    this.showUnknownLabel = false,
  });

  @override
  Widget build(BuildContext context) {
    final cache = WearableStatusCache.instance;
    final future = cache.ensureStereoPosition(wearable);
    if (future == null) {
      return const SizedBox.shrink();
    }

    return FutureBuilder<DevicePosition?>(
      future: future,
      initialData: cache.cachedStereoPositionFor(wearable.deviceId),
      builder: (context, snapshot) {
        final isLoading = snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData;
        final label = _sideLabelForPosition(snapshot.data);

        if (!isLoading && label == null && !showUnknownLabel) {
          return const SizedBox.shrink();
        }

        return DeviceMetadataBubble(
          label: isLoading ? '...' : (label ?? '--'),
          highlighted: highlighted,
        );
      },
    );
  }
}

class DeviceFirmwarePill extends StatelessWidget {
  final Wearable wearable;

  const DeviceFirmwarePill({super.key, required this.wearable});

  @override
  Widget build(BuildContext context) {
    final cache = WearableStatusCache.instance;
    final versionFuture = cache.ensureFirmwareVersion(wearable);
    final supportFuture = cache.ensureFirmwareSupport(wearable);
    if (versionFuture == null) {
      return const DeviceMetadataBubble(label: 'FW', value: '--');
    }

    return FutureBuilder<Object?>(
      future: versionFuture,
      initialData: cache.cachedFirmwareVersionFor(wearable.deviceId),
      builder: (context, versionSnapshot) {
        final isLoading =
            versionSnapshot.connectionState == ConnectionState.waiting &&
                !versionSnapshot.hasData;
        if (isLoading) {
          return const DeviceMetadataBubble(label: 'FW', isLoading: true);
        }

        final versionText = versionSnapshot.hasError
            ? '--'
            : (versionSnapshot.data?.toString() ?? '--');

        if (supportFuture == null) {
          return DeviceMetadataBubble(
            label: 'FW',
            value: versionText,
          );
        }

        return FutureBuilder<FirmwareSupportStatus>(
          future: supportFuture,
          initialData: cache.cachedFirmwareSupportFor(wearable.deviceId),
          builder: (context, supportSnapshot) {
            IconData? statusIcon;
            Color? statusColor;
            switch (supportSnapshot.data) {
              case FirmwareSupportStatus.tooOld:
              case FirmwareSupportStatus.tooNew:
                statusIcon = Icons.warning_rounded;
                statusColor = Colors.orange;
                break;
              case FirmwareSupportStatus.unsupported:
                statusIcon = Icons.error_outline_rounded;
                statusColor = Theme.of(context).colorScheme.error;
                break;
              case FirmwareSupportStatus.unknown:
                statusIcon = Icons.help_rounded;
                statusColor = Theme.of(context).colorScheme.onSurfaceVariant;
                break;
              default:
                break;
            }

            return DeviceMetadataBubble(
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

class DeviceHardwarePill extends StatelessWidget {
  final Wearable wearable;

  const DeviceHardwarePill({super.key, required this.wearable});

  @override
  Widget build(BuildContext context) {
    final cache = WearableStatusCache.instance;
    final versionFuture = cache.ensureHardwareVersion(wearable);
    if (versionFuture == null) {
      return const DeviceMetadataBubble(label: 'HW', value: '--');
    }

    return FutureBuilder<Object?>(
      future: versionFuture,
      initialData: cache.cachedHardwareVersionFor(wearable.deviceId),
      builder: (context, snapshot) {
        final isLoading = snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData;
        if (isLoading) {
          return const DeviceMetadataBubble(label: 'HW', isLoading: true);
        }

        final versionText =
            snapshot.hasError ? '--' : (snapshot.data?.toString() ?? '--');

        return DeviceMetadataBubble(
          label: 'HW',
          value: versionText,
        );
      },
    );
  }
}

class DeviceMetadataBubble extends StatelessWidget {
  final String label;
  final String? value;
  final bool isLoading;
  final bool highlighted;
  final IconData? trailingIcon;
  final Color? foregroundColor;
  final bool showBackground;

  const DeviceMetadataBubble({
    super.key,
    required this.label,
    this.value,
    this.isLoading = false,
    this.highlighted = false,
    this.trailingIcon,
    this.foregroundColor,
    this.showBackground = true,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final defaultForeground = colorScheme.primary;
    final resolvedForeground = foregroundColor ?? defaultForeground;
    final effectiveForeground =
        highlighted ? colorScheme.primary : resolvedForeground;
    final backgroundColor = highlighted
        ? effectiveForeground.withValues(alpha: 0.12)
        : showBackground
            ? colorScheme.surface
            : Colors.transparent;
    final borderColor = highlighted
        ? effectiveForeground.withValues(alpha: 0.24)
        : resolvedForeground.withValues(alpha: 0.42);
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
              color: effectiveForeground,
            ),
          if (!isLoading && trailingIcon != null) const SizedBox(width: 6),
          Text(
            displayText,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: effectiveForeground,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.1,
                ),
          ),
        ],
      ),
    );
  }
}

String? _sideLabelForPosition(DevicePosition? position) {
  return switch (position) {
    DevicePosition.left => 'L',
    DevicePosition.right => 'R',
    _ => null,
  };
}
