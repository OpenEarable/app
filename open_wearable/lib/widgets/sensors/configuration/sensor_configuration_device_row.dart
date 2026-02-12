import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart';
import 'package:open_wearable/view_models/sensor_configuration_storage.dart';
import 'package:open_wearable/widgets/sensors/configuration/edge_recorder_prefix_row.dart';
import 'package:open_wearable/widgets/sensors/configuration/save_config_row.dart';
import 'package:open_wearable/widgets/sensors/configuration/sensor_configuration_value_row.dart';
import 'package:provider/provider.dart';

import '../../../view_models/sensor_configuration_provider.dart';

/// A widget that displays and manages sensor configuration for a single device.
class SensorConfigurationDeviceRow extends StatefulWidget {
  final Wearable device;

  const SensorConfigurationDeviceRow({super.key, required this.device});

  @override
  State<SensorConfigurationDeviceRow> createState() =>
      _SensorConfigurationDeviceRowState();
}

class _SensorConfigurationDeviceRowState
    extends State<SensorConfigurationDeviceRow>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  List<Widget> _content = [];

  String get _deviceProfileScope => 'device_${widget.device.deviceId}';

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
                      Expanded(
                        child: PlatformText(
                          device.name,
                          style:
                              Theme.of(context).textTheme.bodyLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (device.hasCapability<StereoDevice>())
                        _CompactStereoBadge(
                          device: device.requireCapability<StereoDevice>(),
                        ),
                    ],
                  ),
                ),
                if (tabBar != null) ...[
                  const SizedBox(width: 8),
                  ConstrainedBox(
                    constraints: const BoxConstraints(
                      minWidth: 170,
                      maxWidth: 240,
                    ),
                    child: tabBar,
                  ),
                ],
              ],
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
        const Divider(),
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
            'No profiles saved yet. Save current settings above, then tap a profile to apply it.',
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
        isDeviceScoped ? Icons.devices_outlined : Icons.folder_outlined,
      ),
      title: PlatformText(title),
      subtitle: PlatformText(
        isDeviceScoped ? 'Tap to load into settings' : 'Legacy shared profile',
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
      isScrollable: false,
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
        'Loaded "$title" (${result.restoredCount} restored, ${result.skippedCount + result.unknownConfigCount} skipped). Tap "Apply Configurations" to push.',
      );
    } else {
      _showSnackBar(
        'Loaded profile "$title". Tap "Apply Configurations" at the bottom to push to hardware.',
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

class _CompactStereoBadge extends StatelessWidget {
  final StereoDevice device;

  const _CompactStereoBadge({required this.device});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DevicePosition?>(
      future: device.position,
      builder: (context, snapshot) {
        String? label;
        if (snapshot.hasData) {
          switch (snapshot.data) {
            case DevicePosition.left:
              label = 'L';
              break;
            case DevicePosition.right:
              label = 'R';
              break;
            default:
              label = null;
          }
        }

        if (label == null) {
          return const SizedBox.shrink();
        }

        return Padding(
          padding: const EdgeInsets.only(left: 8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ),
        );
      },
    );
  }
}
