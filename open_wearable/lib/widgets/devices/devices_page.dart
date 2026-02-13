import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:go_router/go_router.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart';
import 'package:open_wearable/models/wearable_display_group.dart';
import 'package:open_wearable/view_models/wearables_provider.dart';
import 'package:open_wearable/widgets/devices/battery_state.dart';
import 'package:open_wearable/widgets/devices/connect_devices_page.dart';
import 'package:open_wearable/widgets/devices/device_detail/device_detail_page.dart';
import 'package:open_wearable/widgets/devices/stereo_position_badge.dart';
import 'package:open_wearable/widgets/recording_activity_indicator.dart';
import 'package:provider/provider.dart';

/// On this page the user can see all connected devices.
///
/// Tapping on a device will navigate to the [DeviceDetailPage].
class DevicesPage extends StatefulWidget {
  const DevicesPage({super.key});

  @override
  State<DevicesPage> createState() => _DevicesPageState();
}

class _DevicesPageState extends State<DevicesPage> {
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

  Widget _buildSmallScreenLayout(
    BuildContext context,
    WearablesProvider wearablesProvider,
  ) {
    return PlatformScaffold(
      appBar: PlatformAppBar(
        title: PlatformText("Devices"),
        trailingActions: [
          const AppBarRecordingIndicator(),
          PlatformIconButton(
            icon: Icon(context.platformIcons.bluetooth),
            onPressed: () {
              context.push('/connect-devices');
            },
          ),
        ],
      ),
      body: _buildSmallScreenContent(context, wearablesProvider),
    );
  }

