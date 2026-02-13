import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart';
import 'package:open_wearable/view_models/sensor_configuration_storage.dart';
import 'package:open_wearable/widgets/devices/stereo_position_badge.dart';
import 'package:open_wearable/widgets/sensors/configuration/edge_recorder_prefix_row.dart';
import 'package:open_wearable/widgets/sensors/configuration/save_config_row.dart';
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
  Widget build(BuildContext context) {
    final device = widget.device;
    final tabBar = _buildTabBar(context);
    final isCombinedPair = widget.pairedDevice != null;
    final title = widget.displayName ?? device.name;

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
                'Settings from this row are applied to both paired devices when you tap "Apply Profiles".',
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

    final allConfigKeys =
        await SensorConfigurationStorage.listConfigurationKeys();
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
      );
    } else {
      _showSnackBar(
        'Loaded profile "$title". Tap "Apply Profiles" at the bottom to push to hardware.',
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
    _showSnackBar('Updated profile "$title" with current settings.');
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
    _showSnackBar('Deleted profile "$title".');
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
      _showSnackBar('Profile details are unavailable for this device.');
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
          resolvedValue: 'Configuration not available on this device.',
          status: _ProfileDetailStatus.unknownConfiguration,
        );
      }

      final matchedValue = sensorConfig.values
          .where((value) => value.key == entry.value)
          .firstOrNull;
      if (matchedValue == null) {
        return _ProfileDetailEntry(
          configName: entry.key,
          resolvedValue: 'Saved value is not available on this firmware.',
          status: _ProfileDetailStatus.missingValue,
        );
      }

      return _ProfileDetailEntry(
        configName: entry.key,
        resolvedValue: _describeSensorConfigurationValue(matchedValue),
        status: _ProfileDetailStatus.compatible,
      );
    }).toList()
      ..sort((a, b) => a.configName.compareTo(b.configName));

    final compatibleCount = details
        .where((entry) => entry.status == _ProfileDetailStatus.compatible)
        .length;
    final mismatchCount = details.length - compatibleCount;

    await showPlatformModalSheet<void>(
      context: context,
      builder: (sheetContext) => PlatformScaffold(
        appBar: PlatformAppBar(
          title: const Text('Profile details'),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(sheetContext).pop(),
          ),
        ),
        body: ListView(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Text(
                '${details.length} saved settings. '
                '$compatibleCount available, '
                '$mismatchCount unavailable on this device.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            const Divider(height: 1),
            if (details.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('This profile has no saved settings.'),
              )
            else
              ...details.map(
                (entry) => PlatformListTile(
                  leading: Icon(
                    switch (entry.status) {
                      _ProfileDetailStatus.compatible => Icons.tune_outlined,
                      _ProfileDetailStatus.missingValue =>
                        Icons.warning_amber_outlined,
                      _ProfileDetailStatus.unknownConfiguration =>
                        Icons.help_outline,
                    },
                  ),
                  title: PlatformText(entry.configName),
                  subtitle: PlatformText(entry.resolvedValue),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _describeSensorConfigurationValue(SensorConfigurationValue value) {
    final baseValue = value is SensorFrequencyConfigurationValue
        ? '${value.frequencyHz.toStringAsFixed(2)} Hz'
        : value.key;

    if (value is! ConfigurableSensorConfigurationValue) {
      return baseValue;
    }

    final optionNames = value.options
        .map(_describeSensorConfigurationOption)
        .toSet()
        .toList()
      ..sort();

    if (optionNames.isEmpty) {
      return baseValue;
    }

    return '$baseValue (${optionNames.join(', ')})';
  }

  String _describeSensorConfigurationOption(SensorConfigurationOption option) {
    if (option is StreamSensorConfigOption) {
      return 'Bluetooth';
    }
    if (option is RecordSensorConfigOption) {
      return 'SD card';
    }
    return option.name;
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

  void _showSnackBar(String message) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}

enum _ProfileDetailStatus {
  compatible,
  missingValue,
  unknownConfiguration,
}

class _ProfileDetailEntry {
  final String configName;
  final String resolvedValue;
  final _ProfileDetailStatus status;

  const _ProfileDetailEntry({
    required this.configName,
    required this.resolvedValue,
    required this.status,
  });
}

class _CombinedStereoBadge extends StatelessWidget {
  const _CombinedStereoBadge();

  @override
  Widget build(BuildContext context) {
    final foregroundColor = Theme.of(context).colorScheme.primary;
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
      padding: const EdgeInsets.symmetric(horizontal: 2),
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
