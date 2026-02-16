import 'package:flutter/foundation.dart' show setEquals;
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
          padding: SensorPageSpacing.pagePaddingWithBottomInset(context),
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
    final pairedProvider =
        secondary != null && secondary.hasCapability<SensorConfigurationManager>()
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

    int appliedCount = 0;
    int mirroredCount = 0;
    int mirrorSkippedCount = 0;
    int actionableCount = 0;

    for (final target in targets) {
      final pendingEntries =
          target.provider.getSelectedConfigurations(pendingOnly: true);
      final missingFromReportEntries =
          target.provider.getConfigurationsMissingFromLastReport();
      final pairSyncEntries = _collectPairSyncEntries(target);
      final entriesToApply = _mergeConfigurationEntries(
        pendingEntries,
        _mergeConfigurationEntries(
          missingFromReportEntries,
          pairSyncEntries,
        ),
      );
      if (entriesToApply.isEmpty) {
        continue;
      }

      actionableCount += entriesToApply.length;
      logger.d(
        "Setting sensor configurations for ${target.primaryDevice.name}",
      );

      for (final entry in entriesToApply) {
        final SensorConfiguration config = entry.$1;
        final SensorConfigurationValue value = entry.$2;
        // Always push the selected canonical value to the primary device on
        // apply. This also heals primary-side drift/unknown states.
        config.setConfiguration(value);
        appliedCount += 1;

        final mirroredDevice = target.mirroredDevice;
        if (mirroredDevice != null) {
          final mirrored = _applyConfigurationToDevice(
            mirroredDevice: mirroredDevice,
            sourceConfig: config,
            sourceValue: value,
          );
          if (mirrored) {
            mirroredCount += 1;
          } else {
            mirrorSkippedCount += 1;
          }
        }
      }

      // Pending entries are cleared by SensorConfigurationProvider once the
      // device reports back the applied value. Keeping them pending here
      // avoids transient drift while paired devices settle.
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
      type:
          mirrorSkippedCount > 0 ? AppToastType.warning : AppToastType.success,
      icon: mirrorSkippedCount > 0
          ? Icons.rule_rounded
          : Icons.check_circle_outline_rounded,
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

  bool _applyConfigurationToDevice({
    required Wearable mirroredDevice,
    required SensorConfiguration sourceConfig,
    required SensorConfigurationValue sourceValue,
  }) {
    if (!mirroredDevice.hasCapability<SensorConfigurationManager>()) {
      return false;
    }

    final manager =
        mirroredDevice.requireCapability<SensorConfigurationManager>();
    final mirroredConfig = _findMirroredConfiguration(
      manager: manager,
      sourceConfig: sourceConfig,
    );
    if (mirroredConfig == null) {
      return false;
    }

    final mirroredValue = _findMirroredValue(
      mirroredConfig: mirroredConfig,
      sourceValue: sourceValue,
    );
    if (mirroredValue == null) {
      return false;
    }

    mirroredConfig.setConfiguration(mirroredValue);
    return true;
  }

  List<(SensorConfiguration, SensorConfigurationValue)> _collectPairSyncEntries(
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

    final manager =
        mirroredDevice.requireCapability<SensorConfigurationManager>();
    final result = <(SensorConfiguration, SensorConfigurationValue)>[];
    for (final entry in target.provider.getSelectedConfigurations()) {
      final sourceConfig = entry.$1;
      final sourceValue = entry.$2;
      final mirroredConfig = _findMirroredConfiguration(
        manager: manager,
        sourceConfig: sourceConfig,
      );
      if (mirroredConfig == null) {
        continue;
      }

      final mirroredValue = _findMirroredValue(
        mirroredConfig: mirroredConfig,
        sourceValue: sourceValue,
      );
      if (mirroredValue == null) {
        continue;
      }

      final selectedMirroredValue =
          mirroredProvider.getSelectedConfigurationValue(mirroredConfig);
      if (_configurationValuesMatch(selectedMirroredValue, mirroredValue)) {
        continue;
      }
      result.add(entry);
    }

    return result;
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

  SensorConfiguration? _findMirroredConfiguration({
    required SensorConfigurationManager manager,
    required SensorConfiguration sourceConfig,
  }) {
    for (final candidate in manager.sensorConfigurations) {
      if (candidate.name == sourceConfig.name) {
        return candidate;
      }
    }

    final normalizedSource = _normalizeName(sourceConfig.name);
    for (final candidate in manager.sensorConfigurations) {
      if (_normalizeName(candidate.name) == normalizedSource) {
        return candidate;
      }
    }
    return null;
  }

  SensorConfigurationValue? _findMirroredValue({
    required SensorConfiguration mirroredConfig,
    required SensorConfigurationValue sourceValue,
  }) {
    for (final candidate in mirroredConfig.values) {
      if (candidate.key == sourceValue.key) {
        return candidate;
      }
    }

    if (sourceValue is SensorFrequencyConfigurationValue) {
      final sourceOptions = _optionNameSet(sourceValue);
      final candidates = mirroredConfig.values
          .whereType<SensorFrequencyConfigurationValue>()
          .toList(growable: false);
      if (candidates.isNotEmpty) {
        final sameOptionCandidates = candidates
            .where(
              (candidate) =>
                  setEquals(_optionNameSet(candidate), sourceOptions),
            )
            .toList(growable: false);
        final scoped =
            sameOptionCandidates.isNotEmpty ? sameOptionCandidates : candidates;
        SensorFrequencyConfigurationValue? best;
        double? bestDistance;
        for (final candidate in scoped) {
          final distance =
              (candidate.frequencyHz - sourceValue.frequencyHz).abs();
          if (best == null || distance < bestDistance!) {
            best = candidate;
            bestDistance = distance;
          }
        }
        if (best != null) {
          return best;
        }
      }
    }

    if (sourceValue is ConfigurableSensorConfigurationValue) {
      final sourceWithoutOptions = sourceValue.withoutOptions();
      final sourceOptions = _optionNameSet(sourceValue);
      for (final candidate in mirroredConfig.values
          .whereType<ConfigurableSensorConfigurationValue>()) {
        if (!setEquals(_optionNameSet(candidate), sourceOptions)) {
          continue;
        }
        if (candidate.withoutOptions().key == sourceWithoutOptions.key) {
          return candidate;
        }
      }
    }

    final normalizedKey = _normalizeName(sourceValue.key);
    for (final candidate in mirroredConfig.values) {
      if (_normalizeName(candidate.key) == normalizedKey) {
        return candidate;
      }
    }
    return null;
  }

  Set<String> _optionNameSet(SensorConfigurationValue value) {
    if (value is! ConfigurableSensorConfigurationValue) {
      return const <String>{};
    }
    return value.options.map((option) => _normalizeName(option.name)).toSet();
  }

  String _normalizeName(String value) => value.trim().toLowerCase();

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

  bool _configurationValuesMatch(
    SensorConfigurationValue? current,
    SensorConfigurationValue expected,
  ) {
    if (current == null) {
      return false;
    }

    if (current is SensorFrequencyConfigurationValue &&
        expected is SensorFrequencyConfigurationValue) {
      return current.frequencyHz == expected.frequencyHz &&
          setEquals(_optionNameSet(current), _optionNameSet(expected));
    }

    if (current is ConfigurableSensorConfigurationValue &&
        expected is ConfigurableSensorConfigurationValue) {
      return _normalizeName(current.withoutOptions().key) ==
              _normalizeName(expected.withoutOptions().key) &&
          setEquals(_optionNameSet(current), _optionNameSet(expected));
    }

    if (current.key == expected.key) {
      return true;
    }
    return _normalizeName(current.key) == _normalizeName(expected.key);
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
