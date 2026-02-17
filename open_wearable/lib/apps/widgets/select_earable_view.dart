import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart';
import 'package:open_wearable/apps/widgets/app_compatibility.dart';
import 'package:open_wearable/models/device_name_formatter.dart';
import 'package:open_wearable/models/wearable_display_group.dart';
import 'package:open_wearable/view_models/sensor_configuration_provider.dart';
import 'package:open_wearable/view_models/wearables_provider.dart';
import 'package:open_wearable/widgets/devices/device_status_pills.dart';
import 'package:open_wearable/widgets/devices/wearable_icon.dart';
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
  final bool selected;
  final VoidCallback onTap;

  const _SelectableWearableCard({
    required this.wearable,
    required this.position,
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
                    child: WearableIcon(
                      wearable: wearable,
                      initialVariant: iconVariant,
                      hideWhileResolvingStereoPosition: true,
                      hideWhenResolvedVariantIsSingle: true,
                      fallback: const SizedBox.shrink(),
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
                            formatWearableDisplayName(wearable.name),
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
    String? sideLabel;
    if (position == DevicePosition.left) {
      sideLabel = 'L';
    } else if (position == DevicePosition.right) {
      sideLabel = 'R';
    }

    return buildDeviceStatusPills(
      wearable: wearable,
      sideLabel: sideLabel,
      showStereoPosition: sideLabel == null,
      batteryLiveUpdates: true,
      batteryShowBackground: true,
    );
  }

  Widget _buildStatusPillLine(List<Widget> pills) {
    return DevicePillLine(pills: pills);
  }
}
