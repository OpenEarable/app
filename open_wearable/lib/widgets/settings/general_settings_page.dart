import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:open_wearable/models/auto_connect_preferences.dart';
import 'package:open_wearable/models/app_shutdown_settings.dart';
import 'package:open_wearable/widgets/sensors/sensor_page_spacing.dart';

class GeneralSettingsPage extends StatefulWidget {
  const GeneralSettingsPage({super.key});

  @override
  State<GeneralSettingsPage> createState() => _GeneralSettingsPageState();
}

class _GeneralSettingsPageState extends State<GeneralSettingsPage> {
  bool _isSaving = false;

  Future<void> _setShutOffSensorsOnClose(bool enabled) async {
    if (_isSaving) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      await AppShutdownSettings.saveShutOffAllSensorsOnAppClose(enabled);
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _setDisableLiveDataGraphs(bool enabled) async {
    if (_isSaving) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      await AppShutdownSettings.saveDisableLiveDataGraphs(enabled);
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _setHideLiveDataGraphsWithoutData(bool enabled) async {
    if (_isSaving) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      await AppShutdownSettings.saveHideLiveDataGraphsWithoutData(enabled);
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _setAutoConnectEnabled(bool enabled) async {
    if (_isSaving) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      await AutoConnectPreferences.saveAutoConnectEnabled(enabled);
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PlatformScaffold(
      appBar: PlatformAppBar(
        title: const Text('General settings'),
      ),
      body: ValueListenableBuilder<bool>(
        valueListenable:
            AppShutdownSettings.shutOffAllSensorsOnAppCloseListenable,
        builder: (context, shutOffOnCloseEnabled, _) {
          return ValueListenableBuilder<bool>(
            valueListenable:
                AppShutdownSettings.disableLiveDataGraphsListenable,
            builder: (context, disableLiveGraphsEnabled, __) {
              return ValueListenableBuilder<bool>(
                valueListenable:
                    AppShutdownSettings.hideLiveDataGraphsWithoutDataListenable,
                builder: (context, hideLiveGraphsWithoutDataEnabled, ___) {
                  return ValueListenableBuilder<bool>(
                    valueListenable:
                        AutoConnectPreferences.autoConnectEnabledListenable,
                    builder: (context, autoConnectEnabled, ____) {
                      return ListView(
                        padding: SensorPageSpacing.pagePaddingWithBottomInset(
                          context,
                        ),
                        children: [
                          _buildSectionHeader(
                            context,
                            title: 'Connectivity',
                            description:
                                'Manage how devices reconnect in the background',
                          ),
                          _buildSettingGroup(
                            [
                              SwitchListTile.adaptive(
                                value: autoConnectEnabled,
                                onChanged:
                                    _isSaving ? null : _setAutoConnectEnabled,
                                secondary: const Icon(
                                  Icons.bluetooth_searching_rounded,
                                  size: 18,
                                ),
                                title: const Text(
                                  'Enable Bluetooth auto-connect',
                                ),
                                subtitle: const Text(
                                  'Automatically reconnect remembered devices in the background',
                                ),
                              ),
                            ],
                          ),
                          _buildSectionHeader(
                            context,
                            title: 'App lifecycle',
                            description:
                                'Control what happens to sensors when the app goes to the background',
                          ),
                          _buildSettingGroup(
                            [
                              SwitchListTile.adaptive(
                                value: shutOffOnCloseEnabled,
                                onChanged: _isSaving
                                    ? null
                                    : _setShutOffSensorsOnClose,
                                secondary: const Icon(
                                  Icons.power_settings_new_rounded,
                                  size: 18,
                                ),
                                title: const Text(
                                  'Disable all sensors on app close',
                                ),
                                subtitle: const Text(
                                  'Turns configurable sensors off after 10s in background when possible',
                                ),
                              ),
                            ],
                          ),
                          _buildSectionHeader(
                            context,
                            title: 'Live data',
                            description:
                                'Adjust graph visibility and update behavior in Sensors › Live Data',
                          ),
                          _buildSettingGroup(
                            [
                              SwitchListTile.adaptive(
                                value: disableLiveGraphsEnabled,
                                onChanged: _isSaving
                                    ? null
                                    : _setDisableLiveDataGraphs,
                                secondary: const Icon(
                                  Icons.area_chart_rounded,
                                  size: 18,
                                ),
                                title: const Text('Disable live data graphs'),
                                subtitle: const Text(
                                  'Stop live chart updates in the Sensors › Live Data views',
                                ),
                              ),
                              SwitchListTile.adaptive(
                                value: hideLiveGraphsWithoutDataEnabled,
                                onChanged: _isSaving
                                    ? null
                                    : _setHideLiveDataGraphsWithoutData,
                                secondary: const Icon(
                                  Icons.sensors_off_rounded,
                                  size: 18,
                                ),
                                title: const Text(
                                  'Hide live data graphs without data',
                                ),
                                subtitle: const Text(
                                  'Hides live data graphs in Sensors › Live Data until samples arrive',
                                ),
                              ),
                            ],
                          ),
                        ],
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(
    BuildContext context, {
    required String title,
    required String description,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 2),
          Text(
            description,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingGroup(List<Widget> tiles) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var index = 0; index < tiles.length; index++) ...[
            tiles[index],
            if (index < tiles.length - 1) const Divider(height: 1),
          ],
        ],
      ),
    );
  }
}
