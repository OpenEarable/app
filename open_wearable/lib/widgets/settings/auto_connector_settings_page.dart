import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:open_wearable/models/auto_connect_preferences.dart';
import 'package:open_wearable/widgets/app_toast.dart';
import 'package:open_wearable/widgets/sensors/sensor_page_spacing.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Settings page for Bluetooth auto-connect behavior and remembered devices.
class AutoConnectorSettingsPage extends StatefulWidget {
  /// Creates the auto-connector settings page.
  const AutoConnectorSettingsPage({super.key});

  @override
  State<AutoConnectorSettingsPage> createState() =>
      _AutoConnectorSettingsPageState();
}

class _AutoConnectorSettingsPageState extends State<AutoConnectorSettingsPage> {
  bool _isSaving = false;

  /// Persists the auto-connect enabled state.
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

  /// Removes one remembered device entry from auto-connect storage.
  Future<void> _removeRememberedDeviceName(String deviceName) async {
    if (_isSaving) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      await AutoConnectPreferences.forgetDeviceName(prefs, deviceName);
    } catch (_) {
      if (mounted) {
        AppToast.show(
          context,
          message: 'Could not remove saved auto-connect device.',
          type: AppToastType.error,
          icon: Icons.delete_outline_rounded,
        );
      }
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
        title: const Text('Auto connector'),
      ),
      body: ValueListenableBuilder<bool>(
        valueListenable: AutoConnectPreferences.autoConnectEnabledListenable,
        builder: (context, autoConnectEnabled, _) {
          return ValueListenableBuilder<List<String>>(
            valueListenable:
                AutoConnectPreferences.rememberedDeviceNamesListenable,
            builder: (context, rememberedDeviceNames, __) {
              return ListView(
                padding: SensorPageSpacing.pagePaddingWithBottomInset(context),
                children: [
                  _buildSectionHeader(
                    context,
                    title: 'Bluetooth auto-connect',
                    description:
                        'Control whether remembered devices reconnect in the background',
                  ),
                  _buildSettingGroup(
                    [
                      SwitchListTile.adaptive(
                        value: autoConnectEnabled,
                        onChanged: _isSaving ? null : _setAutoConnectEnabled,
                        secondary: const Icon(
                          Icons.bluetooth_searching_rounded,
                          size: 18,
                        ),
                        title: const Text('Enable Bluetooth auto-connect'),
                        subtitle: const Text(
                          'Automatically reconnect remembered devices in the background',
                        ),
                      ),
                    ],
                  ),
                  _buildSectionHeader(
                    context,
                    title: 'Saved devices',
                    description:
                        'Review and remove remembered devices used as reconnect targets',
                  ),
                  _buildSettingGroup(
                    _buildRememberedDeviceTiles(rememberedDeviceNames),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  /// Builds the saved auto-connect device rows shown in settings.
  List<Widget> _buildRememberedDeviceTiles(List<String> rememberedDeviceNames) {
    if (rememberedDeviceNames.isEmpty) {
      return [
        ListTile(
          leading: const Icon(
            Icons.bluetooth_disabled_rounded,
            size: 18,
          ),
          title: const Text('No saved auto-connect devices'),
          subtitle: const Text(
            'Devices appear here after they have been remembered for background reconnects',
          ),
        ),
      ];
    }

    return rememberedDeviceNames.map((deviceName) {
      return ListTile(
        leading: const Icon(
          Icons.bluetooth_connected_rounded,
          size: 18,
        ),
        title: Text(deviceName),
        subtitle: const Text('Used as a Bluetooth auto-connect target'),
        trailing: IconButton(
          tooltip: 'Remove saved device',
          onPressed:
              _isSaving ? null : () => _removeRememberedDeviceName(deviceName),
          icon: const Icon(Icons.delete_outline_rounded),
        ),
      );
    }).toList(growable: false);
  }

  /// Renders a labeled settings section heading.
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

  /// Groups related settings rows into a single card.
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
