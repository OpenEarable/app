import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:go_router/go_router.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart';
import 'package:open_wearable/models/wearable_display_group.dart';
import 'package:open_wearable/view_models/wearables_provider.dart';
import 'package:open_wearable/widgets/devices/battery_state.dart';
import 'package:open_wearable/widgets/devices/connect_devices_page.dart';
import 'package:open_wearable/widgets/devices/device_detail/audio_mode_widget.dart';
import 'package:open_wearable/widgets/devices/device_detail/device_detail_page.dart';
import 'package:open_wearable/widgets/devices/stereo_position_badge.dart';
import 'package:open_wearable/widgets/recording_activity_indicator.dart';
import 'package:open_wearable/widgets/sensors/sensor_page_spacing.dart';
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
          physics: const AlwaysScrollableScrollPhysics(),
          padding: SensorPageSpacing.pagePadding,
          children: [
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.62,
              child: Center(
                child: _NoDevicesPromptView(
                  onScanPressed: () => context.push('/connect-devices'),
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

        if (groups.isEmpty) {
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: _NoDevicesPromptView(
                  onScanPressed: () => context.push('/connect-devices'),
                ),
              ),
            ),
          );
        }

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

class _NoDevicesPromptView extends StatelessWidget {
  final VoidCallback onScanPressed;

  const _NoDevicesPromptView({required this.onScanPressed});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer.withValues(alpha: 0.45),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(
              Icons.bluetooth_searching_rounded,
              size: 28,
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(height: 14),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 280),
            child: Text(
              'No devices connected',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 280),
            child: Text(
              'Scan for devices to start streaming and recording data.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: onScanPressed,
            icon: const Icon(Icons.search_rounded, size: 18),
            label: const Text('Scan for devices'),
          ),
        ],
      ),
    );
  }
}

// MARK: DeviceRow

/// This widget represents a single device in the list/grid.
/// Tapping on it will navigate to the [DeviceDetailPage].
class DeviceRow extends StatelessWidget {
  final WearableDisplayGroup group;
  final void Function(String pairKey, bool combined)? onPairCombineChanged;
  final void Function(Wearable device)? onSingleDeviceSelected;
  final bool showWearableIcon;

  const DeviceRow({
    super.key,
    required this.group,
    this.onPairCombineChanged,
    this.onSingleDeviceSelected,
    this.showWearableIcon = true,
  });

