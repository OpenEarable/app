import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart';
import 'package:open_wearable/models/app_shutdown_settings.dart';
import 'package:open_wearable/models/device_name_formatter.dart';
import 'package:open_wearable/widgets/sensors/values/sensor_chart.dart';

class SensorValueDetail extends StatelessWidget {
  final Sensor sensor;
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
              child: ValueListenableBuilder<bool>(
                valueListenable:
                    AppShutdownSettings.disableLiveDataGraphsListenable,
                builder: (context, disableLiveDataGraphs, _) {
                  if (!disableLiveDataGraphs) {
                    return const SensorChart(
                      allowToggleAxes: true,
                    );
                  }

                  return Center(
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => context.push('/settings/app-close'),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 12,
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Live data graphs are disabled in General settings.',
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Tap to open General settings',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color:
                                          Theme.of(context).colorScheme.primary,
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
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
