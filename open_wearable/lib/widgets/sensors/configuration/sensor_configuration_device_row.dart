import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart';
import 'package:open_wearable/models/device_name_formatter.dart';
import 'package:open_wearable/view_models/sensor_configuration_storage.dart';
import 'package:open_wearable/view_models/sensor_profile_service.dart';
import 'package:open_wearable/widgets/app_toast.dart';
import 'package:open_wearable/widgets/devices/stereo_position_badge.dart';
import 'package:open_wearable/widgets/sensors/configuration/edge_recorder_prefix_row.dart';
import 'package:open_wearable/widgets/sensors/configuration/save_config_row.dart';
import 'package:open_wearable/widgets/sensors/configuration/sensor_configuration_profile_widgets.dart';
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
                          child: CombinedStereoBadge(),
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
          if (SensorProfileService.normalizeName(
                    candidate.withoutOptions().key,
                  ) ==
                  SensorProfileService.normalizeName(
                    offValue.withoutOptions().key,
                  ) &&
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
              : SensorProfileService.findMirroredConfiguration(
                  manager: pairedManager,
                  sourceConfig: config,
                ),
          pairedProvider: widget.pairedProvider,
        ),
      ),
    ];

    if (device.hasCapability<EdgeRecorderManager>()) {
      content.addAll([
        const InsetSectionDivider(),
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
            final state = SensorProfileService.resolveProfileApplicationState(
              primaryDevice: widget.device,
              primaryProvider: provider,
              pairedProvider: widget.pairedProvider,
              pairedDevice: widget.pairedDevice,
              profileConfig: profileConfig,
            );
            final colorScheme = Theme.of(context).colorScheme;
            const appliedGreen = Color(0xFF2E7D32);
            final stateColor = switch (state) {
              ProfileApplicationState.none => colorScheme.onSurface,
              ProfileApplicationState.selected => colorScheme.primary,
              ProfileApplicationState.applied => appliedGreen,
              ProfileApplicationState.mixed => colorScheme.error,
            };
            final titleStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: state == ProfileApplicationState.none
                      ? FontWeight.w500
                      : FontWeight.w700,
                  color:
                      state == ProfileApplicationState.none ? null : stateColor,
                );
            final tileDecoration = switch (state) {
              ProfileApplicationState.selected => null,
              ProfileApplicationState.applied => null,
              ProfileApplicationState.mixed => null,
              ProfileApplicationState.none => null,
            };

            final subtitle = switch (state) {
              ProfileApplicationState.selected => 'Selected, not applied',
              ProfileApplicationState.applied => widget.pairedProvider == null
                  ? 'Applied on device'
                  : 'Applied on both devices',
              ProfileApplicationState.mixed =>
                'Mixed state across paired devices',
              ProfileApplicationState.none => isBuiltIn
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
                    color: state == ProfileApplicationState.none
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
                      if (state != ProfileApplicationState.none)
                        ProfileApplicationBadge(state: state),
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
          : SensorProfileService.buildMirroredProfileConfig(
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
    final actions = _buildProfileActions(
      key: key,
      title: title,
      isBuiltIn: isBuiltIn,
    );
    showPlatformModalSheet<void>(
      context: context,
      builder: (sheetContext) => PlatformWidget(
        material: (_, __) => SafeArea(
          child: Wrap(
            children: [
              for (final action in actions)
                ListTile(
                  leading: Icon(action.icon),
                  title: Text(action.label),
                  onTap: () => _runProfileActionFromSheet(
                    sheetContext: sheetContext,
                    action: action,
                  ),
                ),
            ],
          ),
        ),
        cupertino: (_, __) => CupertinoActionSheet(
          title: Text(title),
          actions: [
            for (final action in actions)
              CupertinoActionSheetAction(
                isDestructiveAction: action.isDestructive,
                onPressed: () => _runProfileActionFromSheet(
                  sheetContext: sheetContext,
                  action: action,
                ),
                child: Text(action.label),
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

  List<_ProfileActionItem> _buildProfileActions({
    required String key,
    required String title,
    required bool isBuiltIn,
  }) {
    return [
      _ProfileActionItem(
        label: 'View details',
        icon: Icons.info_outline,
        onPressed: () => _viewProfileDetails(key: key, title: title),
      ),
      _ProfileActionItem(
        label: 'Load',
        icon: Icons.download,
        onPressed: () => _loadProfile(key: key, title: title),
      ),
      if (!isBuiltIn)
        _ProfileActionItem(
          label: 'Overwrite with current settings',
          icon: Icons.save,
          onPressed: () => _overwriteProfile(key: key, title: title),
        ),
      if (!isBuiltIn)
        _ProfileActionItem(
          label: 'Delete',
          icon: Icons.delete,
          isDestructive: true,
          onPressed: () => _deleteProfile(key: key, title: title),
        ),
    ];
  }

  Future<void> _runProfileActionFromSheet({
    required BuildContext sheetContext,
    required _ProfileActionItem action,
  }) async {
    Navigator.of(sheetContext).pop();
    await action.onPressed();
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
      final sourceConfig = SensorProfileService.findConfigurationByName(
        manager: sensorManager,
        configName: entry.key,
      );
      if (sourceConfig == null) {
        return ProfileDetailEntry(
          configName: entry.key,
          status: ProfileDetailStatus.unavailable,
          detailText: 'Configuration not available on this device.',
        );
      }

      final sourceValue = SensorProfileService.findConfigurationValueByKey(
        config: sourceConfig,
        valueKey: entry.value,
      );
      if (sourceValue == null) {
        return ProfileDetailEntry(
          configName: entry.key,
          status: ProfileDetailStatus.unavailable,
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
                          itemBuilder: (context, index) => ProfileDetailCard(
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

  ProfileDetailEntry _buildSingleProfileDetailEntry({
    required String configName,
    required SensorConfiguration sensorConfig,
    required SensorConfigurationValue profileValue,
    required SensorConfigurationProvider provider,
  }) {
    final resolved =
        SensorProfileService.describeSensorConfigurationValue(profileValue);
    final selectedMatches =
        provider.selectedMatchesConfigurationValue(sensorConfig, profileValue);
    final applied =
        selectedMatches && provider.isConfigurationApplied(sensorConfig);
    final status = switch ((selectedMatches, applied)) {
      (true, true) => ProfileDetailStatus.applied,
      (true, false) => ProfileDetailStatus.selected,
      _ => ProfileDetailStatus.notSelected,
    };

    return ProfileDetailEntry(
      configName: configName,
      status: status,
      samplingLabel: resolved.samplingLabel,
      dataTargetOptions: resolved.dataTargetOptions,
      detailText: status == ProfileDetailStatus.notSelected
          ? 'Current setting differs from this profile.'
          : null,
    );
  }

  ProfileDetailEntry _buildPairedProfileDetailEntry({
    required String configName,
    required SensorConfiguration primaryConfig,
    required SensorConfigurationValue primaryProfileValue,
    required SensorConfigurationProvider primaryProvider,
    required SensorConfigurationManager pairedManager,
    required SensorConfigurationProvider pairedProvider,
  }) {
    final resolved = SensorProfileService.describeSensorConfigurationValue(
      primaryProfileValue,
    );
    final mirroredConfig = SensorProfileService.findMirroredConfiguration(
      manager: pairedManager,
      sourceConfig: primaryConfig,
    );
    if (mirroredConfig == null) {
      return ProfileDetailEntry(
        configName: configName,
        status: ProfileDetailStatus.mixed,
        detailText: 'Configuration is unavailable on the paired device.',
      );
    }

    final mirroredProfileValue = SensorProfileService.findMirroredValue(
      mirroredConfig: mirroredConfig,
      sourceValue: primaryProfileValue,
    );
    if (mirroredProfileValue == null) {
      return ProfileDetailEntry(
        configName: configName,
        status: ProfileDetailStatus.mixed,
        detailText: 'Saved value is unavailable on the paired device.',
      );
    }

    final primarySnapshot = SensorProfileService.buildDeviceConfigSnapshot(
      provider: primaryProvider,
      config: primaryConfig,
      expectedValue: primaryProfileValue,
    );
    final secondarySnapshot = SensorProfileService.buildDeviceConfigSnapshot(
      provider: pairedProvider,
      config: mirroredConfig,
      expectedValue: mirroredProfileValue,
    );

    final statesMatch = primarySnapshot.state == secondarySnapshot.state;
    final selectedValuesMatch =
        SensorProfileService.configurationValuesMatchNullable(
      primarySnapshot.selectedValue,
      secondarySnapshot.selectedValue,
    );

    if (!statesMatch || !selectedValuesMatch) {
      return ProfileDetailEntry(
        configName: configName,
        status: ProfileDetailStatus.mixed,
        detailText:
            'Paired devices differ in selected/apply state, sampling rate, or data targets.',
      );
    }

    final status = switch (primarySnapshot.state) {
      DeviceProfileConfigState.applied => ProfileDetailStatus.applied,
      DeviceProfileConfigState.selected => ProfileDetailStatus.selected,
      DeviceProfileConfigState.notSelected => ProfileDetailStatus.notSelected,
      DeviceProfileConfigState.unavailable => ProfileDetailStatus.unavailable,
    };

    return ProfileDetailEntry(
      configName: configName,
      status: status,
      samplingLabel: resolved.samplingLabel,
      dataTargetOptions: resolved.dataTargetOptions,
      detailText: status == ProfileDetailStatus.notSelected
          ? 'Current paired setting differs from this profile.'
          : null,
    );
  }

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

class _ProfileActionItem {
  final String label;
  final IconData icon;
  final bool isDestructive;
  final Future<void> Function() onPressed;

  const _ProfileActionItem({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.isDestructive = false,
  });
}
