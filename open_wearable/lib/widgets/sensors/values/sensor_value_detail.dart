import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart';
import 'package:open_wearable/models/device_name_formatter.dart';
import 'package:open_wearable/view_models/sensor_data_provider.dart';
import 'package:open_wearable/widgets/sensors/values/live_data_graph_settings.dart';
import 'package:open_wearable/widgets/sensors/values/sensor_chart.dart';
import 'package:provider/provider.dart';

/// Full-screen live graph view for a single wearable sensor.
class SensorValueDetail extends StatelessWidget {
  /// Sensor whose values should be visualized.
  final Sensor sensor;

  /// Wearable that owns [sensor].
  final Wearable wearable;

  const SensorValueDetail({
    super.key,
    required this.sensor,
    required this.wearable,
  });

  @override
  Widget build(BuildContext context) {
    return PlatformScaffold(
      appBar: PlatformAppBar(
        title: PlatformText(
          sensor.sensorName,
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ),
      body: SafeArea(
        top: false,
        bottom: true,
        minimum: const EdgeInsets.all(10),
        child: Column(
          children: [
            PlatformText(
              formatWearableDisplayName(wearable.name),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            Expanded(
              child: LiveDataGraphSettingsBuilder(
                builder: (context, settings) {
                  return Selector<SensorDataProvider, bool>(
                    selector: (context, dataProvider) =>
                        dataProvider.sensorValues.isNotEmpty,
                    builder: (context, hasData, _) {
                      if (settings.shouldShowGraph(hasData: hasData)) {
                        return SensorChart(
                          allowToggleAxes: true,
                          settings: settings,
                          onDisabledTap: settings.liveUpdatesEnabled
                              ? null
                              : () => context.push('/settings/general'),
                        );
                      }

                      return Center(
                        child: LiveDataGraphHiddenPlaceholder(
                          icon: Icons.sensors_off_outlined,
                          title: 'Live data graph hidden',
                          subtitle: 'Tap to open General settings',
                          onTap: () => context.push('/settings/general'),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