  @override
  Widget build(BuildContext context) {
    final primary = group.representative;
    final secondary = group.secondary;
    final pairKey = group.stereoPairKey;
    final knownIconVariant = _resolveWearableIconVariant();
    final hasWearableIcon = showWearableIcon &&
        (primary.getWearableIconPath(variant: knownIconVariant)?.isNotEmpty ??
            false);
    final topRightIdentifierLabel = _buildTopRightIdentifierLabel();
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
                  if (hasWearableIcon) ...[
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: SizedBox(
                        width: 56,
                        height: 56,
                        child: _WearableIconView(
                          device: primary,
                          initialVariant: knownIconVariant,
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
                              flex: group.isCombined ? 6 : 7,
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
                            if (topRightIdentifierLabel != null) ...[
                              const SizedBox(width: 8),
                              Expanded(
                                flex: group.isCombined ? 5 : 4,
                                child: _buildIdentifierLabel(
                                  context,
                                  topRightIdentifierLabel,
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
                              'Tap to choose left or right device controls',
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

  WearableIconVariant _resolveWearableIconVariant() {
    if (group.isCombined) {
      return WearableIconVariant.pair;
    }

    switch (group.primaryPosition) {
      case DevicePosition.left:
        return WearableIconVariant.left;
      case DevicePosition.right:
        return WearableIconVariant.right;
      case null:
        return WearableIconVariant.single;
    }
  }

  String? _buildTopRightIdentifierLabel() {
    if (!group.isCombined) {
      final label = group.identifiersLabel.trim();
      return label.isEmpty ? null : label;
    }

    final leftId = group.leftDevice?.deviceId;
    final rightId = group.rightDevice?.deviceId;
    if (leftId == null ||
        leftId.isEmpty ||
        rightId == null ||
        rightId.isEmpty) {
      return null;
    }

    return '${_compactIdentifier(leftId)} / ${_compactIdentifier(rightId)}';
  }

  Widget _buildIdentifierLabel(BuildContext context, String label) {
    final style = Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        );

    if (!group.isCombined) {
      return Align(
        alignment: Alignment.centerRight,
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.right,
          style: style,
        ),
      );
    }

    final parts = label.split(' / ');
    if (parts.length != 2) {
      return Align(
        alignment: Alignment.centerRight,
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.right,
          style: style,
        ),
      );
    }

    return Row(
      children: [
        Expanded(
          child: Text(
            parts[0],
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.fade,
            textAlign: TextAlign.right,
            style: style,
          ),
        ),
        Text(' / ', style: style),
        Expanded(
          child: Text(
            parts[1],
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.fade,
            textAlign: TextAlign.left,
            style: style,
          ),
        ),
      ],
    );
  }

  String _compactIdentifier(String id) {
    final normalized = id.trim();
    const maxChars = 14;
    if (normalized.length <= maxChars) {
      return normalized;
    }

    const ellipsis = '...';
    final keep = maxChars - ellipsis.length;
    final prefixLength = (keep / 2).ceil();
    final suffixLength = keep - prefixLength;

    return '${normalized.substring(0, prefixLength)}'
        '$ellipsis'
        '${normalized.substring(normalized.length - suffixLength)}';
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
        const [_MetadataBubble(label: 'L+R', highlighted: true)],
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
        _MetadataBubble(label: sideLabel, highlighted: true),
      if (hasStereoPositionPill)
        StereoPositionBadge(device: device.requireCapability<StereoDevice>()),
      if (hasBatteryStatus)
        BatteryStateView(
          key: ValueKey<String>('battery_${device.deviceId}'),
          device: device,
        ),
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

  Future<void> _openDetails(BuildContext context) async {
    final devices = group.members;
    if (devices.length == 1) {
      final device = devices.first;
      if (onSingleDeviceSelected != null) {
        onSingleDeviceSelected!(device);
      } else {
        _openDeviceDetail(context, device);
      }
      return;
    }

    final leftDevice = group.leftDevice ?? devices.first;
    final rightDevice = group.rightDevice ?? devices.last;

    await showPlatformModalSheet<void>(
      context: context,
      builder: (sheetContext) => _PairedDeviceSheet(
        title: group.displayName,
        leftDevice: leftDevice,
        rightDevice: rightDevice,
        onOpenDeviceDetail: (device) {
          Navigator.of(sheetContext).pop();
          if (onSingleDeviceSelected != null) {
            onSingleDeviceSelected!(device);
          } else {
            _openDeviceDetail(context, device);
          }
        },
      ),
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

class _WearableIconView extends StatefulWidget {
  final Wearable device;
  final WearableIconVariant initialVariant;

  const _WearableIconView({
    required this.device,
    required this.initialVariant,
  });

  @override
  State<_WearableIconView> createState() => _WearableIconViewState();
}

class _WearableIconViewState extends State<_WearableIconView> {
  static final Expando<Future<DevicePosition?>> _positionFutureCache =
      Expando<Future<DevicePosition?>>();

  Future<DevicePosition?>? _positionFuture;

  @override
  void initState() {
    super.initState();
    _configurePositionFuture();
  }

  @override
  void didUpdateWidget(covariant _WearableIconView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.device, widget.device) ||
        oldWidget.initialVariant != widget.initialVariant) {
      _configurePositionFuture();
    }
  }

  void _configurePositionFuture() {
    if (widget.initialVariant != WearableIconVariant.single ||
        !widget.device.hasCapability<StereoDevice>()) {
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
      _ => widget.initialVariant,
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
    final path = _resolveIconPath(variant);
    if (path == null) {
      return const SizedBox.shrink();
    }

    if (path.toLowerCase().endsWith('.svg')) {
      return SvgPicture.asset(
        path,
        fit: BoxFit.contain,
      );
    }

    return Image.asset(
      path,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => const Icon(Icons.watch_outlined),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_positionFuture == null) {
      return _buildIcon(widget.initialVariant);
    }

    return FutureBuilder<DevicePosition?>(
      future: _positionFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          // Avoid flashing the generic icon before stereo side is known.
          return const SizedBox.shrink();
        }
        final variant = _variantForPosition(snapshot.data);
        if (variant == WearableIconVariant.single) {
          return const SizedBox.shrink();
        }
        return _buildIcon(variant);
      },
    );
  }
}

class _PairedDeviceSheet extends StatelessWidget {
  final String title;
  final Wearable leftDevice;
  final Wearable rightDevice;
  final void Function(Wearable device) onOpenDeviceDetail;

  const _PairedDeviceSheet({
    required this.title,
    required this.leftDevice,
    required this.rightDevice,
    required this.onOpenDeviceDetail,
  });

  bool _supportsStereoListeningMode(Wearable device) {
    return device.hasCapability<StereoDevice>() &&
        device.hasCapability<AudioModeManager>();
  }

  Wearable? _resolveListeningModeDevice() {
    if (_supportsStereoListeningMode(leftDevice)) {
      return leftDevice;
    }
    if (_supportsStereoListeningMode(rightDevice)) {
      return rightDevice;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final listeningModeDevice = _resolveListeningModeDevice();

    return SafeArea(
      child: Material(
        color: theme.colorScheme.surface,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Select a device to open details.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded, size: 20),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              DeviceRow(
                group: WearableDisplayGroup.single(
                  wearable: leftDevice,
                  position: DevicePosition.left,
                ),
                onSingleDeviceSelected: onOpenDeviceDetail,
              ),
              const SizedBox(height: 8),
              DeviceRow(
                group: WearableDisplayGroup.single(
                  wearable: rightDevice,
                  position: DevicePosition.right,
                ),
                onSingleDeviceSelected: onOpenDeviceDetail,
              ),
              if (listeningModeDevice != null) ...[
                const SizedBox(height: 12),
                AudioModeWidget(
                  key: ValueKey(
                    'pair_audio_${leftDevice.deviceId}_${rightDevice.deviceId}',
                  ),
                  device: listeningModeDevice,
                  applyScope: AudioModeApplyScope.pairOnly,
                ),
              ] else ...[
                const SizedBox(height: 10),
                Text(
                  'Listening mode is not available for this stereo pair.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _FirmwareVersionBubble extends StatefulWidget {
  final DeviceFirmwareVersion firmwareVersion;

  const _FirmwareVersionBubble({required this.firmwareVersion});

  @override
  State<_FirmwareVersionBubble> createState() => _FirmwareVersionBubbleState();
}

class _FirmwareVersionBubbleState extends State<_FirmwareVersionBubble> {
  static final Expando<Future<Object?>> _versionFutureCache =
      Expando<Future<Object?>>();
  static final Expando<Future<FirmwareSupportStatus>> _supportFutureCache =
      Expando<Future<FirmwareSupportStatus>>();

  late Future<Object?> _versionFuture;
  late Future<FirmwareSupportStatus> _supportFuture;

  @override
  void initState() {
    super.initState();
    _versionFuture = _resolveVersionFuture(widget.firmwareVersion);
    _supportFuture = _resolveSupportFuture(widget.firmwareVersion);
  }

  @override
  void didUpdateWidget(covariant _FirmwareVersionBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.firmwareVersion, widget.firmwareVersion)) {
      _versionFuture = _resolveVersionFuture(widget.firmwareVersion);
      _supportFuture = _resolveSupportFuture(widget.firmwareVersion);
    }
  }

  Future<Object?> _resolveVersionFuture(DeviceFirmwareVersion firmwareVersion) {
    return _versionFutureCache[firmwareVersion] ??=
        firmwareVersion.readDeviceFirmwareVersion();
  }

  Future<FirmwareSupportStatus> _resolveSupportFuture(
    DeviceFirmwareVersion firmwareVersion,
  ) {
    return _supportFutureCache[firmwareVersion] ??=
        firmwareVersion.checkFirmwareSupport();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Object?>(
      future: _versionFuture,
      builder: (context, versionSnapshot) {
        if (versionSnapshot.connectionState == ConnectionState.waiting) {
          return const _MetadataBubble(label: "FW", isLoading: true);
        }

        final versionText = versionSnapshot.hasError
            ? "--"
            : (versionSnapshot.data?.toString() ?? "--");

        return FutureBuilder<FirmwareSupportStatus>(
          future: _supportFuture,
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

class _HardwareVersionBubble extends StatefulWidget {
  final DeviceHardwareVersion hardwareVersion;

  const _HardwareVersionBubble({required this.hardwareVersion});

  @override
  State<_HardwareVersionBubble> createState() => _HardwareVersionBubbleState();
}

class _HardwareVersionBubbleState extends State<_HardwareVersionBubble> {
  static final Expando<Future<Object?>> _versionFutureCache =
      Expando<Future<Object?>>();

  late Future<Object?> _versionFuture;

  @override
  void initState() {
    super.initState();
    _versionFuture = _resolveVersionFuture(widget.hardwareVersion);
  }

  @override
  void didUpdateWidget(covariant _HardwareVersionBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.hardwareVersion, widget.hardwareVersion)) {
      _versionFuture = _resolveVersionFuture(widget.hardwareVersion);
    }
  }

  Future<Object?> _resolveVersionFuture(DeviceHardwareVersion hardwareVersion) {
    return _versionFutureCache[hardwareVersion] ??=
        hardwareVersion.readDeviceHardwareVersion();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Object?>(
      future: _versionFuture,
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
  final bool highlighted;
  final IconData? trailingIcon;
  final Color? foregroundColor;

  const _MetadataBubble({
    required this.label,
    this.value,
    this.isLoading = false,
    this.highlighted = false,
    this.trailingIcon,
    this.foregroundColor,
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
        : colorScheme.surface;
    final borderColor = highlighted
        ? effectiveForeground.withValues(alpha: 0.24)
        : resolvedForeground.withValues(alpha: 0.42);
    final displayText =
        isLoading ? "$label ..." : (value == null ? label : "$label $value");

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
