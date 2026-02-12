import 'package:flutter/foundation.dart' show setEquals;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart';
import 'package:open_wearable/models/device_name_formatter.dart';
import 'package:open_wearable/view_models/sensor_configuration_storage.dart';
import 'package:open_wearable/widgets/app_toast.dart';
import 'package:open_wearable/widgets/devices/stereo_position_badge.dart';
import 'package:open_wearable/widgets/sensors/configuration/edge_recorder_prefix_row.dart';
import 'package:open_wearable/widgets/sensors/configuration/save_config_row.dart';
import 'package:open_wearable/widgets/sensors/configuration/sensor_config_option_icon_factory.dart';
import 'package:open_wearable/widgets/sensors/configuration/sensor_configuration_value_row.dart';
import 'package:provider/provider.dart';

import '../../../view_models/sensor_configuration_provider.dart';

/// A widget that displays and manages sensor configuration for a single device.
class SensorConfigurationDeviceRow extends StatefulWidget {
  final Wearable device;
  final Wearable? pairedDevice;
  final SensorConfigurationProvider? pairedProvider;
  final String? displayName;
  final String? storageScope;

  const SensorConfigurationDeviceRow({
    super.key,
    required this.device,
    this.pairedDevice,
    this.pairedProvider,
    this.displayName,
    this.storageScope,
  });

  @override
  State<SensorConfigurationDeviceRow> createState() =>
      _SensorConfigurationDeviceRowState();
}

