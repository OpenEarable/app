import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart' hide logger;
import 'package:open_wearable/models/wearable_display_group.dart';
import 'package:open_wearable/view_models/sensor_configuration_provider.dart';
import 'package:open_wearable/view_models/wearables_provider.dart';
import 'package:open_wearable/widgets/app_toast.dart';
import 'package:open_wearable/widgets/sensors/sensor_page_spacing.dart';
import 'package:open_wearable/widgets/sensors/configuration/sensor_configuration_device_row.dart';
import 'package:provider/provider.dart';

import '../../../models/logger.dart';

/// A view that displays the sensor configurations of all connected wearables.
///
/// The specific sensor configurations should be made available via the [SensorConfigurationProvider].
class SensorConfigurationView extends StatelessWidget {
  final VoidCallback? onSetConfigPressed;

  const SensorConfigurationView({super.key, this.onSetConfigPressed});

  @override
  Widget build(BuildContext context) {
    return Consumer<WearablesProvider>(
      builder: (context, wearablesProvider, child) {
        return _buildSmallScreenLayout(context, wearablesProvider);
      },
    );
  }

  Widget _buildSmallScreenLayout(
    BuildContext context,
    WearablesProvider wearablesProvider,
  ) {
    if (wearablesProvider.wearables.isEmpty) {
      return Center(
        child: PlatformText(
          "No devices connected",
          style: Theme.of(context).textTheme.titleLarge,
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
        final groups = _orderGroupsForConfigure(
          snapshot.data ??
              wearablesProvider.wearables
                  .map(
                    (wearable) =>
                        WearableDisplayGroup.single(wearable: wearable),
                  )
                  .toList(),
        );
        final applyTargets = _buildApplyTargets(
          groups: groups,
          wearablesProvider: wearablesProvider,
        );
        final sections = <Widget>[
          ...groups.map(
            (group) => _buildGroupConfigurationRow(
              group: group,
              wearablesProvider: wearablesProvider,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: _buildApplyConfigButton(
              context,
              targets: applyTargets,
            ),
          ),
          _buildThroughputWarningBanner(context),
        ];

        return ListView(
          padding: SensorPageSpacing.pagePadding,
          children: sections,
        );
      },
    );
  }

  List<WearableDisplayGroup> _orderGroupsForConfigure(
    List<WearableDisplayGroup> groups,
  ) {
    final indexed = groups.asMap().entries.toList();

    indexed.sort((a, b) {
      final groupA = a.value;
      final groupB = b.value;
      final sameName =
          groupA.displayName.toLowerCase() == groupB.displayName.toLowerCase();
      final bothSingle = !groupA.isCombined && !groupB.isCombined;
      if (sameName && bothSingle) {
        final sideOrderA = _configureSideOrder(groupA.primaryPosition);
        final sideOrderB = _configureSideOrder(groupB.primaryPosition);
        final knownSides = sideOrderA <= 1 && sideOrderB <= 1;
        if (knownSides && sideOrderA != sideOrderB) {
          return sideOrderA.compareTo(sideOrderB);
        }
      }

      // Preserve existing order for all other rows.
      return a.key.compareTo(b.key);
    });

    return indexed.map((entry) => entry.value).toList();
  }

  int _configureSideOrder(DevicePosition? position) {
    if (position == DevicePosition.left) {
      return 0;
    }
    if (position == DevicePosition.right) {
      return 1;
    }
    return 2;
  }

  Widget _buildGroupConfigurationRow({
    required WearableDisplayGroup group,
    required WearablesProvider wearablesProvider,
  }) {
    final primary = _resolvePrimaryForConfiguration(group);
    final secondary = _resolveMirroredDevice(group, primary);
    final storageScope = _storageScopeForGroup(group);
    final supportsConfig = primary.hasCapability<SensorConfigurationManager>();

    if (!supportsConfig) {
      return SensorConfigurationDeviceRow(
        device: primary,
        pairedDevice: secondary,
        displayName: group.displayName,
        storageScope: storageScope,
      );
    }

    return ChangeNotifierProvider<SensorConfigurationProvider>.value(
      value: wearablesProvider.getSensorConfigurationProvider(primary),
      child: SensorConfigurationDeviceRow(
        device: primary,
        pairedDevice: secondary,
        displayName: group.displayName,
        storageScope: storageScope,
      ),
    );
  }

  String _storageScopeForGroup(WearableDisplayGroup group) {
    if (!group.isCombined) {
      return 'device_${group.representative.deviceId}';
    }

    final ids = group.members.map((device) => device.deviceId).toList()..sort();
    return 'stereo_${ids.join('_')}';
  }

  List<_ConfigApplyTarget> _buildApplyTargets({
    required List<WearableDisplayGroup> groups,
    required WearablesProvider wearablesProvider,
  }) {
    final targets = <_ConfigApplyTarget>[];
    for (final group in groups) {
      final primary = _resolvePrimaryForConfiguration(group);
      if (!primary.hasCapability<SensorConfigurationManager>()) {
        continue;
      }

      final partner = _resolveMirroredDevice(group, primary);
      final mirrorTarget =
          partner != null && partner.hasCapability<SensorConfigurationManager>()
              ? partner
              : null;

      targets.add(
        _ConfigApplyTarget(
          primaryDevice: primary,
          mirroredDevice: mirrorTarget,
          provider: wearablesProvider.getSensorConfigurationProvider(primary),
        ),
      );
    }
    return targets;
  }

  Wearable _resolvePrimaryForConfiguration(WearableDisplayGroup group) {
    if (group.isCombined) {
      for (final member in group.members) {
        if (member.hasCapability<SensorConfigurationManager>()) {
          return member;
        }
      }
    }
    return group.representative;
  }

  Wearable? _resolveMirroredDevice(
    WearableDisplayGroup group,
    Wearable primary,
  ) {
    if (!group.isCombined) {
      return null;
    }
    for (final member in group.members) {
      if (member.deviceId != primary.deviceId) {
        return member;
      }
    }
    return null;
  }

  Widget _buildApplyConfigButton(
    BuildContext context, {
    required List<_ConfigApplyTarget> targets,
  }) {
    return PlatformElevatedButton(
      onPressed: () async {
        if (targets.isEmpty) {
          await showPlatformDialog<void>(
            context: context,
            builder: (dialogContext) => PlatformAlertDialog(
              title: PlatformText('No configurable devices'),
              content: PlatformText(
                'Connect a wearable with configurable sensors to apply settings.',
              ),
              actions: [
                PlatformDialogAction(
                  child: PlatformText('OK'),
                  onPressed: () => Navigator.of(dialogContext).pop(),
                ),
              ],
            ),
          );
          return;
        }

        int appliedCount = 0;
        int mirroredCount = 0;
        int mirrorSkippedCount = 0;

        for (final target in targets) {
          logger.d(
            "Setting sensor configurations for ${target.primaryDevice.name}",
          );

          for (final entry in target.provider.getSelectedConfigurations()) {
            final SensorConfiguration config = entry.$1;
            final SensorConfigurationValue value = entry.$2;
            config.setConfiguration(value);
            appliedCount += 1;

            final mirroredDevice = target.mirroredDevice;
            if (mirroredDevice != null) {
              final mirrored = _applyConfigurationToDevice(
                mirroredDevice: mirroredDevice,
                configName: config.name,
                valueKey: value.key,
              );
              if (mirrored) {
                mirroredCount += 1;
              } else {
                mirrorSkippedCount += 1;
              }
            }
          }
        }

        final message = StringBuffer(
          'Applied $appliedCount sensor settings.',
        );
        if (mirroredCount > 0) {
          message.write(' Mirrored $mirroredCount settings to paired devices.');
        }
        if (mirrorSkippedCount > 0) {
          message.write(
            ' $mirrorSkippedCount mirrored settings were unavailable on partner firmware.',
          );
        }

        AppToast.show(
          context,
          message: message.toString(),
          type: mirrorSkippedCount > 0
              ? AppToastType.warning
              : AppToastType.success,
          icon: mirrorSkippedCount > 0
              ? Icons.rule_rounded
              : Icons.check_circle_outline_rounded,
        );

        (onSetConfigPressed ?? () {})();
      },
      child: PlatformText('Apply Profiles'),
    );
  }

  Widget _buildThroughputWarningBanner(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.insights_outlined,
                  size: 20,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Sampling & bandwidth guidance',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'High sensor counts and aggressive sampling rates can exceed bandwidth and cause dropped samples.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 10),
            _buildGuidanceItem(
              context,
              'Enable only the sensors needed for this session.',
            ),
            _buildGuidanceItem(
              context,
              'Lower sampling rates for non-critical signals.',
            ),
            _buildGuidanceItem(
              context,
              'For high-rate recordings, recording to the on-board memory of the device is preferred (if available).',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGuidanceItem(BuildContext context, String text) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(
              Icons.check_circle_outline,
              size: 16,
              color: colorScheme.primary.withValues(alpha: 0.9),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }

  bool _applyConfigurationToDevice({
    required Wearable mirroredDevice,
    required String configName,
    required String valueKey,
  }) {
    if (!mirroredDevice.hasCapability<SensorConfigurationManager>()) {
      return false;
    }

    final manager =
        mirroredDevice.requireCapability<SensorConfigurationManager>();
    SensorConfiguration? mirroredConfig;
    for (final config in manager.sensorConfigurations) {
      if (config.name == configName) {
        mirroredConfig = config;
        break;
      }
    }
    if (mirroredConfig == null) {
      return false;
    }

    SensorConfigurationValue? mirroredValue;
    for (final value in mirroredConfig.values) {
      if (value.key == valueKey) {
        mirroredValue = value;
        break;
      }
    }
    if (mirroredValue == null) {
      return false;
    }

    mirroredConfig.setConfiguration(mirroredValue);
    return true;
  }

  // ignore: unused_element
  Widget _buildLargeScreenLayout(
    BuildContext context,
    WearablesProvider wearablesProvider,
  ) {
    final List<Wearable> devices = wearablesProvider.wearables;
    List<StaggeredGridTile> tiles =
        _generateTiles(devices, wearablesProvider.sensorConfigurationProviders);
    if (tiles.isNotEmpty) {
      tiles.addAll(
        [
          StaggeredGridTile.extent(
            crossAxisCellCount: 1,
            mainAxisExtent: 100.0,
            child: _buildApplyConfigButton(
              context,
              targets: devices
                  .where(
                    (device) =>
                        device.hasCapability<SensorConfigurationManager>(),
                  )
                  .map(
                    (device) => _ConfigApplyTarget(
                      primaryDevice: device,
                      mirroredDevice: null,
                      provider: wearablesProvider
                          .getSensorConfigurationProvider(device),
                    ),
                  )
                  .toList(),
            ),
          ),
          StaggeredGridTile.extent(
            crossAxisCellCount: 1,
            mainAxisExtent: 230.0,
            child: _buildThroughputWarningBanner(context),
          ),
        ],
      );
    }

    return StaggeredGrid.count(
      crossAxisCount: (MediaQuery.of(context).size.width / 250)
          .floor()
          .clamp(1, 4), // Adaptive grid
      mainAxisSpacing: SensorPageSpacing.gridGap,
      crossAxisSpacing: SensorPageSpacing.gridGap,
      children: tiles.isNotEmpty
          ? tiles
          : [
              StaggeredGridTile.extent(
                crossAxisCellCount: 1,
                mainAxisExtent: 100.0,
                child: Card(
                  shape: RoundedRectangleBorder(
                    side: BorderSide(
                      color: Colors.grey,
                      width: 1,
                      style: BorderStyle.solid,
                      strokeAlign: -1,
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: PlatformText(
                      "No devices connected",
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                ),
              ),
            ],
    );
  }

  /// Generates a dynamic quilted grid layout based on the device properties
  List<StaggeredGridTile> _generateTiles(
    List<Wearable> devices,
    Map<Wearable, SensorConfigurationProvider> notifiers,
  ) {
    // Sort devices by size dynamically for a balanced layout
    devices.sort(
      (a, b) => _getGridSpanForDevice(b) - _getGridSpanForDevice(a),
    );

    return devices.map((device) {
      int span = _getGridSpanForDevice(device);

      return StaggeredGridTile.extent(
        crossAxisCellCount: 1, // Dynamic width
        mainAxisExtent: span * 100.0, // Dynamic height based on content
        child: ChangeNotifierProvider<SensorConfigurationProvider>.value(
          value: notifiers[device]!,
          child: SensorConfigurationDeviceRow(device: device),
        ),
      );
    }).toList();
  }

  /// Determines how many columns a device should span
  int _getGridSpanForDevice(Wearable device) {
    if (!device.hasCapability<SensorConfigurationManager>()) {
      return 1; // Default size
    }

    int sensorConfigCount = device
        .requireCapability<SensorConfigurationManager>()
        .sensorConfigurations
        .length;

    return sensorConfigCount.clamp(1, 4);
  }
}

class _ConfigApplyTarget {
  final Wearable primaryDevice;
  final Wearable? mirroredDevice;
  final SensorConfigurationProvider provider;

  const _ConfigApplyTarget({
    required this.primaryDevice,
    required this.mirroredDevice,
    required this.provider,
  });
}
