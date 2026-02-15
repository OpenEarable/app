import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart';
import 'package:open_wearable/apps/heart_tracker/model/ppg_filter.dart';
import 'package:open_wearable/apps/heart_tracker/widgets/rowling_chart.dart';
import 'package:open_wearable/view_models/sensor_configuration_provider.dart';
import 'package:provider/provider.dart';

class HeartTrackerPage extends StatefulWidget {
  final Sensor ppgSensor;
  final Sensor? accelerometerSensor;

  const HeartTrackerPage({
    super.key,
    required this.ppgSensor,
    this.accelerometerSensor,
  });

  @override
  State<HeartTrackerPage> createState() => _HeartTrackerPageState();
}

class _HeartTrackerPageState extends State<HeartTrackerPage> {
  PpgFilter? _ppgFilter;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final configProvider =
          Provider.of<SensorConfigurationProvider>(context, listen: false);
      final ppgSensor = widget.ppgSensor;
      final accelerometerSensor = widget.accelerometerSensor;

      final sampleFreq = _configureSensorForStreaming(
        ppgSensor,
        configProvider,
        fallbackFrequency: 25.0,
      );
      if (accelerometerSensor != null) {
        _configureSensorForStreaming(
          accelerometerSensor,
          configProvider,
          fallbackFrequency: 25.0,
        );
      }

      final ppgStream = ppgSensor.sensorStream
          .map<PpgOpticalSample?>((data) {
            if (data is! SensorDoubleValue) {
              return null;
            }
            return _extractPpgOpticalSample(data);
          })
          .where((sample) => sample != null)
          .cast<PpgOpticalSample>()
          .asBroadcastStream();

      Stream<(int, double)>? accelerometerMagnitudeStream;
      if (accelerometerSensor != null) {
        accelerometerMagnitudeStream = accelerometerSensor.sensorStream
            .map<(int, double)?>((data) {
              if (data is! SensorDoubleValue) {
                return null;
              }
              final x = data.values.isNotEmpty ? data.values[0] : 0.0;
              final y = data.values.length > 1 ? data.values[1] : 0.0;
              final z = data.values.length > 2 ? data.values[2] : 0.0;
              final magnitude = sqrt((x * x) + (y * y) + (z * z));
              return (data.timestamp, magnitude);
            })
            .where((sample) => sample != null)
            .cast<(int, double)>()
            .asBroadcastStream();
      }

      if (!mounted) {
        return;
      }
      setState(() {
        _ppgFilter = PpgFilter(
          inputStream: ppgStream,
          motionStream: accelerometerMagnitudeStream,
          sampleFreq: sampleFreq,
          timestampExponent: ppgSensor.timestampExponent,
        );
      });
    });
  }

  @override
  void dispose() {
    _ppgFilter?.dispose();
    super.dispose();
  }

  double _configureSensorForStreaming(
    Sensor sensor,
    SensorConfigurationProvider configProvider, {
    required double fallbackFrequency,
  }) {
    final configuration = sensor.relatedConfigurations.firstOrNull;
    if (configuration == null) {
      return fallbackFrequency;
    }

    if (configuration is ConfigurableSensorConfiguration &&
        configuration.availableOptions.contains(StreamSensorConfigOption())) {
      configProvider.addSensorConfigurationOption(
        configuration,
        StreamSensorConfigOption(),
        markPending: false,
      );
    }

    final values = configProvider.getSensorConfigurationValues(
      configuration,
      distinct: true,
    );
    if (values.isNotEmpty) {
      configProvider.addSensorConfiguration(
        configuration,
        values.first,
        markPending: false,
      );
    }

    final selectedValue =
        configProvider.getSelectedConfigurationValue(configuration);
    if (selectedValue != null) {
      configuration.setConfiguration(selectedValue);
    }

    if (selectedValue is SensorFrequencyConfigurationValue) {
      return selectedValue.frequencyHz;
    }

    return fallbackFrequency;
  }

  PpgOpticalSample? _extractPpgOpticalSample(SensorDoubleValue data) {
    if (data.values.isEmpty) {
      return null;
    }

    // OpenEarable PPG usually exposes [red, ir, green, ambient].
    // Fall back safely for firmwares that expose fewer channels.
    final green = data.values.length > 2 ? data.values[2] : data.values.first;
    final ambient = data.values.length > 3
        ? data.values[3]
        : data.values.length > 1
            ? data.values[1]
            : 0.0;

    return PpgOpticalSample(
      timestamp: data.timestamp,
      green: green,
      ambient: ambient,
    );
  }

  @override
  Widget build(BuildContext context) {
    final ppgFilter = _ppgFilter;
    return PlatformScaffold(
      appBar: PlatformAppBar(
        title: PlatformText('Heart Tracker'),
      ),
      body: ppgFilter == null
          ? const Center(child: PlatformCircularProgressIndicator())
          : _buildContent(context, ppgFilter),
    );
  }

  Widget _buildContent(BuildContext context, PpgFilter ppgFilter) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
      children: [
        Row(
          children: [
            Expanded(
              child: StreamBuilder<double?>(
                stream: ppgFilter.heartRateStream,
                builder: (context, snapshot) {
                  final bpm = snapshot.data;
                  final hasValue = bpm != null && bpm.isFinite;
                  return _MetricCard(
                    title: 'Heart Rate',
                    value: hasValue ? bpm.toStringAsFixed(0) : null,
                    unit: hasValue ? 'BPM' : null,
                    subtitle: 'Estimated from PPG peaks',
                  );
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: StreamBuilder<double?>(
                stream: ppgFilter.hrvStream,
                builder: (context, snapshot) {
                  final hrv = snapshot.data;
                  final hasValue = hrv != null && hrv.isFinite;
                  return _MetricCard(
                    title: 'HRV',
                    value: hasValue ? hrv.toStringAsFixed(0) : null,
                    unit: hasValue ? 'ms' : null,
                    subtitle: 'RMSSD',
                  );
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'PPG Signal',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Beat-stabilized proxy waveform derived from the filtered optical signal.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 220,
                  child: RollingChart(
                    dataSteam: ppgFilter.displaySignalStream,
                    timestampExponent: widget.ppgSensor.timestampExponent,
                    timeWindow: 8,
                    showYAxis: false,
                    fixedMeasureMin: -1.4,
                    fixedMeasureMax: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String title;
  final String? value;
  final String? unit;
  final String subtitle;

  const _MetricCard({
    required this.title,
    required this.value,
    required this.unit,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (value != null) ...[
                  Text(
                    value!,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  if (unit != null) ...[
                    const SizedBox(width: 4),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 3),
                      child: Text(
                        unit!,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                      ),
                    ),
                  ],
                ] else
                  const SizedBox(height: 36),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
