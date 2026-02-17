import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart';
import 'package:open_wearable/models/app_shutdown_settings.dart';
import 'package:open_wearable/models/device_name_formatter.dart';
import 'package:open_wearable/view_models/sensor_data_provider.dart';
import 'package:open_wearable/widgets/sensors/values/sensor_chart.dart';
import 'package:provider/provider.dart';

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
            const SizedBox(height: 6),
            const _SensorSamplingRateHeader(),
            const SizedBox(height: 8),
            Expanded(
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
                        return SensorChart(
                          allowToggleAxes: true,
                          liveUpdatesEnabled: !disableLiveDataGraphs,
                          onDisabledTap: disableLiveDataGraphs
                              ? () => context.push('/settings/general')
                              : null,
                        );
                      }

                      return Consumer<SensorDataProvider>(
                        builder: (context, dataProvider, ___) {
                          if (dataProvider.sensorValues.isNotEmpty) {
                            return const SensorChart(
                              allowToggleAxes: true,
                            );
                          }

                          return Center(
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: () => context.push('/settings/general'),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 18,
                                    vertical: 12,
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        'Live data graph is hidden while this sensor has no data.',
                                        textAlign: TextAlign.center,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium,
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        'Tap to open General settings',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .primary,
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

class _SensorSamplingRateHeader extends StatelessWidget {
  const _SensorSamplingRateHeader();

  @override
  Widget build(BuildContext context) {
    return Consumer<SensorDataProvider>(
      builder: (context, dataProvider, _) {
        final samplingRateHz = dataProvider.currentSamplingRateHz;
        final samplingRateText =
            samplingRateHz == null ? '--' : _formatFrequency(samplingRateHz);
        return _buildLabel(context, 'Sampling rate: $samplingRateText');
      },
    );
  }

  Widget _buildLabel(BuildContext context, String text) {
    return PlatformText(
      text,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
    );
  }

  String _formatFrequency(double hz) {
    if ((hz - hz.roundToDouble()).abs() < 0.01) {
      return '${hz.round()} Hz';
    }
    if (hz >= 10) {
      return '${hz.toStringAsFixed(1)} Hz';
    }
    return '${hz.toStringAsFixed(2)} Hz';
  }
}
