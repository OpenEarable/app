import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart';
import 'package:open_wearable/models/app_shutdown_settings.dart';
import 'package:open_wearable/models/device_name_formatter.dart';
import 'package:open_wearable/view_models/sensor_data_provider.dart';
import 'package:open_wearable/widgets/devices/stereo_position_badge.dart';
import 'package:open_wearable/widgets/sensors/values/live_data_graph_settings.dart';
import 'package:open_wearable/widgets/sensors/values/sensor_chart.dart';
import 'package:open_wearable/widgets/sensors/values/sensor_value_detail.dart';
import 'package:provider/provider.dart';

/// Shows the latest live graph preview for one wearable sensor.
class SensorValueCard extends StatelessWidget {
  /// Sensor whose live data should be visualized.
  final Sensor sensor;

  /// Wearable that owns [sensor].
  final Wearable wearable;

  const SensorValueCard({
    super.key,
    required this.sensor,
    required this.wearable,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (AppShutdownSettings.disableLiveDataGraphs) {
          context.push('/settings/general');
          return;
        }

        final provider = context.read<SensorDataProvider>();
        context.push(
          '/view',
          extra: ChangeNotifierProvider.value(
            value: provider,
            child: SensorValueDetail(sensor: sensor, wearable: wearable),
          ),
        );
      },
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(10.0),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: PlatformText(
                      sensor.sensorName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      PlatformText(
                        formatWearableDisplayName(wearable.name),
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      if (wearable.hasCapability<StereoDevice>())
                        Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: StereoPositionBadge(
                            device: wearable.requireCapability<StereoDevice>(),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(top: 10.0),
                child: LiveDataGraphSettingsBuilder(
                  builder: (context, settings) {
                    return Selector<SensorDataProvider, bool>(
                      selector: (context, dataProvider) =>
                          dataProvider.sensorValues.isNotEmpty,
                      builder: (context, hasData, _) {
                        return SizedBox(
                          height: 200,
                          child: settings.shouldShowGraph(hasData: hasData)
                              ? SensorChart(
                                  compactMode: true,
                                  settings: settings,
                                  onDisabledTap: settings.liveUpdatesEnabled
                                      ? null
                                      : () => context.push('/settings/general'),
                                )
                              : LiveDataGraphHiddenPlaceholder(
                                  icon: Icons.sensors_off_outlined,
                                  title: 'No live data yet',
                                  subtitle:
                                      'Graph hidden when no data is received. Tap to open General settings',
                                  onTap: () =>
                                      context.push('/settings/general'),
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
      ),
    );
  }
}
