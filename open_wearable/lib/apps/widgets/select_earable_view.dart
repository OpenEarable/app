import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart';
import 'package:open_wearable/apps/widgets/app_compatibility.dart';
import 'package:open_wearable/models/wearable_display_group.dart';
import 'package:open_wearable/view_models/sensor_configuration_provider.dart';
import 'package:open_wearable/view_models/wearables_provider.dart';
import 'package:open_wearable/widgets/devices/battery_state.dart';
import 'package:open_wearable/widgets/devices/stereo_position_badge.dart';
import 'package:provider/provider.dart';

class SelectEarableView extends StatefulWidget {
  final Widget Function(Wearable, SensorConfigurationProvider) startApp;
  final List<String> supportedDevicePrefixes;

  const SelectEarableView({
    super.key,
    required this.startApp,
    this.supportedDevicePrefixes = const [],
  });

  @override
  State<SelectEarableView> createState() => _SelectEarableViewState();
}

class _SelectEarableViewState extends State<SelectEarableView> {
  Wearable? _selectedWearable;
  Future<List<WearableDisplayGroup>>? _groupsFuture;
  String _groupFingerprint = '';
  final Map<String, _DeviceInfoFutureCache> _deviceInfoFutureCache = {};

  @override
  Widget build(BuildContext context) {
    return PlatformScaffold(
      appBar: PlatformAppBar(
        title: PlatformText('Select Wearable'),
      ),
      body: Consumer<WearablesProvider>(
        builder: (context, wearablesProvider, _) {
          final compatibleWearables = wearablesProvider.wearables
              .where(
                (wearable) => wearableIsCompatibleWithApp(
                  wearableName: wearable.name,
                  supportedDevicePrefixes: widget.supportedDevicePrefixes,
                ),
              )
              .toList(growable: false);

          _refreshGroupFutureIfNeeded(compatibleWearables);
          final selectedDeviceId = _selectedWearable?.deviceId;
          final hasSelectedCompatibleWearable = selectedDeviceId != null &&
              compatibleWearables.any(
                (wearable) => wearable.deviceId == selectedDeviceId,
              );

          return Column(
            children: [
              Expanded(
                child: _buildBody(
                  context,
                  compatibleWearables: compatibleWearables,
                  wearablesProvider: wearablesProvider,
                ),
              ),
              SafeArea(
                top: false,
                minimum: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: SizedBox(
                  width: double.infinity,
                  child: PlatformElevatedButton(
                    onPressed: hasSelectedCompatibleWearable
                        ? () => _startSelectedApp(
                              context,
                              wearablesProvider,
                              compatibleWearables,
                            )
                        : null,
                    child: PlatformText('Start App'),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _refreshGroupFutureIfNeeded(List<Wearable> wearables) {
    final activeIds = wearables.map((wearable) => wearable.deviceId).toSet();
    _deviceInfoFutureCache.removeWhere((id, _) => !activeIds.contains(id));
    for (final wearable in wearables) {
      _ensureInfoCacheForWearable(wearable);
    }

    final fingerprint = wearables
        .map((wearable) => '${wearable.deviceId}:${wearable.name}')
        .join('|');
    if (_groupsFuture != null && _groupFingerprint == fingerprint) {
      return;
    }

    _groupFingerprint = fingerprint;
    _groupsFuture = buildWearableDisplayGroups(
      wearables,
      shouldCombinePair: (_, __) => false,
    );
  }

  _DeviceInfoFutureCache _ensureInfoCacheForWearable(Wearable wearable) {
    final cache = _deviceInfoFutureCache.putIfAbsent(
      wearable.deviceId,
      _DeviceInfoFutureCache.new,
    );

    if (cache.firmwareVersionFuture == null &&
        wearable.hasCapability<DeviceFirmwareVersion>()) {
      final capability = wearable.requireCapability<DeviceFirmwareVersion>();
      cache.firmwareVersionFuture = capability.readDeviceFirmwareVersion();
      cache.firmwareSupportFuture = capability.checkFirmwareSupport();
    }
    if (cache.hardwareVersionFuture == null &&
        wearable.hasCapability<DeviceHardwareVersion>()) {
      final capability = wearable.requireCapability<DeviceHardwareVersion>();
      cache.hardwareVersionFuture = capability.readDeviceHardwareVersion();
    }
    return cache;
  }

  Widget _buildBody(
    BuildContext context, {
    required List<Wearable> compatibleWearables,
    required WearablesProvider wearablesProvider,
  }) {
    if (compatibleWearables.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Text(
            'No compatible wearables connected for this app.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      );
    }

    return FutureBuilder<List<WearableDisplayGroup>>(
      future: _groupsFuture,
      builder: (context, snapshot) {
        final groups = _sortGroupsForSelection(
          snapshot.data ??
              compatibleWearables
                  .map(
                    (wearable) =>
                        WearableDisplayGroup.single(wearable: wearable),
                  )
                  .toList(growable: false),
        );

        if (groups.isEmpty) {
          return const SizedBox.shrink();
        }

        final selectedId = _selectedWearable?.deviceId;

        return ListView.builder(
          padding: const EdgeInsets.all(10),
          itemCount: groups.length,
          itemBuilder: (context, index) {
            final group = groups[index];
            final wearable = group.primary;
            final isSelected = selectedId == wearable.deviceId;

            return _SelectableWearableCard(
              wearable: wearable,
              position: group.primaryPosition,
              infoCache: _ensureInfoCacheForWearable(wearable),
              selected: isSelected,
              onTap: () {
                setState(() {
                  _selectedWearable = wearable;
                });
              },
            );
          },
        );
      },
    );
  }

  List<WearableDisplayGroup> _sortGroupsForSelection(
    List<WearableDisplayGroup> groups,
  ) {
    final indexed = groups.asMap().entries.toList();

    String normalizedName(String name) {
      var value = name.trim();
      value = value.replaceFirst(
        RegExp(r'\s*\((left|right|l|r)\)$', caseSensitive: false),
        '',
      );
      value = value.replaceFirst(
        RegExp(r'[\s_-]+(left|right|l|r)$', caseSensitive: false),
        '',
      );
      value = value.trim();
      return value.isEmpty ? name.trim() : value;
    }

    int positionRank(DevicePosition? position) {
      return switch (position) {
        DevicePosition.left => 0,
        DevicePosition.right => 1,
        _ => 2,
      };
    }

    indexed.sort((a, b) {
      final aBase = normalizedName(a.value.primary.name).toLowerCase();
      final bBase = normalizedName(b.value.primary.name).toLowerCase();
      final byBase = aBase.compareTo(bBase);
      if (byBase != 0) {
        return byBase;
      }

      final byPosition = positionRank(a.value.primaryPosition)
          .compareTo(positionRank(b.value.primaryPosition));
      if (byPosition != 0) {
        return byPosition;
      }

      final byName = a.value.primary.name
          .toLowerCase()
          .compareTo(b.value.primary.name.toLowerCase());
      if (byName != 0) {
        return byName;
      }

      return a.key.compareTo(b.key);
    });

    return indexed.map((entry) => entry.value).toList(growable: false);
  }

  void _startSelectedApp(
    BuildContext context,
    WearablesProvider wearablesProvider,
    List<Wearable> compatibleWearables,
  ) {
    final selectedId = _selectedWearable?.deviceId;
    if (selectedId == null) {
      return;
    }

    final selectedWearable = compatibleWearables
        .where((wearable) => wearable.deviceId == selectedId)
        .firstOrNull;

    if (selectedWearable == null) {
      return;
    }

    final sensorConfigProvider =
        wearablesProvider.getSensorConfigurationProvider(selectedWearable);

    Navigator.push(
      context,
      platformPageRoute(
        context: context,
        builder: (context) => ChangeNotifierProvider.value(
          value: sensorConfigProvider,
          child: widget.startApp(
            selectedWearable,
            sensorConfigProvider,
          ),
        ),
      ),
    );
  }
}

class _SelectableWearableCard extends StatelessWidget {
  final Wearable wearable;
  final DevicePosition? position;
  final _DeviceInfoFutureCache infoCache;
  final bool selected;
  final VoidCallback onTap;

  const _SelectableWearableCard({
    required this.wearable,
    required this.position,
    required this.infoCache,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final iconVariant = _iconVariantForPosition(position);
    final hasWearableIcon = _hasWearableIcon(iconVariant);
    final cardColor = selected
        ? colorScheme.primaryContainer.withValues(alpha: 0.34)
        : colorScheme.surface;
    final pills = _buildDeviceStatusPills();

    return Card(
      color: cardColor,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (hasWearableIcon) ...[
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: SizedBox(
                    width: 56,
                    height: 56,
                    child: _SelectableWearableIconView(
                      wearable: wearable,
                      initialVariant: iconVariant,
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
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            wearable.name,
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
                            wearable.deviceId,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.right,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (selected) ...[
                          const SizedBox(width: 6),
                          Padding(
                            padding: const EdgeInsets.only(top: 1),
                            child: Icon(
                              Icons.check_circle_rounded,
                              color: colorScheme.primary,
                              size: 18,
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (pills.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      _buildStatusPillLine(pills),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  WearableIconVariant _iconVariantForPosition(DevicePosition? position) {
    return switch (position) {
      DevicePosition.left => WearableIconVariant.left,
      DevicePosition.right => WearableIconVariant.right,
      _ => WearableIconVariant.single,
    };
  }

  bool _hasWearableIcon(WearableIconVariant initialVariant) {
    final variantPath = wearable.getWearableIconPath(variant: initialVariant);
    if (variantPath != null && variantPath.isNotEmpty) {
      return true;
    }
    final fallbackPath = wearable.getWearableIconPath();
    return fallbackPath != null && fallbackPath.isNotEmpty;
  }

  List<Widget> _buildDeviceStatusPills() {
    final hasBatteryStatus = wearable.hasCapability<BatteryLevelStatus>() ||
        wearable.hasCapability<BatteryLevelStatusService>();
    final hasFirmwareInfo = wearable.hasCapability<DeviceFirmwareVersion>();
    final hasHardwareInfo = wearable.hasCapability<DeviceHardwareVersion>();

    String? sideLabel;
    if (position == DevicePosition.left) {
      sideLabel = 'L';
    } else if (position == DevicePosition.right) {
      sideLabel = 'R';
    }

    return <Widget>[
      if (sideLabel != null)
        _MetadataBubble(label: sideLabel, highlighted: true)
      else if (wearable.hasCapability<StereoDevice>())
        StereoPositionBadge(device: wearable.requireCapability<StereoDevice>()),
      if (hasBatteryStatus)
        BatteryStateView(
          device: wearable,
          showBackground: false,
        ),
      if (hasFirmwareInfo)
        _FirmwareVersionBubble(
          firmwareVersionFuture: infoCache.firmwareVersionFuture,
          firmwareSupportFuture: infoCache.firmwareSupportFuture,
        ),
      if (hasHardwareInfo)
        _HardwareVersionBubble(
          hardwareVersionFuture: infoCache.hardwareVersionFuture,
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
}

class _SelectableWearableIconView extends StatefulWidget {
  final Wearable wearable;
  final WearableIconVariant initialVariant;

  const _SelectableWearableIconView({
    required this.wearable,
    required this.initialVariant,
  });

  @override
  State<_SelectableWearableIconView> createState() =>
      _SelectableWearableIconViewState();
}

class _SelectableWearableIconViewState
    extends State<_SelectableWearableIconView> {
  static final Expando<Future<DevicePosition?>> _positionFutureCache =
      Expando<Future<DevicePosition?>>();

  Future<DevicePosition?>? _positionFuture;

  @override
  void initState() {
    super.initState();
    _configurePositionFuture();
  }

  @override
  void didUpdateWidget(covariant _SelectableWearableIconView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.wearable, widget.wearable) ||
        oldWidget.initialVariant != widget.initialVariant) {
      _configurePositionFuture();
    }
  }

  void _configurePositionFuture() {
    if (widget.initialVariant != WearableIconVariant.single ||
        !widget.wearable.hasCapability<StereoDevice>()) {
      _positionFuture = null;
      return;
    }

    final stereoDevice = widget.wearable.requireCapability<StereoDevice>();
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
    final variantPath = widget.wearable.getWearableIconPath(variant: variant);
    if (variantPath != null && variantPath.isNotEmpty) {
      return variantPath;
    }

    if (variant != WearableIconVariant.single) {
      final fallbackPath = widget.wearable.getWearableIconPath();
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

class _FirmwareVersionBubble extends StatelessWidget {
  final Future<Object?>? firmwareVersionFuture;
  final Future<FirmwareSupportStatus>? firmwareSupportFuture;

  const _FirmwareVersionBubble({
    required this.firmwareVersionFuture,
    required this.firmwareSupportFuture,
  });

  @override
  Widget build(BuildContext context) {
    if (firmwareVersionFuture == null || firmwareSupportFuture == null) {
      return const _MetadataBubble(label: 'FW', value: '--');
    }

    return FutureBuilder<Object?>(
      future: firmwareVersionFuture,
      builder: (context, versionSnapshot) {
        if (versionSnapshot.connectionState == ConnectionState.waiting) {
          return const _MetadataBubble(label: 'FW', isLoading: true);
        }

        final versionText = versionSnapshot.hasError
            ? '--'
            : (versionSnapshot.data?.toString() ?? '--');

        return FutureBuilder<FirmwareSupportStatus>(
          future: firmwareSupportFuture,
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

class _HardwareVersionBubble extends StatelessWidget {
  final Future<Object?>? hardwareVersionFuture;

  const _HardwareVersionBubble({required this.hardwareVersionFuture});

  @override
  Widget build(BuildContext context) {
    if (hardwareVersionFuture == null) {
      return const _MetadataBubble(label: 'HW', value: '--');
    }

    return FutureBuilder<Object?>(
      future: hardwareVersionFuture,
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

class _DeviceInfoFutureCache {
  Future<Object?>? firmwareVersionFuture;
  Future<FirmwareSupportStatus>? firmwareSupportFuture;
  Future<Object?>? hardwareVersionFuture;
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
        : Colors.transparent;
    final borderColor = highlighted
        ? effectiveForeground.withValues(alpha: 0.24)
        : resolvedForeground.withValues(alpha: 0.42);
    final displayText =
        isLoading ? '$label ...' : (value == null ? label : '$label $value');

    return Container(
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
