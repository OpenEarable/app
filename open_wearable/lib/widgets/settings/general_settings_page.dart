import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
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
                  return ListView(
                    padding:
                        SensorPageSpacing.pagePaddingWithBottomInset(context),
                    children: [
                      Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: SwitchListTile.adaptive(
                          value: shutOffOnCloseEnabled,
                          onChanged:
                              _isSaving ? null : _setShutOffSensorsOnClose,
                          secondary: const Icon(
                            Icons.power_settings_new_rounded,
                            size: 18,
                          ),
                          title: const Text('Disable all sensors on app close'),
                          subtitle: const Text(
                            'Turns configurable sensors off after 10s in background when possible.',
                          ),
                        ),
                      ),
                      Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: SwitchListTile.adaptive(
                          value: disableLiveGraphsEnabled,
                          onChanged:
                              _isSaving ? null : _setDisableLiveDataGraphs,
                          secondary: const Icon(
                            Icons.area_chart_rounded,
                            size: 18,
                          ),
                          title: const Text('Disable live data graphs'),
                          subtitle: const Text(
                            'Stop live chart updates in the Sensors › Live Data views.',
                          ),
                        ),
                      ),
                      Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: SwitchListTile.adaptive(
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
                            'Hides live data graphs in Sensors › Live Data until samples arrive.',
                          ),
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
