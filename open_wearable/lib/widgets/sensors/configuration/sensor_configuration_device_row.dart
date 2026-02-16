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
  final String? displayName;
  final String? storageScope;

  const SensorConfigurationDeviceRow({
    super.key,
    required this.device,
    this.pairedDevice,
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
  late final TabController _tabController;
  List<Widget> _content = [];

  String get _deviceProfileScope =>
      widget.storageScope ?? 'device_${widget.device.deviceId}';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_onTabChanged);
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
    final scopeChanged = oldWidget.storageScope != widget.storageScope;
    if (deviceChanged || pairedDeviceChanged || scopeChanged) {
      _updateContent();
    }
  }

  @override
  Widget build(BuildContext context) {
    final device = widget.device;
    final tabBar = _buildTabBar(context);
    final isCombinedPair = widget.pairedDevice != null;
    final title =
        widget.displayName ?? formatWearableDisplayName(device.name);

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

    final content = <Widget>[
      ...sensorManager.sensorConfigurations.map(
        (config) => SensorConfigurationValueRow(
          sensorConfiguration: config,
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

    List<String> allConfigKeys;
    try {
      allConfigKeys = await SensorConfigurationStorage.listConfigurationKeys()
          .timeout(const Duration(seconds: 8));
    } catch (error, stackTrace) {
      debugPrint(
        'Failed to load sensor profiles for $_deviceProfileScope: '
        '$error\n$stackTrace',
      );
      if (!mounted) return;
      setState(() {
        _content = [
          SaveConfigRow(
            storageScope: _deviceProfileScope,
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
    final scopedKeys = allConfigKeys
        .where(
          (key) => SensorConfigurationStorage.keyMatchesScope(
            key,
            _deviceProfileScope,
          ),
        )
        .toList()
      ..sort();
    final legacyKeys = allConfigKeys
        .where(SensorConfigurationStorage.isLegacyUnscopedKey)
        .toList()
      ..sort();
    final profileKeys = [...scopedKeys, ...legacyKeys];

    if (!mounted) return;

    final content = <Widget>[
      SaveConfigRow(
        storageScope: _deviceProfileScope,
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
      content.addAll(profileKeys.map(_buildProfileTile));
    }

    setState(() {
      _content = content;
    });
  }

  Widget _buildProfileTile(String key) {
    final isDeviceScoped = SensorConfigurationStorage.keyMatchesScope(
      key,
      _deviceProfileScope,
    );

    final title = isDeviceScoped
        ? SensorConfigurationStorage.displayNameFromScopedKey(
            key,
            scope: _deviceProfileScope,
          )
        : key;

    return PlatformListTile(
      leading: Icon(
        isDeviceScoped ? Icons.tune_outlined : Icons.tune,
      ),
      title: PlatformText(title),
      subtitle: PlatformText(
        isDeviceScoped ? 'Tap to load as current' : 'Legacy shared profile',
      ),
      onTap: () => _loadProfile(key: key, title: title),
      trailing: PlatformIconButton(
        icon: const Icon(Icons.more_horiz),
        onPressed: () => _showProfileActions(
          key: key,
          title: title,
        ),
      ),
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
    final config = await SensorConfigurationStorage.loadConfiguration(key);
    if (!mounted) return;

    final provider = context.read<SensorConfigurationProvider>();
    final result = await provider.restoreFromJson(config);
    if (!mounted) return;

    if (!result.hasRestoredValues) {
      await showPlatformDialog<void>(
        context: context,
        builder: (dialogContext) => PlatformAlertDialog(
          title: const Text('Profile error'),
          content: Text(
            'No compatible values from "$title" could be restored for this device.',
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

    if (result.skippedCount > 0 || result.unknownConfigCount > 0) {
      _showSnackBar(
        'Loaded "$title" (${result.restoredCount} restored, ${result.skippedCount + result.unknownConfigCount} skipped). Tap "Apply Profiles" to push.',
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
    final confirmed = await _confirmOverwrite(title);
    if (!confirmed) return;
    if (!mounted) return;

    final provider = context.read<SensorConfigurationProvider>();
    await SensorConfigurationStorage.saveConfiguration(key, provider.toJson());
    if (!mounted) return;
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
    final confirmed = await _confirmDelete(title);
    if (!confirmed) return;

    await SensorConfigurationStorage.deleteConfiguration(key);
    if (!mounted) return;
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
              ListTile(
                leading: const Icon(Icons.save),
                title: const Text('Overwrite with current settings'),
                onTap: () async {
                  Navigator.of(sheetContext).pop();
                  await _overwriteProfile(key: key, title: title);
                },
              ),
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
            CupertinoActionSheetAction(
              onPressed: () async {
                Navigator.of(sheetContext).pop();
                await _overwriteProfile(key: key, title: title);
              },
              child: const Text('Overwrite with current settings'),
            ),
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
    final config = await SensorConfigurationStorage.loadConfiguration(key);
    if (!mounted) return;

    if (!widget.device.hasCapability<SensorConfigurationManager>()) {
      _showSnackBar(
        'Profile details are unavailable for this device.',
        type: AppToastType.warning,
        icon: Icons.info_outline_rounded,
      );
      return;
    }

    final sensorManager =
        widget.device.requireCapability<SensorConfigurationManager>();
    final knownConfigs = <String, SensorConfiguration>{
      for (final sensorConfig in sensorManager.sensorConfigurations)
        sensorConfig.name: sensorConfig,
    };

    final details = config.entries.map((entry) {
      final sensorConfig = knownConfigs[entry.key];
      if (sensorConfig == null) {
        return _ProfileDetailEntry(
          configName: entry.key,
          status: _ProfileDetailStatus.unknownConfiguration,
          detailText: 'Configuration not available on this device.',
        );
      }

      final matchedValue = sensorConfig.values
          .where((value) => value.key == entry.value)
          .firstOrNull;
      if (matchedValue == null) {
        return _ProfileDetailEntry(
          configName: entry.key,
          status: _ProfileDetailStatus.missingValue,
          detailText: 'Saved value is not available on this firmware.',
        );
      }

      final resolved = _describeSensorConfigurationValue(matchedValue);
      return _ProfileDetailEntry(
        configName: entry.key,
        samplingLabel: resolved.samplingLabel,
        dataTargetOptions: resolved.dataTargetOptions,
        detailText: resolved.detailText,
        status: resolved.missingDataTarget
            ? _ProfileDetailStatus.inactiveNoTarget
            : _ProfileDetailStatus.compatible,
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

  _ResolvedProfileValue _describeSensorConfigurationValue(
    SensorConfigurationValue value,
  ) {
    final baseValue = value is SensorFrequencyConfigurationValue
        ? '${value.frequencyHz.toStringAsFixed(2)} Hz'
        : value.key;

    if (value is! ConfigurableSensorConfigurationValue) {
      return _ResolvedProfileValue(
        samplingLabel: baseValue,
        dataTargetOptions: const [],
        missingDataTarget: false,
        detailText: null,
      );
    }

    final dataTargets =
        value.options.where(_isDataTargetOption).toSet().toList();

    return _ResolvedProfileValue(
      samplingLabel: baseValue,
      dataTargetOptions: dataTargets,
      missingDataTarget: dataTargets.isEmpty,
      detailText: null,
    );
  }

  bool _isDataTargetOption(SensorConfigurationOption option) {
    return option is StreamSensorConfigOption ||
        option is RecordSensorConfigOption;
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

enum _ProfileDetailStatus {
  compatible,
  inactiveNoTarget,
  missingValue,
  unknownConfiguration,
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
  final bool missingDataTarget;
  final String? detailText;

  const _ResolvedProfileValue({
    required this.samplingLabel,
    required this.dataTargetOptions,
    required this.missingDataTarget,
    required this.detailText,
  });
}

class _ProfileDetailCard extends StatelessWidget {
  final _ProfileDetailEntry entry;

  const _ProfileDetailCard({
    required this.entry,
  });

  @override
  Widget build(BuildContext context) {
    const sensorOnGreen = Color(0xFF2E7D32);
    final colorScheme = Theme.of(context).colorScheme;
    final isOn = entry.status == _ProfileDetailStatus.compatible;
    final isOff = entry.status == _ProfileDetailStatus.inactiveNoTarget;
    final isUnavailable = entry.status == _ProfileDetailStatus.missingValue ||
        entry.status == _ProfileDetailStatus.unknownConfiguration;

    final indicatorColor = isOn
        ? sensorOnGreen.withValues(alpha: 0.72)
        : isUnavailable
            ? colorScheme.error.withValues(alpha: 0.62)
            : colorScheme.outlineVariant.withValues(alpha: 0.65);

    final icon = switch (entry.status) {
      _ProfileDetailStatus.compatible => Icons.sensors_rounded,
      _ProfileDetailStatus.inactiveNoTarget => Icons.sensors_off_rounded,
      _ProfileDetailStatus.missingValue => Icons.warning_amber_outlined,
      _ProfileDetailStatus.unknownConfiguration => Icons.help_outline_rounded,
    };
    final iconColor = isOn
        ? sensorOnGreen
        : isUnavailable
            ? colorScheme.error
            : colorScheme.onSurfaceVariant;

    final pillLabel =
        isUnavailable ? null : (isOff ? 'Off' : (entry.samplingLabel ?? 'On'));
    final pillEnabled = isOn;

    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 8),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: isOn ? 3 : 2,
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
              color: iconColor,
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
                                    fontWeight: FontWeight.w700,
                                  ),
                        ),
                      ),
                      if (entry.dataTargetOptions.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        _ProfileOptionsCompactBadge(
                          options: entry.dataTargetOptions,
                        ),
                      ],
                      if (pillLabel != null) ...[
                        const SizedBox(width: 8),
                        _ProfileSamplingRatePill(
                          label: pillLabel,
                          enabled: pillEnabled,
                        ),
                      ],
                    ],
                  ),
                  if (isUnavailable && entry.detailText != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      entry.detailText!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: isUnavailable
                                ? colorScheme.error
                                : colorScheme.onSurfaceVariant,
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

  const _ProfileOptionsCompactBadge({
    required this.options,
  });

  @override
  Widget build(BuildContext context) {
    const sensorOnGreen = Color(0xFF2E7D32);
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
            color: sensorOnGreen.withValues(alpha: 0.38),
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
                color: sensorOnGreen,
              ),
              if (i < visibleCount - 1) const SizedBox(width: 3),
            ],
            if (remainingCount > 0) ...[
              const SizedBox(width: 4),
              Text(
                '+$remainingCount',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: sensorOnGreen,
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
  final bool enabled;

  const _ProfileSamplingRatePill({
    required this.label,
    required this.enabled,
  });

  @override
  Widget build(BuildContext context) {
    const sensorOnGreen = Color(0xFF2E7D32);
    final colorScheme = Theme.of(context).colorScheme;
    final foreground = enabled ? sensorOnGreen : colorScheme.onSurfaceVariant;

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
