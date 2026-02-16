import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:open_wearable/models/app_shutdown_settings.dart';

class AppCloseBehaviorPage extends StatefulWidget {
  const AppCloseBehaviorPage({super.key});

  @override
  State<AppCloseBehaviorPage> createState() => _AppCloseBehaviorPageState();
}

class _AppCloseBehaviorPageState extends State<AppCloseBehaviorPage> {
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
              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                children: [
                  Card(
                    child: SwitchListTile.adaptive(
                      value: shutOffOnCloseEnabled,
                      onChanged: _isSaving ? null : _setShutOffSensorsOnClose,
                      secondary: const Icon(
                        Icons.power_settings_new_rounded,
                        size: 18,
                      ),
                      title: const Text('Disable all sensors on app close'),
                      subtitle: const Text(
                        'Turns configurable sensors off after 10s in background when possible (Android applies this as soon as the app is backgrounded for reliability).',
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Card(
                    child: SwitchListTile.adaptive(
                      value: disableLiveGraphsEnabled,
                      onChanged: _isSaving ? null : _setDisableLiveDataGraphs,
                      secondary: const Icon(
                        Icons.area_chart_rounded,
                        size: 18,
                      ),
                      title: const Text('Disable live data graphs'),
                      subtitle: const Text(
                        'Hide live chart rendering in the Sensors › Live Data views.',
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