  Widget _buildSmallScreenContent(
    BuildContext context,
    WearablesProvider wearablesProvider,
  ) {
    if (wearablesProvider.wearables.isEmpty) {
      return RefreshIndicator(
        onRefresh: () async {
          // await _startBluetooth();
          //TODO: implement refresh logic
        },
        child: ListView(
          children: [
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.8,
              child: Center(
                child: PlatformText(
                  "No devices connected",
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return FutureBuilder<List<WearableDisplayGroup>>(
      future: buildWearableDisplayGroups(
        wearablesProvider.wearables,
        shouldCombinePair: (left, right) =>
            wearablesProvider.isStereoPairCombined(
          first: left,
          second: right,
        ),
      ),
      builder: (context, snapshot) {
        final groups = _orderGroupsForOverview(
          snapshot.data ??
              wearablesProvider.wearables
                  .map(
                    (wearable) =>
                        WearableDisplayGroup.single(wearable: wearable),
                  )
                  .toList(),
        );

        return RefreshIndicator(
          onRefresh: () {
            return WearableManager().connectToSystemDevices().then((wearables) {
              for (var wearable in wearables) {
                wearablesProvider.addWearable(wearable);
              }
            });
          },
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: ListView.builder(
              itemCount: groups.length,
              itemBuilder: (context, index) {
                return DeviceRow(
                  group: groups[index],
                  onPairCombineChanged: (pairKey, combined) =>
                      wearablesProvider.setStereoPairKeyCombined(
                    pairKey: pairKey,
                    combined: combined,
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildLargeScreenLayout(
    BuildContext context,
    WearablesProvider wearablesProvider,
  ) {
    return FutureBuilder<List<WearableDisplayGroup>>(
      future: buildWearableDisplayGroups(
        wearablesProvider.wearables,
        shouldCombinePair: (left, right) =>
            wearablesProvider.isStereoPairCombined(
          first: left,
          second: right,
        ),
      ),
      builder: (context, snapshot) {
        final groups = _orderGroupsForOverview(
          snapshot.data ??
              wearablesProvider.wearables
                  .map(
                    (wearable) =>
                        WearableDisplayGroup.single(wearable: wearable),
                  )
                  .toList(),
        );

        return GridView.builder(
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 500,
            childAspectRatio: 3,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
          ),
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: groups.length + 1,
          itemBuilder: (context, index) {
            if (index == groups.length) {
              return GestureDetector(
                onTap: () {
                  showPlatformModalSheet(
                    context: context,
                    builder: (context) => const ConnectDevicesPage(),
                  );
                },
                child: Card(
                  color: Theme.of(context)
                      .colorScheme
                      .surfaceTint
                      .withValues(alpha: 0.2),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          PlatformIcons(context).add,
                          color: Theme.of(context).colorScheme.surfaceTint,
                        ),
                        PlatformText(
                          "Connect Device",
                          style: Theme.of(context)
                              .textTheme
                              .bodyLarge
                              ?.copyWith(
                                color:
                                    Theme.of(context).colorScheme.surfaceTint,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }
            return DeviceRow(
              group: groups[index],
              onPairCombineChanged: (pairKey, combined) =>
                  wearablesProvider.setStereoPairKeyCombined(
                pairKey: pairKey,
                combined: combined,
              ),
            );
          },
        );
      },
    );
  }

  List<WearableDisplayGroup> _orderGroupsForOverview(
    List<WearableDisplayGroup> groups,
  ) {
    final indexed = groups.asMap().entries.toList();

    int rank(WearableDisplayGroup group) {
      if (group.isCombined) {
        return 0;
      }
      if (group.primaryPosition == DevicePosition.left) {
        return 1;
      }
      if (group.primaryPosition == DevicePosition.right) {
        return 2;
      }
      return 3;
    }

    indexed.sort((a, b) {
      final rankA = rank(a.value);
      final rankB = rank(b.value);
      if (rankA != rankB) {
        return rankA.compareTo(rankB);
      }

      if (rankA <= 2) {
        final byName = a.value.displayName
            .toLowerCase()
            .compareTo(b.value.displayName.toLowerCase());
        if (byName != 0) {
          return byName;
        }
      }

      return a.key.compareTo(b.key);
    });

    return indexed.map((entry) => entry.value).toList();
  }
}

// MARK: DeviceRow

/// This widget represents a single device in the list/grid.
/// Tapping on it will navigate to the [DeviceDetailPage].
class DeviceRow extends StatelessWidget {
  final WearableDisplayGroup group;
  final void Function(String pairKey, bool combined)? onPairCombineChanged;

  const DeviceRow({
    super.key,
    required this.group,
    this.onPairCombineChanged,
  });

  @override
  Widget build(BuildContext context) {
    final primary = group.representative;
    final secondary = group.secondary;
    final pairKey = group.stereoPairKey;
    final wearableIconPath = primary.getWearableIconPath();
    final statusPills = _buildDeviceStatusPills(
      primary,
      includeSideLabel: false,
      showStereoPosition: !group.isCombined,
    );

    return GestureDetector(
      onTap: () => _openDetails(context),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (wearableIconPath != null) ...[
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: SizedBox(
                        width: 56,
                        height: 56,
                        child: SvgPicture.asset(
                          wearableIconPath,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                group.displayName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyLarge
                                    ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                            ),
                            if (!group.isCombined) ...[
                              const SizedBox(width: 8),
                              ConstrainedBox(
                                constraints:
                                    const BoxConstraints(maxWidth: 170),
                                child: Text(
                                  group.identifiersLabel,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.right,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant,
                                        fontWeight: FontWeight.w600,
                                      ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        if (group.isCombined) ...[
                          const SizedBox(height: 8),
                          ..._buildCombinedStatusLines(),
                        ] else if (statusPills.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          _buildStatusPillLine(statusPills),
                        ],
                        if (secondary != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              'Tap to choose left or right device details',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              if (pairKey != null) ...[
                const SizedBox(height: 8),
                Divider(
                  height: 1,
                  thickness: 0.6,
                  color: Theme.of(
                    context,
                  ).colorScheme.outlineVariant.withValues(alpha: 0.55),
                ),
                const SizedBox(height: 6),
                _buildPairToggleButton(
                  context,
                  pairKey: pairKey,
                  combined: group.isCombined,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPairToggleButton(
    BuildContext context, {
    required String pairKey,
    required bool combined,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final enabled = onPairCombineChanged != null;
    return SizedBox(
      width: double.infinity,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Row(
          children: [
            Icon(
              combined ? Icons.merge_type : Icons.call_split,
              size: 16,
              color: enabled
                  ? colorScheme.primary
                  : colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Combine stereo pair',
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Switch.adaptive(
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              value: combined,
              onChanged: enabled
                  ? (value) => onPairCombineChanged!(pairKey, value)
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildCombinedStatusLines() {
    final lines = <Widget>[];
    final left = group.leftDevice;
    final right = group.rightDevice;

    if (left != null) {
      lines.add(
        _buildStatusPillLine(
          _buildDeviceStatusPills(
            left,
            includeSideLabel: true,
            sideLabel: 'L',
          ),
        ),
      );
    }

    if (right != null) {
      if (lines.isNotEmpty) {
        lines.add(const SizedBox(height: 6));
      }
      lines.add(
        _buildStatusPillLine(
          _buildDeviceStatusPills(
            right,
            includeSideLabel: true,
            sideLabel: 'R',
          ),
        ),
      );
    }

    if (lines.isNotEmpty) {
      return lines;
    }

    return [
      _buildStatusPillLine(
        const [_MetadataBubble(label: 'L+R')],
      ),
    ];
  }

  List<Widget> _buildDeviceStatusPills(
    Wearable device, {
    required bool includeSideLabel,
    String? sideLabel,
    bool showStereoPosition = false,
  }) {
    final hasBatteryStatus = device.hasCapability<BatteryLevelStatus>() ||
        device.hasCapability<BatteryLevelStatusService>();
    final hasFirmwareInfo = device.hasCapability<DeviceFirmwareVersion>();
    final hasHardwareInfo = device.hasCapability<DeviceHardwareVersion>();
    final hasStereoPositionPill =
        showStereoPosition && device.hasCapability<StereoDevice>();

    return <Widget>[
      if (includeSideLabel && sideLabel != null)
        _MetadataBubble(label: sideLabel),
      if (hasStereoPositionPill)
        StereoPositionBadge(device: device.requireCapability<StereoDevice>()),
      if (hasBatteryStatus) BatteryStateView(device: device),
      if (hasFirmwareInfo)
        _FirmwareVersionBubble(
          firmwareVersion: device.requireCapability<DeviceFirmwareVersion>(),
        ),
      if (hasHardwareInfo)
        _HardwareVersionBubble(
          hardwareVersion: device.requireCapability<DeviceHardwareVersion>(),
        ),
    ];
  }

  Widget _buildStatusPillLine(List<Widget> pills) {
    if (pills.isEmpty) {
      return const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: BoxConstraints(minWidth: constraints.maxWidth),
          child: Row(
            mainAxisAlignment: pills.length == 1
                ? MainAxisAlignment.start
                : MainAxisAlignment.spaceBetween,
            children: pills,
          ),
        ),
      ),
    );
  }

  Future<void> _openDetails(BuildContext context) async {
    final devices = group.members;
    if (devices.length == 1) {
      _openDeviceDetail(context, devices.first);
      return;
    }

    await showPlatformModalSheet<void>(
      context: context,
      builder: (sheetContext) => PlatformWidget(
        material: (_, __) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildPairedActionTile(
                sheetContext: sheetContext,
                rootContext: context,
                device: group.leftDevice ?? devices.first,
                sideLabel: 'Left',
              ),
              _buildPairedActionTile(
                sheetContext: sheetContext,
                rootContext: context,
                device: group.rightDevice ?? devices.last,
                sideLabel: 'Right',
              ),
            ],
          ),
        ),
        cupertino: (_, __) => CupertinoActionSheet(
          title: Text(group.displayName),
          actions: [
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.of(sheetContext).pop();
                _openDeviceDetail(
                  context,
                  group.leftDevice ?? devices.first,
                );
              },
              child: const Text('Open Left Device'),
            ),
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.of(sheetContext).pop();
                _openDeviceDetail(
                  context,
                  group.rightDevice ?? devices.last,
                );
              },
              child: const Text('Open Right Device'),
            ),
          ],
          cancelButton: CupertinoActionSheetAction(
            onPressed: () => Navigator.of(sheetContext).pop(),
            child: const Text('Cancel'),
          ),
        ),
      ),
    );
  }

  Widget _buildPairedActionTile({
    required BuildContext sheetContext,
    required BuildContext rootContext,
    required Wearable device,
    required String sideLabel,
  }) {
    final positionLabel = sideLabel == 'Left' ? 'L' : 'R';

    return ListTile(
      leading: _MetadataBubble(label: positionLabel),
      title: Text(device.name),
      subtitle: Text(device.deviceId),
      onTap: () {
        Navigator.of(sheetContext).pop();
        _openDeviceDetail(rootContext, device);
      },
    );
  }

  void _openDeviceDetail(BuildContext context, Wearable device) {
    final isLargeScreen = MediaQuery.of(context).size.width > 600;
    if (isLargeScreen) {
      showGeneralDialog(
        context: context,
        pageBuilder: (context, animation1, animation2) {
          return Center(
            child: SizedBox(
              width: MediaQuery.of(context).size.width * 0.5,
              height: MediaQuery.of(context).size.height * 0.5,
              child: DeviceDetailPage(device: device),
            ),
          );
        },
      );
      return;
    }
    context.push('/device-detail', extra: device);
  }
}

class _FirmwareVersionBubble extends StatelessWidget {
  final DeviceFirmwareVersion firmwareVersion;

  const _FirmwareVersionBubble({required this.firmwareVersion});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Object?>(
      future: firmwareVersion.readDeviceFirmwareVersion(),
      builder: (context, versionSnapshot) {
        if (versionSnapshot.connectionState == ConnectionState.waiting) {
          return const _MetadataBubble(label: "FW", isLoading: true);
        }

        final versionText = versionSnapshot.hasError
            ? "--"
            : (versionSnapshot.data?.toString() ?? "--");

        return FutureBuilder<FirmwareSupportStatus>(
          future: firmwareVersion.checkFirmwareSupport(),
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
              label: "FW",
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

class _HardwareVersionBubble extends StatelessWidget {
  final DeviceHardwareVersion hardwareVersion;

  const _HardwareVersionBubble({required this.hardwareVersion});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Object?>(
      future: hardwareVersion.readDeviceHardwareVersion(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _MetadataBubble(label: "HW", isLoading: true);
        }

        final versionText =
            snapshot.hasError ? "--" : (snapshot.data?.toString() ?? "--");

        return _MetadataBubble(
          label: "HW",
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
          if (isLoading)
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: resolvedForeground,
              ),
            )
          else if (trailingIcon != null)
            Icon(
              trailingIcon,
              size: 14,
              color: resolvedForeground,
            ),
          if (isLoading || trailingIcon != null) const SizedBox(width: 6),
          Text(
            value == null ? label : "$label $value",
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
