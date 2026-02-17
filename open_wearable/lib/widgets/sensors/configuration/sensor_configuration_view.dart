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
        final groups = orderWearableGroupsByNameAndSide(
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
          padding: SensorPageSpacing.pagePaddingWithBottomInset(context),
          children: sections,
        );
      },
    );
  }

  Widget _buildGroupConfigurationRow({
    required WearableDisplayGroup group,
    required WearablesProvider wearablesProvider,
  }) {
    final primary = _resolvePrimaryForConfiguration(group);
    final secondary = _resolveMirroredDevice(group, primary);
    final pairedProvider = secondary != null &&
            secondary.hasCapability<SensorConfigurationManager>()
        ? _tryGetSensorConfigurationProvider(
            wearablesProvider: wearablesProvider,
            wearable: secondary,
          )
        : null;
    final storageScope = _storageScopeForGroup(group);
    final rowKey = ValueKey(
      _configurationRowIdentity(
        group: group,
        primary: primary,
        secondary: secondary,
      ),
    );
    final supportsConfig = primary.hasCapability<SensorConfigurationManager>();

    if (!supportsConfig) {
      return SensorConfigurationDeviceRow(
        key: rowKey,
        device: primary,
        pairedDevice: secondary,
        pairedProvider: pairedProvider,
        displayName: group.displayName,
        storageScope: storageScope,
      );
    }

    return ChangeNotifierProvider<SensorConfigurationProvider>.value(
      value: wearablesProvider.getSensorConfigurationProvider(primary),
      child: SensorConfigurationDeviceRow(
        key: rowKey,
        device: primary,
        pairedDevice: secondary,
        pairedProvider: pairedProvider,
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

  String _configurationRowIdentity({
    required WearableDisplayGroup group,
    required Wearable primary,
    required Wearable? secondary,
  }) {
    if (!group.isCombined) {
      return 'single:${primary.deviceId}';
    }

    final pairKey = group.stereoPairKey ??
        WearableDisplayGroup.stereoPairKeyForIds(
          primary.deviceId,
          secondary?.deviceId ?? '',
        );
    return 'pair:$pairKey:primary:${primary.deviceId}:secondary:${secondary?.deviceId ?? 'none'}';
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
      final mirrorProvider = mirrorTarget == null
          ? null
          : _tryGetSensorConfigurationProvider(
              wearablesProvider: wearablesProvider,
              wearable: mirrorTarget,
            );

      targets.add(
        _ConfigApplyTarget(
          primaryDevice: primary,
          mirroredDevice: mirrorTarget,
          mirroredProvider: mirrorProvider,
          provider: wearablesProvider.getSensorConfigurationProvider(primary),
        ),
      );
    }
    return targets;
  }

  SensorConfigurationProvider? _tryGetSensorConfigurationProvider({
    required WearablesProvider wearablesProvider,
    required Wearable wearable,
  }) {
    try {
      return wearablesProvider.getSensorConfigurationProvider(wearable);
    } catch (_) {
      return null;
    }
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
      onPressed: () => _applyConfigurations(context, targets: targets),
      child: PlatformText('Apply Profiles'),
    );
  }

  Future<void> _applyConfigurations(
    BuildContext context, {
    required List<_ConfigApplyTarget> targets,
  }) async {
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

    int actionableCount = 0;

    for (final target in targets) {
      final primaryEntriesToApply = _entriesToApplyForProvider(target.provider);
      final mirroredEntriesToApply = _entriesToApplyForMirroredTarget(target);
      if (primaryEntriesToApply.isEmpty && mirroredEntriesToApply.isEmpty) {
        continue;
      }

      actionableCount +=
          primaryEntriesToApply.length + mirroredEntriesToApply.length;
      for (final entry in primaryEntriesToApply) {
        final SensorConfiguration config = entry.$1;
        final SensorConfigurationValue value = entry.$2;
        // Always push the selected canonical value to the primary device on
        // apply. This also heals primary-side drift/unknown states.
        config.setConfiguration(value);
      }

      for (final entry in mirroredEntriesToApply) {
        final SensorConfiguration config = entry.$1;
        final SensorConfigurationValue value = entry.$2;
        config.setConfiguration(value);
      }

      logger.d(
        "Applied ${primaryEntriesToApply.length} primary and ${mirroredEntriesToApply.length} mirrored sensor settings for ${target.primaryDevice.name}",
      );
    }

    if (actionableCount == 0) {
      AppToast.show(
        context,
        message: 'No pending sensor settings to apply.',
        type: AppToastType.info,
        icon: Icons.info_outline_rounded,
      );
      return;
    }

    AppToast.show(
      context,
      message: 'Sensor settings applied.',
      type: AppToastType.success,
      icon: Icons.check_circle_outline_rounded,
    );

    (onSetConfigPressed ?? () {})();
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

  List<(SensorConfiguration, SensorConfigurationValue)>
      _entriesToApplyForMirroredTarget(
    _ConfigApplyTarget target,
  ) {
    final mirroredDevice = target.mirroredDevice;
    final mirroredProvider = target.mirroredProvider;
    if (mirroredDevice == null || mirroredProvider == null) {
      return const <(SensorConfiguration, SensorConfigurationValue)>[];
    }
    if (!mirroredDevice.hasCapability<SensorConfigurationManager>()) {
      return const <(SensorConfiguration, SensorConfigurationValue)>[];
    }
    return _entriesToApplyForProvider(mirroredProvider);
  }

  List<(SensorConfiguration, SensorConfigurationValue)>
      _entriesToApplyForProvider(
    SensorConfigurationProvider provider,
  ) {
    return _mergeConfigurationEntries(
      provider.getSelectedConfigurations(pendingOnly: true),
      provider.getConfigurationsMissingFromLastReport(),
    );
  }

  List<(SensorConfiguration, SensorConfigurationValue)>
      _mergeConfigurationEntries(
    List<(SensorConfiguration, SensorConfigurationValue)> first,
    List<(SensorConfiguration, SensorConfigurationValue)> second,
  ) {
    final merged = <(SensorConfiguration, SensorConfigurationValue)>[];
    final seen = <String>{};

    for (final entry in first) {
      if (seen.add(_configurationIdentityKey(entry.$1))) {
        merged.add(entry);
      }
    }
    for (final entry in second) {
      if (seen.add(_configurationIdentityKey(entry.$1))) {
        merged.add(entry);
      }
    }
    return merged;
  }

  String _configurationIdentityKey(SensorConfiguration configuration) {
    final dynamic configDynamic = configuration;
    try {
      final sensorId = configDynamic.sensorId;
      if (sensorId is int) {
        return 'sensor:$sensorId';
      }
    } catch (_) {
      // Fall through to structural key.
    }

    final valuesKey = configuration.values
        .map((value) => value.key)
        .toList(growable: false)
      ..sort();
    return '${configuration.runtimeType}:${configuration.name}:${valuesKey.join('|')}';
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
                      mirroredProvider: null,
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
  final SensorConfigurationProvider? mirroredProvider;
  final SensorConfigurationProvider provider;

  const _ConfigApplyTarget({
    required this.primaryDevice,
    required this.mirroredDevice,
    required this.mirroredProvider,
    required this.provider,
  });
}