class _SensorConfigurationDeviceRowState
    extends State<SensorConfigurationDeviceRow>
    with SingleTickerProviderStateMixin {
  static const String _builtInOffProfileKey = '__builtin_off_profile__';
  static const String _builtInOffProfileTitle = 'Off';

  late final TabController _tabController;
  late Future<DeviceProfileScopeMatch> _profileScopeMatchFuture;
  List<Widget> _content = const [];
  final Map<String, Future<Map<String, String>>> _profileConfigFutures = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_onTabChanged);
    _profileScopeMatchFuture = _resolveProfileScopeMatch();
    _content = const [Center(child: CircularProgressIndicator())];
    _updateContent();
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant SensorConfigurationDeviceRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    final deviceChanged = oldWidget.device.deviceId != widget.device.deviceId;
    final pairedDeviceChanged =
        oldWidget.pairedDevice?.deviceId != widget.pairedDevice?.deviceId;
    final pairedProviderChanged =
        oldWidget.pairedProvider != widget.pairedProvider;
    final displayNameChanged = oldWidget.displayName != widget.displayName;
    final scopeChanged = oldWidget.storageScope != widget.storageScope;
    if (deviceChanged ||
        pairedDeviceChanged ||
        pairedProviderChanged ||
        displayNameChanged ||
        scopeChanged) {
      _profileConfigFutures.clear();
      _profileScopeMatchFuture = _resolveProfileScopeMatch();
      _updateContent();
    }
  }

  @override
  Widget build(BuildContext context) {
    final device = widget.device;
    final tabBar = _buildTabBar(context);
    final isCombinedPair = widget.pairedDevice != null;
    final title = widget.displayName ?? formatWearableDisplayName(device.name);

    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        fit: FlexFit.loose,
                        child: PlatformText(
                          title,
                          style:
                              Theme.of(context).textTheme.bodyLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isCombinedPair)
                        const Padding(
                          padding: EdgeInsets.only(left: 8),
                          child: _CombinedStereoBadge(),
                        )
                      else if (device.hasCapability<StereoDevice>())
                        Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: StereoPositionBadge(
                            device: device.requireCapability<StereoDevice>(),
                          ),
                        ),
                    ],
                  ),
                ),
                if (tabBar != null) ...[
                  const SizedBox(width: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    widthFactor: 1,
                    child: tabBar,
                  ),
                ],
              ],
            ),
          ),
          if (isCombinedPair)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
              child: Text(
                'Settings are applied to both paired devices.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ),
          ..._content,
        ],
      ),
    );
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging) {
      _updateContent();
    }
  }

  Future<DeviceProfileScopeMatch> _resolveProfileScopeMatch() async {
    final explicitScope = widget.storageScope?.trim();
    if (explicitScope != null && explicitScope.isNotEmpty) {
      return DeviceProfileScopeMatch(
        nameScope: explicitScope,
        firmwareScope: null,
      );
    }

    final firmwareVersion =
        await _readFirmwareVersionForProfiles(widget.device);
    return DeviceProfileScopeMatch.forDevice(
      deviceName: _profileDeviceName(),
      firmwareVersion: firmwareVersion,
    );
  }

  String _profileDeviceName() {
    final name =
        widget.displayName ?? formatWearableDisplayName(widget.device.name);
    final trimmed = name.trim();
    return trimmed.isEmpty ? widget.device.name : trimmed;
  }

  Future<String?> _readFirmwareVersionForProfiles(Wearable wearable) async {
    if (!wearable.hasCapability<DeviceFirmwareVersion>()) {
      return null;
    }
    try {
      final version = await wearable
          .requireCapability<DeviceFirmwareVersion>()
          .readDeviceFirmwareVersion()
          .timeout(const Duration(seconds: 2));
      return SensorConfigurationStorage.normalizeFirmwareVersionForScope(
        version,
      );
    } catch (_) {
      return null;
    }
  }

  Future<DeviceProfileScopeMatch> _readCurrentScopeMatch() async {
    final future = _profileScopeMatchFuture;
    final match = await future;
    return match;
  }

  bool _isBuiltInProfileKey(String key) => key == _builtInOffProfileKey;

  Future<Map<String, String>> _loadProfileConfiguration(String key) async {
    if (_isBuiltInProfileKey(key)) {
      return _buildBuiltInOffProfileConfig(widget.device);
    }
    return SensorConfigurationStorage.loadConfiguration(key);
  }

  Map<String, String> _buildBuiltInOffProfileConfig(Wearable device) {
    if (!device.hasCapability<SensorConfigurationManager>()) {
      return const <String, String>{};
    }

    final manager = device.requireCapability<SensorConfigurationManager>();
    final config = <String, String>{};
    for (final sensorConfig in manager.sensorConfigurations) {
      final offValue = _resolveBuiltInOffValue(sensorConfig);
      if (offValue != null) {
        config[sensorConfig.name] = offValue.key;
      }
    }
    return config;
  }

  SensorConfigurationValue? _resolveBuiltInOffValue(
    SensorConfiguration sensorConfig,
  ) {
    final offValue = sensorConfig.offValue;
    if (sensorConfig is ConfigurableSensorConfiguration) {
      final configurableValues = sensorConfig.values
          .whereType<ConfigurableSensorConfigurationValue>()
          .toList(growable: false);

      if (offValue is ConfigurableSensorConfigurationValue) {
        for (final candidate in configurableValues) {
          if (_normalizeName(candidate.withoutOptions().key) ==
                  _normalizeName(offValue.withoutOptions().key) &&
              candidate.options.isEmpty) {
            return candidate;
          }
        }
      }

      final withoutTargets = configurableValues
          .where((candidate) => candidate.options.isEmpty)
          .toList(growable: false);
      if (withoutTargets.isNotEmpty) {
        final frequencyCandidates =
            withoutTargets.whereType<SensorFrequencyConfigurationValue>();
        if (frequencyCandidates.isNotEmpty) {
          var best = frequencyCandidates.first;
          for (final candidate in frequencyCandidates.skip(1)) {
            if (candidate.frequencyHz < best.frequencyHz) {
              best = candidate;
            }
          }
          return best;
        }
        return withoutTargets.first;
      }
    }

    if (offValue != null) {
      return offValue;
    }

    if (sensorConfig.values.isEmpty) {
      return null;
    }

    final frequencyValues =
        sensorConfig.values.whereType<SensorFrequencyConfigurationValue>();
    if (frequencyValues.isNotEmpty) {
      var best = frequencyValues.first;
      for (final candidate in frequencyValues.skip(1)) {
        if (candidate.frequencyHz < best.frequencyHz) {
          best = candidate;
        }
      }
      return best;
    }

    return sensorConfig.values.first;
  }

  Future<bool> _ensureProfileKeyMatchesCurrentDevice({
    required String key,
    required String profileTitle,
  }) async {
    if (_isBuiltInProfileKey(key)) {
      return true;
    }
    final scopeMatch = await _readCurrentScopeMatch();
    if (scopeMatch.allowsKey(key)) {
      return true;
    }
    if (!mounted) {
      return false;
    }

    await showPlatformDialog<void>(
      context: context,
      builder: (dialogContext) => PlatformAlertDialog(
        title: const Text('Profile mismatch'),
        content: Text(
          'Profile "$profileTitle" no longer matches this device name/firmware and cannot be used.',
        ),
        actions: [
          PlatformDialogAction(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );

    _refreshProfiles();
    return false;
  }

  Future<void> _updateContent() async {
    final device = widget.device;

    if (!device.hasCapability<SensorConfigurationManager>()) {
      if (!mounted) return;
      setState(() {
        _content = [
          const Padding(
            padding: EdgeInsets.all(12),
            child: Text('This device does not support sensor configuration.'),
          ),
        ];
      });
      return;
    }

    if (_tabController.index == 0) {
      _buildSettingsTabContent(device);
    } else {
      await _buildProfilesTabContent();
    }
  }

  void _buildSettingsTabContent(Wearable device) {
    final sensorManager =
        device.requireCapability<SensorConfigurationManager>();
    final pairedManager = widget.pairedDevice != null &&
            widget.pairedProvider != null &&
            widget.pairedDevice!.hasCapability<SensorConfigurationManager>()
        ? widget.pairedDevice!.requireCapability<SensorConfigurationManager>()
        : null;

    final content = <Widget>[
      ...sensorManager.sensorConfigurations.map(
        (config) => SensorConfigurationValueRow(
          sensorConfiguration: config,
          pairedSensorConfiguration: pairedManager == null
              ? null
              : _findMirroredConfiguration(
                  manager: pairedManager,
                  sourceConfig: config,
                ),
          pairedProvider: widget.pairedProvider,
        ),
      ),
    ];

    if (device.hasCapability<EdgeRecorderManager>()) {
      content.addAll([
        const _InsetSectionDivider(),
        EdgeRecorderPrefixRow(
          manager: device.requireCapability<EdgeRecorderManager>(),
        ),
      ]);
    }

    if (!mounted) return;
    setState(() {
      _content = content;
    });
  }

  Future<void> _buildProfilesTabContent() async {
    if (!mounted) return;
    setState(() {
      _content = const [Center(child: CircularProgressIndicator())];
    });

    final scopeFuture = _profileScopeMatchFuture;
    final scopeMatch = await scopeFuture;
    if (!mounted || !identical(scopeFuture, _profileScopeMatchFuture)) {
      return;
    }

    List<String> allConfigKeys;
    try {
      allConfigKeys = await SensorConfigurationStorage.listConfigurationKeys()
          .timeout(const Duration(seconds: 8));
    } catch (error, stackTrace) {
      debugPrint(
        'Failed to load sensor profiles for ${scopeMatch.saveScope}: '
        '$error\n$stackTrace',
      );
      if (!mounted) return;
      setState(() {
        _content = [
          SaveConfigRow(
            storageScope: scopeMatch.saveScope,
            uniqueNameScope: scopeMatch.nameScope,
            reservedProfileNames: const {_builtInOffProfileTitle},
            reservedProfilesByName: {
              _builtInOffProfileTitle: _buildBuiltInOffProfileConfig(
                widget.device,
              ),
            },
            onSaved: _refreshProfiles,
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.all(12),
            child: Text(
              'Could not load saved profiles. Please try again.',
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: _refreshProfiles,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
              ),
            ),
          ),
        ];
      });
      return;
    }
    final scopedKeys = allConfigKeys.where(scopeMatch.matchesScopedKey).toList()
      ..sort();
    final legacyKeys = allConfigKeys
        .where(SensorConfigurationStorage.isLegacyUnscopedKey)
        .toList()
      ..sort();
    final profileKeys = [
      ...scopedKeys.where((key) => key != _builtInOffProfileKey),
      ...legacyKeys.where((key) => key != _builtInOffProfileKey),
      _builtInOffProfileKey,
    ];

    if (!mounted) return;

    final content = <Widget>[
      SaveConfigRow(
        storageScope: scopeMatch.saveScope,
        uniqueNameScope: scopeMatch.nameScope,
        reservedProfileNames: const {_builtInOffProfileTitle},
        reservedProfilesByName: {
          _builtInOffProfileTitle: _buildBuiltInOffProfileConfig(
            widget.device,
          ),
        },
        onSaved: _refreshProfiles,
      ),
      const Divider(),
    ];

    if (profileKeys.isEmpty) {
      content.add(
        const Padding(
          padding: EdgeInsets.all(12),
          child: Text(
            'No profiles saved yet. Save current settings above, then tap a profile to load as current.',
          ),
        ),
      );
    } else {
      content.addAll(
        profileKeys.map(
          (key) => _buildProfileTile(
            key,
            scopeMatch: scopeMatch,
          ),
        ),
      );
    }

    setState(() {
      _content = content;
    });
  }

  Widget _buildProfileTile(
    String key, {
    required DeviceProfileScopeMatch scopeMatch,
  }) {
    final isBuiltIn = _isBuiltInProfileKey(key);
    final matchedScope = scopeMatch.matchingScopeForKey(key);
    final isDeviceScoped = isBuiltIn || matchedScope != null;

    final title = switch ((isBuiltIn, matchedScope)) {
      (true, _) => _builtInOffProfileTitle,
      (false, final scope?) =>
        SensorConfigurationStorage.displayNameFromScopedKey(
          key,
          scope: scope,
        ),
      _ => key,
    };

    return Consumer<SensorConfigurationProvider>(
      builder: (context, provider, _) {
        return FutureBuilder<Map<String, String>>(
          future: _profileConfigFutures.putIfAbsent(
            key,
            () => _loadProfileConfiguration(key),
          ),
          builder: (context, snapshot) {
            final profileConfig = snapshot.data;
            final state = _resolveProfileApplicationState(
              provider: provider,
              pairedProvider: widget.pairedProvider,
              profileConfig: profileConfig,
            );
            final colorScheme = Theme.of(context).colorScheme;
            const appliedGreen = Color(0xFF2E7D32);
            final stateColor = switch (state) {
              _ProfileApplicationState.none => colorScheme.onSurface,
              _ProfileApplicationState.selected => colorScheme.primary,
              _ProfileApplicationState.applied => appliedGreen,
              _ProfileApplicationState.mixed => colorScheme.error,
            };
            final titleStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: state == _ProfileApplicationState.none
                      ? FontWeight.w500
                      : FontWeight.w700,
                  color: state == _ProfileApplicationState.none
                      ? null
                      : stateColor,
                );
            final tileDecoration = switch (state) {
              _ProfileApplicationState.selected => null,
              _ProfileApplicationState.applied => null,
              _ProfileApplicationState.mixed => null,
              _ProfileApplicationState.none => null,
            };

            final subtitle = switch (state) {
              _ProfileApplicationState.selected => 'Selected, not applied',
              _ProfileApplicationState.applied => widget.pairedProvider == null
                  ? 'Applied on device'
                  : 'Applied on both devices',
              _ProfileApplicationState.mixed =>
                'Mixed state across paired devices',
              _ProfileApplicationState.none => isBuiltIn
                  ? 'Built-in default profile'
                  : isDeviceScoped
                      ? 'Tap to load as current'
                      : 'Legacy shared profile',
            };

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: DecoratedBox(
                decoration: tileDecoration ?? const BoxDecoration(),
                child: PlatformListTile(
                  leading: Icon(
                    Icons.view_list_rounded,
                    color: state == _ProfileApplicationState.none
                        ? colorScheme.onSurfaceVariant
                        : stateColor,
                  ),
                  title: PlatformText(
                    title,
                    style: titleStyle,
                  ),
                  subtitle: PlatformText(subtitle),
                  onTap: () => _loadProfile(key: key, title: title),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (state != _ProfileApplicationState.none)
                        _ProfileApplicationBadge(state: state),
                      PlatformIconButton(
                        icon: const Icon(Icons.more_horiz),
                        onPressed: () => _showProfileActions(
                          key: key,
                          title: title,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  _ProfileApplicationState _resolveProfileApplicationState({
    required SensorConfigurationProvider provider,
    required SensorConfigurationProvider? pairedProvider,
    required Map<String, String>? profileConfig,
  }) {
    if (profileConfig == null || profileConfig.isEmpty) {
      return _ProfileApplicationState.none;
    }

    final primaryState = _resolveSingleDeviceProfileState(
      device: widget.device,
      provider: provider,
      expectedConfig: profileConfig,
    );

    final pairedDevice = widget.pairedDevice;
    if (pairedDevice == null || pairedProvider == null) {
      return primaryState;
    }

    final mirroredProfile = _buildMirroredProfileConfig(
      sourceDevice: widget.device,
      targetDevice: pairedDevice,
      sourceProfileConfig: profileConfig,
    );
    if (mirroredProfile == null || mirroredProfile.isEmpty) {
      return _ProfileApplicationState.mixed;
    }

    final secondaryState = _resolveSingleDeviceProfileState(
      device: pairedDevice,
      provider: pairedProvider,
      expectedConfig: mirroredProfile,
    );

    if (primaryState == _ProfileApplicationState.none &&
        secondaryState == _ProfileApplicationState.none) {
      return _ProfileApplicationState.none;
    }
    if (primaryState == secondaryState) {
      return primaryState;
    }
    return _ProfileApplicationState.mixed;
  }

  _ProfileApplicationState _resolveSingleDeviceProfileState({
    required Wearable device,
    required SensorConfigurationProvider provider,
    required Map<String, String> expectedConfig,
  }) {
    if (!device.hasCapability<SensorConfigurationManager>()) {
      return _ProfileApplicationState.none;
    }

    final manager = device.requireCapability<SensorConfigurationManager>();
    var allSelected = true;
    var allApplied = provider.hasReceivedConfigurationReport;
    for (final entry in expectedConfig.entries) {
      final config = _findConfigurationByName(
        manager: manager,
        configName: entry.key,
      );
      if (config == null) {
        return _ProfileApplicationState.none;
      }

      final expectedValue = _findConfigurationValueByKey(
        config: config,
        valueKey: entry.value,
      );
      if (expectedValue == null) {
        return _ProfileApplicationState.none;
      }

      if (!provider.selectedMatchesConfigurationValue(config, expectedValue)) {
        allSelected = false;
      }

      if (allApplied) {
        final reportedValue =
            provider.getLastReportedConfigurationValue(config);
        if (reportedValue == null ||
            !_configurationValuesMatch(reportedValue, expectedValue)) {
          allApplied = false;
        }
      } else {
        allApplied = false;
      }
    }

    if (allApplied) {
      return _ProfileApplicationState.applied;
    }
    if (allSelected) {
      return _ProfileApplicationState.selected;
    }
    return _ProfileApplicationState.none;
  }

  Map<String, String>? _buildMirroredProfileConfig({
    required Wearable sourceDevice,
    required Wearable targetDevice,
    required Map<String, String> sourceProfileConfig,
  }) {
    if (!sourceDevice.hasCapability<SensorConfigurationManager>() ||
        !targetDevice.hasCapability<SensorConfigurationManager>()) {
      return null;
    }

    final sourceManager =
        sourceDevice.requireCapability<SensorConfigurationManager>();
    final targetManager =
        targetDevice.requireCapability<SensorConfigurationManager>();
    final mirrored = <String, String>{};

    for (final entry in sourceProfileConfig.entries) {
      final sourceConfig = _findConfigurationByName(
        manager: sourceManager,
        configName: entry.key,
      );
      if (sourceConfig == null) {
        continue;
      }
      final sourceValue = _findConfigurationValueByKey(
        config: sourceConfig,
        valueKey: entry.value,
      );
      if (sourceValue == null) {
        continue;
      }

      final mirroredConfig = _findMirroredConfiguration(
        manager: targetManager,
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
      mirrored[mirroredConfig.name] = mirroredValue.key;
    }

    return mirrored;
  }

  Widget? _buildTabBar(BuildContext context) {
    if (!widget.device.hasCapability<SensorConfigurationManager>()) return null;

    return TabBar.secondary(
      controller: _tabController,
      isScrollable: true,
      tabAlignment: TabAlignment.start,
      padding: EdgeInsets.zero,
      dividerHeight: 1,
      labelPadding: const EdgeInsets.symmetric(horizontal: 8),
      tabs: const [
        Tab(text: 'Current'),
        Tab(text: 'Profiles'),
      ],
    );
  }

  Future<void> _loadProfile({
    required String key,
    required String title,
  }) async {
    final keyMatches = await _ensureProfileKeyMatchesCurrentDevice(
      key: key,
      profileTitle: title,
    );
    if (!keyMatches || !mounted) {
      return;
    }

    final config = await _loadProfileConfiguration(key);
    if (!mounted) return;

    final provider = context.read<SensorConfigurationProvider>();
    final result = await provider.restoreFromJson(config);
    SensorConfigurationRestoreResult? pairedResult;
    final pairedProvider = widget.pairedProvider;
    final pairedDevice = widget.pairedDevice;
    if (pairedProvider != null && pairedDevice != null) {
      final mirroredConfig = _isBuiltInProfileKey(key)
          ? _buildBuiltInOffProfileConfig(pairedDevice)
          : _buildMirroredProfileConfig(
              sourceDevice: widget.device,
              targetDevice: pairedDevice,
              sourceProfileConfig: config,
            );
      if (mirroredConfig != null && mirroredConfig.isNotEmpty) {
        pairedResult = await pairedProvider.restoreFromJson(mirroredConfig);
      }
    }
    if (!mounted) return;

    final hasPrimaryValues = result.hasRestoredValues;
    final hasPairedValues =
        pairedResult == null || pairedResult.hasRestoredValues;
    if (!hasPrimaryValues || !hasPairedValues) {
      await showPlatformDialog<void>(
        context: context,
        builder: (dialogContext) => PlatformAlertDialog(
          title: const Text('Profile error'),
          content: Text(
            pairedResult == null
                ? 'No compatible values from "$title" could be restored for this device.'
                : 'Profile "$title" could not be restored on both paired devices.',
          ),
          actions: [
            PlatformDialogAction(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    final pairedSkipped = (pairedResult?.skippedCount ?? 0) +
        (pairedResult?.unknownConfigCount ?? 0);
    if (result.skippedCount > 0 ||
        result.unknownConfigCount > 0 ||
        pairedSkipped > 0) {
      final skippedTotal =
          result.skippedCount + result.unknownConfigCount + pairedSkipped;
      _showSnackBar(
        'Loaded "$title" (${result.restoredCount + (pairedResult?.restoredCount ?? 0)} restored, $skippedTotal skipped). Tap "Apply Profiles" to push.',
        type: AppToastType.warning,
        icon: Icons.rule_rounded,
      );
    } else {
      _showSnackBar(
        'Loaded profile "$title". Tap "Apply Profiles" at the bottom to push to hardware.',
        type: AppToastType.info,
        icon: Icons.download_done_rounded,
      );
    }

    _tabController.index = 0;
    _updateContent();
  }

  Future<void> _overwriteProfile({
    required String key,
    required String title,
  }) async {
    if (_isBuiltInProfileKey(key)) {
      _showSnackBar(
        'Built-in profile "$title" cannot be overwritten.',
        type: AppToastType.info,
        icon: Icons.info_outline_rounded,
      );
      return;
    }

    final keyMatches = await _ensureProfileKeyMatchesCurrentDevice(
      key: key,
      profileTitle: title,
    );
    if (!keyMatches || !mounted) {
      return;
    }

    final confirmed = await _confirmOverwrite(title);
    if (!confirmed) return;
    if (!mounted) return;

    final provider = context.read<SensorConfigurationProvider>();
    await SensorConfigurationStorage.saveConfiguration(key, provider.toJson());
    if (!mounted) return;
    _profileConfigFutures.remove(key);
    _showSnackBar(
      'Updated profile "$title" with current settings.',
      type: AppToastType.success,
      icon: Icons.check_circle_outline_rounded,
    );
    _updateContent();
  }

  Future<void> _deleteProfile({
    required String key,
    required String title,
  }) async {
    if (_isBuiltInProfileKey(key)) {
      _showSnackBar(
        'Built-in profile "$title" cannot be deleted.',
        type: AppToastType.info,
        icon: Icons.lock_outline_rounded,
      );
      return;
    }

    final keyMatches = await _ensureProfileKeyMatchesCurrentDevice(
      key: key,
      profileTitle: title,
    );
    if (!keyMatches) {
      return;
    }

    final confirmed = await _confirmDelete(title);
    if (!confirmed) return;

    await SensorConfigurationStorage.deleteConfiguration(key);
    if (!mounted) return;
    _profileConfigFutures.remove(key);
    _showSnackBar(
      'Deleted profile "$title".',
      type: AppToastType.success,
      icon: Icons.delete_outline_rounded,
    );
    _updateContent();
  }

  void _showProfileActions({
    required String key,
    required String title,
  }) {
    final isBuiltIn = _isBuiltInProfileKey(key);
    showPlatformModalSheet<void>(
      context: context,
      builder: (sheetContext) => PlatformWidget(
        material: (_, __) => SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text('View details'),
                onTap: () async {
                  Navigator.of(sheetContext).pop();
                  await _viewProfileDetails(key: key, title: title);
                },
              ),
              ListTile(
                leading: const Icon(Icons.download),
                title: const Text('Load'),
                onTap: () async {
                  Navigator.of(sheetContext).pop();
                  await _loadProfile(key: key, title: title);
                },
              ),
              if (!isBuiltIn)
                ListTile(
                  leading: const Icon(Icons.save),
                  title: const Text('Overwrite with current settings'),
                  onTap: () async {
                    Navigator.of(sheetContext).pop();
                    await _overwriteProfile(key: key, title: title);
                  },
                ),
              if (!isBuiltIn)
                ListTile(
                  leading: const Icon(Icons.delete),
                  title: const Text('Delete'),
                  onTap: () async {
                    Navigator.of(sheetContext).pop();
                    await _deleteProfile(key: key, title: title);
                  },
                ),
            ],
          ),
        ),
        cupertino: (_, __) => CupertinoActionSheet(
          title: Text(title),
          actions: [
            CupertinoActionSheetAction(
              onPressed: () async {
                Navigator.of(sheetContext).pop();
                await _viewProfileDetails(key: key, title: title);
              },
              child: const Text('View details'),
            ),
            CupertinoActionSheetAction(
              onPressed: () async {
                Navigator.of(sheetContext).pop();
                await _loadProfile(key: key, title: title);
              },
              child: const Text('Load'),
            ),
            if (!isBuiltIn)
              CupertinoActionSheetAction(
                onPressed: () async {
                  Navigator.of(sheetContext).pop();
                  await _overwriteProfile(key: key, title: title);
                },
                child: const Text('Overwrite with current settings'),
              ),
            if (!isBuiltIn)
              CupertinoActionSheetAction(
                isDestructiveAction: true,
                onPressed: () async {
                  Navigator.of(sheetContext).pop();
                  await _deleteProfile(key: key, title: title);
                },
                child: const Text('Delete'),
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

  Future<void> _viewProfileDetails({
    required String key,
    required String title,
  }) async {
    final keyMatches = await _ensureProfileKeyMatchesCurrentDevice(
      key: key,
      profileTitle: title,
    );
    if (!keyMatches || !mounted) {
      return;
    }

    final profileConfig = await _loadProfileConfiguration(key);
    if (!mounted) return;

    if (!widget.device.hasCapability<SensorConfigurationManager>()) {
      _showSnackBar(
        'Profile details are unavailable for this device.',
        type: AppToastType.warning,
        icon: Icons.info_outline_rounded,
      );
      return;
    }

    final primaryProvider = context.read<SensorConfigurationProvider>();
    final sensorManager =
        widget.device.requireCapability<SensorConfigurationManager>();
    final pairedDevice = widget.pairedDevice;
    final pairedProvider = widget.pairedProvider;
    final pairedManager = pairedDevice != null &&
            pairedDevice.hasCapability<SensorConfigurationManager>()
        ? pairedDevice.requireCapability<SensorConfigurationManager>()
        : null;

    final details = profileConfig.entries.map((entry) {
      final sourceConfig = _findConfigurationByName(
        manager: sensorManager,
        configName: entry.key,
      );
      if (sourceConfig == null) {
        return _ProfileDetailEntry(
          configName: entry.key,
          status: _ProfileDetailStatus.unavailable,
          detailText: 'Configuration not available on this device.',
        );
      }

      final sourceValue = _findConfigurationValueByKey(
        config: sourceConfig,
        valueKey: entry.value,
      );
      if (sourceValue == null) {
        return _ProfileDetailEntry(
          configName: entry.key,
          status: _ProfileDetailStatus.unavailable,
          detailText: 'Saved value is not available on this firmware.',
        );
      }

      if (pairedManager != null && pairedProvider != null) {
        return _buildPairedProfileDetailEntry(
          configName: entry.key,
          primaryConfig: sourceConfig,
          primaryProfileValue: sourceValue,
          primaryProvider: primaryProvider,
          pairedManager: pairedManager,
          pairedProvider: pairedProvider,
        );
      }

      return _buildSingleProfileDetailEntry(
        configName: entry.key,
        sensorConfig: sourceConfig,
        profileValue: sourceValue,
        provider: primaryProvider,
      );
    }).toList()
      ..sort((a, b) => a.configName.compareTo(b.configName));

    await showPlatformModalSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: SizedBox(
          height: MediaQuery.of(sheetContext).size.height * 0.82,
          child: Material(
            color: Theme.of(sheetContext).colorScheme.surface,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: Theme.of(sheetContext)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        tooltip: 'Close',
                        onPressed: () => Navigator.of(sheetContext).pop(),
                        icon: const Icon(Icons.close_rounded, size: 20),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: details.isEmpty
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: Text('This profile has no saved settings.'),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
                          itemCount: details.length,
                          itemBuilder: (context, index) => _ProfileDetailCard(
                            entry: details[index],
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  _ProfileDetailEntry _buildSingleProfileDetailEntry({
    required String configName,
    required SensorConfiguration sensorConfig,
    required SensorConfigurationValue profileValue,
    required SensorConfigurationProvider provider,
  }) {
    final resolved = _describeSensorConfigurationValue(profileValue);
    final selectedMatches =
        provider.selectedMatchesConfigurationValue(sensorConfig, profileValue);
    final applied =
        selectedMatches && provider.isConfigurationApplied(sensorConfig);
    final status = switch ((selectedMatches, applied)) {
      (true, true) => _ProfileDetailStatus.applied,
      (true, false) => _ProfileDetailStatus.selected,
      _ => _ProfileDetailStatus.notSelected,
    };

    return _ProfileDetailEntry(
      configName: configName,
      status: status,
      samplingLabel: resolved.samplingLabel,
      dataTargetOptions: resolved.dataTargetOptions,
      detailText: status == _ProfileDetailStatus.notSelected
          ? 'Current setting differs from this profile.'
          : null,
    );
  }

  _ProfileDetailEntry _buildPairedProfileDetailEntry({
    required String configName,
    required SensorConfiguration primaryConfig,
    required SensorConfigurationValue primaryProfileValue,
    required SensorConfigurationProvider primaryProvider,
    required SensorConfigurationManager pairedManager,
    required SensorConfigurationProvider pairedProvider,
  }) {
    final resolved = _describeSensorConfigurationValue(primaryProfileValue);
    final mirroredConfig = _findMirroredConfiguration(
      manager: pairedManager,
      sourceConfig: primaryConfig,
    );
    if (mirroredConfig == null) {
      return _ProfileDetailEntry(
        configName: configName,
        status: _ProfileDetailStatus.mixed,
        detailText: 'Configuration is unavailable on the paired device.',
      );
    }

    final mirroredProfileValue = _findMirroredValue(
      mirroredConfig: mirroredConfig,
      sourceValue: primaryProfileValue,
    );
    if (mirroredProfileValue == null) {
      return _ProfileDetailEntry(
        configName: configName,
        status: _ProfileDetailStatus.mixed,
        detailText: 'Saved value is unavailable on the paired device.',
      );
    }

    final primarySnapshot = _buildDeviceConfigSnapshot(
      provider: primaryProvider,
      config: primaryConfig,
      expectedValue: primaryProfileValue,
    );
    final secondarySnapshot = _buildDeviceConfigSnapshot(
      provider: pairedProvider,
      config: mirroredConfig,
      expectedValue: mirroredProfileValue,
    );

    final statesMatch = primarySnapshot.state == secondarySnapshot.state;
    final selectedValuesMatch = _configurationValuesMatchNullable(
      primarySnapshot.selectedValue,
      secondarySnapshot.selectedValue,
    );

    if (!statesMatch || !selectedValuesMatch) {
      return _ProfileDetailEntry(
        configName: configName,
        status: _ProfileDetailStatus.mixed,
        detailText:
            'Paired devices differ in selected/apply state, sampling rate, or data targets.',
      );
    }

    final status = switch (primarySnapshot.state) {
      _DeviceProfileConfigState.applied => _ProfileDetailStatus.applied,
      _DeviceProfileConfigState.selected => _ProfileDetailStatus.selected,
      _DeviceProfileConfigState.notSelected => _ProfileDetailStatus.notSelected,
      _DeviceProfileConfigState.unavailable => _ProfileDetailStatus.unavailable,
    };

    return _ProfileDetailEntry(
      configName: configName,
      status: status,
      samplingLabel: resolved.samplingLabel,
      dataTargetOptions: resolved.dataTargetOptions,
      detailText: status == _ProfileDetailStatus.notSelected
          ? 'Current paired setting differs from this profile.'
          : null,
    );
  }

  _DeviceConfigSnapshot _buildDeviceConfigSnapshot({
    required SensorConfigurationProvider provider,
    required SensorConfiguration config,
    required SensorConfigurationValue expectedValue,
  }) {
    final selectedValue = provider.getSelectedConfigurationValue(config);
    if (selectedValue == null) {
      return const _DeviceConfigSnapshot(
        state: _DeviceProfileConfigState.notSelected,
        selectedValue: null,
      );
    }

    if (!provider.selectedMatchesConfigurationValue(config, expectedValue)) {
      return _DeviceConfigSnapshot(
        state: _DeviceProfileConfigState.notSelected,
        selectedValue: selectedValue,
      );
    }

    if (provider.isConfigurationApplied(config)) {
      return _DeviceConfigSnapshot(
        state: _DeviceProfileConfigState.applied,
        selectedValue: selectedValue,
      );
    }

    return _DeviceConfigSnapshot(
      state: _DeviceProfileConfigState.selected,
      selectedValue: selectedValue,
    );
  }

  _ResolvedProfileValue _describeSensorConfigurationValue(
    SensorConfigurationValue value,
  ) {
    final baseValue = value is SensorFrequencyConfigurationValue
        ? _formatFrequency(value.frequencyHz)
        : value.key;

    if (value is! ConfigurableSensorConfigurationValue) {
      return _ResolvedProfileValue(
        samplingLabel: baseValue,
        dataTargetOptions: const [],
      );
    }

    final dataTargets =
        value.options.where(_isDataTargetOption).toSet().toList(growable: false)
          ..sort(
            (a, b) => _normalizeName(a.name).compareTo(_normalizeName(b.name)),
          );

    return _ResolvedProfileValue(
      samplingLabel: dataTargets.isEmpty ? 'Off' : baseValue,
      dataTargetOptions: dataTargets,
    );
  }

  String _formatFrequency(double hz) {
    if ((hz - hz.roundToDouble()).abs() < 0.01) {
      return '${hz.round()} Hz';
    }
    if (hz >= 10) {
      return '${hz.toStringAsFixed(1)} Hz';
    }
    return '${hz.toStringAsFixed(2)} Hz';
  }

  bool _isDataTargetOption(SensorConfigurationOption option) {
    return option is StreamSensorConfigOption ||
        option is RecordSensorConfigOption;
  }

  SensorConfiguration? _findConfigurationByName({
    required SensorConfigurationManager manager,
    required String configName,
  }) {
    for (final config in manager.sensorConfigurations) {
      if (config.name == configName) {
        return config;
      }
    }

    final normalized = _normalizeName(configName);
    for (final config in manager.sensorConfigurations) {
      if (_normalizeName(config.name) == normalized) {
        return config;
      }
    }
    return null;
  }

  SensorConfigurationValue? _findConfigurationValueByKey({
    required SensorConfiguration config,
    required String valueKey,
  }) {
    for (final value in config.values) {
      if (value.key == valueKey) {
        return value;
      }
    }

    final normalized = _normalizeName(valueKey);
    for (final value in config.values) {
      if (_normalizeName(value.key) == normalized) {
        return value;
      }
    }
    return null;
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
      if (_normalizeName(candidate.key) == _normalizeName(sourceValue.key)) {
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
        if (_normalizeName(candidate.withoutOptions().key) ==
            _normalizeName(sourceWithoutOptions.key)) {
          return candidate;
        }
      }
    }

    return null;
  }

  bool _configurationValuesMatchNullable(
    SensorConfigurationValue? left,
    SensorConfigurationValue? right,
  ) {
    if (left == null || right == null) {
      return left == null && right == null;
    }
    return _configurationValuesMatch(left, right);
  }

  bool _configurationValuesMatch(
    SensorConfigurationValue left,
    SensorConfigurationValue right,
  ) {
    if (left is SensorFrequencyConfigurationValue &&
        right is SensorFrequencyConfigurationValue) {
      return left.frequencyHz == right.frequencyHz &&
          setEquals(_optionNameSet(left), _optionNameSet(right));
    }

    if (left is ConfigurableSensorConfigurationValue &&
        right is ConfigurableSensorConfigurationValue) {
      return _normalizeName(left.withoutOptions().key) ==
              _normalizeName(right.withoutOptions().key) &&
          setEquals(_optionNameSet(left), _optionNameSet(right));
    }

    return _normalizeName(left.key) == _normalizeName(right.key);
  }

  Set<String> _optionNameSet(SensorConfigurationValue value) {
    if (value is! ConfigurableSensorConfigurationValue) {
      return const <String>{};
    }
    return value.options.map((option) => _normalizeName(option.name)).toSet();
  }

  String _normalizeName(String value) => value.trim().toLowerCase();

  Future<bool> _confirmDelete(String title) async {
    final bool? confirmed = await showPlatformDialog<bool>(
      context: context,
      builder: (dialogContext) => PlatformAlertDialog(
        title: const Text('Delete profile?'),
        content: Text('Delete "$title" permanently?'),
        actions: [
          PlatformDialogAction(
            child: const Text('Cancel'),
            onPressed: () => Navigator.of(dialogContext).pop(false),
          ),
          PlatformDialogAction(
            child: const Text('Delete'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  Future<bool> _confirmOverwrite(String title) async {
    final bool? confirmed = await showPlatformDialog<bool>(
      context: context,
      builder: (dialogContext) => PlatformAlertDialog(
        title: const Text('Overwrite profile?'),
        content: Text(
          'Replace profile "$title" with current settings from this device?',
        ),
        actions: [
          PlatformDialogAction(
            child: const Text('Cancel'),
            onPressed: () => Navigator.of(dialogContext).pop(false),
          ),
          PlatformDialogAction(
            child: const Text('Overwrite'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  void _refreshProfiles() {
    _profileConfigFutures.clear();
    _updateContent();
  }

  void _showSnackBar(
    String message, {
    AppToastType type = AppToastType.info,
    IconData? icon,
  }) {
    AppToast.show(
      context,
      message: message,
      type: type,
      icon: icon,
    );
  }
}

enum _ProfileApplicationState {
  none,
  selected,
  applied,
  mixed,
}

class _ProfileApplicationBadge extends StatelessWidget {
  final _ProfileApplicationState state;

  const _ProfileApplicationBadge({
    required this.state,
  });

  @override
  Widget build(BuildContext context) {
    const appliedGreen = Color(0xFF2E7D32);
    final colorScheme = Theme.of(context).colorScheme;
    final (label, foreground, background, border) = switch (state) {
      _ProfileApplicationState.selected => (
          'Selected',
          colorScheme.primary,
          colorScheme.primary.withValues(alpha: 0.10),
          colorScheme.primary.withValues(alpha: 0.30),
        ),
      _ProfileApplicationState.applied => (
          'Applied',
          appliedGreen,
          appliedGreen.withValues(alpha: 0.12),
          appliedGreen.withValues(alpha: 0.34),
        ),
      _ProfileApplicationState.mixed => (
          'Mixed',
          colorScheme.error,
          colorScheme.error.withValues(alpha: 0.12),
          colorScheme.error.withValues(alpha: 0.34),
        ),
      _ProfileApplicationState.none => (
          '',
          colorScheme.onSurfaceVariant,
          Colors.transparent,
          Colors.transparent,
        ),
    };

    if (state == _ProfileApplicationState.none) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(right: 2),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: foreground,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

enum _ProfileDetailStatus {
  notSelected,
  selected,
  applied,
  mixed,
  unavailable,
}

enum _DeviceProfileConfigState {
  notSelected,
  selected,
  applied,
  unavailable,
}

class _DeviceConfigSnapshot {
  final _DeviceProfileConfigState state;
  final SensorConfigurationValue? selectedValue;

  const _DeviceConfigSnapshot({
    required this.state,
    required this.selectedValue,
  });
}

class _ProfileDetailEntry {
  final String configName;
  final _ProfileDetailStatus status;
  final String? samplingLabel;
  final List<SensorConfigurationOption> dataTargetOptions;
  final String? detailText;

  const _ProfileDetailEntry({
    required this.configName,
    required this.status,
    this.samplingLabel,
    this.dataTargetOptions = const [],
    this.detailText,
  });
}

class _ResolvedProfileValue {
  final String samplingLabel;
  final List<SensorConfigurationOption> dataTargetOptions;

  const _ResolvedProfileValue({
    required this.samplingLabel,
    required this.dataTargetOptions,
  });
}

class _ProfileDetailCard extends StatelessWidget {
  final _ProfileDetailEntry entry;

  const _ProfileDetailCard({
    required this.entry,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final neutralAccent = colorScheme.onSurfaceVariant;
    final indicatorColor = colorScheme.outlineVariant.withValues(alpha: 0.72);
    final icon = switch (entry.status) {
      _ProfileDetailStatus.mixed => Icons.sync_problem_rounded,
      _ProfileDetailStatus.unavailable => Icons.warning_amber_outlined,
      _ => Icons.sensors_rounded,
    };
    final showMixedBubble = entry.status == _ProfileDetailStatus.mixed;
    final showValueBubbles =
        !showMixedBubble && entry.status != _ProfileDetailStatus.unavailable;
    final showHelperText = entry.detailText != null &&
        (entry.status == _ProfileDetailStatus.notSelected ||
            entry.status == _ProfileDetailStatus.mixed ||
            entry.status == _ProfileDetailStatus.unavailable);
    final titleColor = colorScheme.onSurface;

    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 8),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 2,
              height: 30,
              decoration: BoxDecoration(
                color: indicatorColor,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(width: 6),
            Icon(
              icon,
              size: 15,
              color: neutralAccent,
            ),
            const SizedBox(width: 7),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Text(
                          entry.configName,
                          maxLines: 1,
                          softWrap: false,
                          overflow: TextOverflow.ellipsis,
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: titleColor,
                                    fontWeight: FontWeight.w700,
                                  ),
                        ),
                      ),
                      if (showMixedBubble) ...[
                        const SizedBox(width: 8),
                        const _ProfileMixedStateBubble(),
                      ] else if (showValueBubbles &&
                          entry.dataTargetOptions.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        _ProfileOptionsCompactBadge(
                          options: entry.dataTargetOptions,
                          accentColor: neutralAccent,
                        ),
                      ],
                      if (showValueBubbles && entry.samplingLabel != null) ...[
                        const SizedBox(width: 8),
                        _ProfileSamplingRatePill(
                          label: entry.samplingLabel!,
                          foreground: neutralAccent,
                        ),
                      ],
                    ],
                  ),
                  if (showHelperText) ...[
                    const SizedBox(height: 2),
                    Text(
                      entry.detailText!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileOptionsCompactBadge extends StatelessWidget {
  final List<SensorConfigurationOption> options;
  final Color accentColor;

  const _ProfileOptionsCompactBadge({
    required this.options,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final visibleCount = options.length > 2 ? 2 : options.length;
    final remainingCount = options.length - visibleCount;

    return SizedBox(
      height: 22,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: accentColor.withValues(alpha: 0.38),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < visibleCount; i++) ...[
              Icon(
                getSensorConfigurationOptionIcon(options[i]) ??
                    Icons.tune_rounded,
                size: 10,
                color: accentColor,
              ),
              if (i < visibleCount - 1) const SizedBox(width: 3),
            ],
            if (remainingCount > 0) ...[
              const SizedBox(width: 4),
              Text(
                '+$remainingCount',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: accentColor,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ProfileSamplingRatePill extends StatelessWidget {
  final String label;
  final Color foreground;

  const _ProfileSamplingRatePill({
    required this.label,
    required this.foreground,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SizedBox(
      height: 22,
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 7),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: foreground.withValues(alpha: 0.42),
          ),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 38),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: foreground,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
      ),
    );
  }
}

class _ProfileMixedStateBubble extends StatelessWidget {
  const _ProfileMixedStateBubble();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: 22,
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.82),
          ),
        ),
        child: Text(
          'Mixed',
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
        ),
      ),
    );
  }
}

class _CombinedStereoBadge extends StatelessWidget {
  const _CombinedStereoBadge();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final foregroundColor = colorScheme.primary;
    final backgroundColor = foregroundColor.withValues(alpha: 0.12);
    final borderColor = foregroundColor.withValues(alpha: 0.24);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: borderColor),
      ),
      child: Text(
        'L+R',
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: foregroundColor,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.1,
            ),
      ),
    );
  }
}

class _InsetSectionDivider extends StatelessWidget {
  const _InsetSectionDivider();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Divider(
        height: 1,
        thickness: 0.6,
        color: Theme.of(context).colorScheme.outlineVariant.withValues(
              alpha: 0.55,
            ),
      ),
    );
  }
}
