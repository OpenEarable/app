import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart';
import 'package:open_wearable/models/app_shutdown_settings.dart';
import 'package:open_wearable/models/device_name_formatter.dart';
import 'package:open_wearable/view_models/sensor_data_provider.dart';
import 'package:open_wearable/widgets/devices/stereo_position_badge.dart';
import 'package:open_wearable/widgets/sensors/values/sensor_chart.dart';
import 'package:open_wearable/widgets/sensors/values/sensor_value_detail.dart';
import 'package:provider/provider.dart';

class SensorValueCard extends StatelessWidget {
  final Sensor sensor;
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
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => ChangeNotifierProvider.value(
              value: provider,
              child: SensorValueDetail(sensor: sensor, wearable: wearable),
            ),
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
                child: ValueListenableBuilder<bool>(
                  valueListenable:
                      AppShutdownSettings.disableLiveDataGraphsListenable,
                  builder: (context, disableLiveDataGraphs, _) {
                    return ValueListenableBuilder<bool>(
                      valueListenable: AppShutdownSettings
                          .hideLiveDataGraphsWithoutDataListenable,
                      builder: (context, hideGraphsWithoutData, __) {
                        final shouldHideWithoutData =
                            hideGraphsWithoutData && !disableLiveDataGraphs;
                        if (!shouldHideWithoutData) {
                          return SizedBox(
                            height: 200,
                            child: SensorChart(
                              allowToggleAxes: false,
                              liveUpdatesEnabled: !disableLiveDataGraphs,
                              onDisabledTap: disableLiveDataGraphs
                                  ? () => context.push('/settings/general')
                                  : null,
                            ),
                          );
                        }

                        return Consumer<SensorDataProvider>(
                          builder: (context, dataProvider, ___) {
                            final hideNoDataGraph =
                                dataProvider.sensorValues.isEmpty;
                            return SizedBox(
                              height: 200,
                              child: hideNoDataGraph
                                  ? _GraphsDisabledPlaceholder(
                                      icon: Icons.sensors_off_outlined,
                                      title: 'No live data yet',
                                      subtitle:
                                          'Graph hidden when no data is received. Tap to open General settings',
                                      onTap: () =>
                                          context.push('/settings/general'),
                                    )
                                  : const SensorChart(
                                      allowToggleAxes: false,
                                    ),
                            );
                          },
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

class _GraphsDisabledPlaceholder extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _GraphsDisabledPlaceholder({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  color: colorScheme.onSurfaceVariant,
                ),
                const SizedBox(height: 8),
                Text(
                  title,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
