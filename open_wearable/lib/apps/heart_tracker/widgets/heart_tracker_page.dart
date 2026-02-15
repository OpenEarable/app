import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart';
import 'package:open_wearable/apps/heart_tracker/model/ppg_filter.dart';
import 'package:open_wearable/apps/heart_tracker/widgets/rowling_chart.dart';
import 'package:open_wearable/models/wearable_display_group.dart';
import 'package:open_wearable/view_models/sensor_configuration_provider.dart';
import 'package:open_wearable/widgets/devices/devices_page.dart';
import 'package:provider/provider.dart';

class HeartTrackerPage extends StatefulWidget {
  final Wearable wearable;
  final Sensor ppgSensor;
  final Sensor? accelerometerSensor;

  const HeartTrackerPage({
    super.key,
    required this.wearable,
    required this.ppgSensor,
    this.accelerometerSensor,
  });

  @override
  State<HeartTrackerPage> createState() => _HeartTrackerPageState();
}

class _HeartTrackerPageState extends State<HeartTrackerPage> {
  PpgFilter? _ppgFilter;
  Stream<(int, double)>? _displayPpgSignalStream;
  SensorConfigurationProvider? _sensorConfigProvider;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final configProvider =
          Provider.of<SensorConfigurationProvider>(context, listen: false);
      _sensorConfigProvider = configProvider;
      final ppgSensor = widget.ppgSensor;
      final accelerometerSensor = widget.accelerometerSensor;

      final sampleFreq = _configureSensorForStreaming(
        ppgSensor,
        configProvider,
        fallbackFrequency: 50.0,
        targetFrequencyHz: 50,
      );
      if (accelerometerSensor != null) {
        _configureSensorForStreaming(
          accelerometerSensor,
          configProvider,
          fallbackFrequency: 50.0,
          targetFrequencyHz: 50,
        );
      }

      final ppgStream = ppgSensor.sensorStream
          .map<PpgOpticalSample?>((data) {
            if (data is! SensorDoubleValue) {
              return null;
            }
            return _extractPpgOpticalSample(ppgSensor, data);
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
      final ppgFilter = PpgFilter(
        inputStream: ppgStream,
        motionStream: accelerometerMagnitudeStream,
        sampleFreq: sampleFreq,
        timestampExponent: ppgSensor.timestampExponent,
      );
      setState(() {
        _displayPpgSignalStream = ppgFilter.displaySignalStream;
        _ppgFilter = ppgFilter;
      });
    });
  }

  @override
  void dispose() {
    final configProvider = _sensorConfigProvider;
    if (configProvider != null) {
      _disableSensorStreaming(widget.ppgSensor, configProvider);
      final accelerometerSensor = widget.accelerometerSensor;
      if (accelerometerSensor != null) {
        _disableSensorStreaming(accelerometerSensor, configProvider);
      }
    }
    _ppgFilter?.dispose();
    super.dispose();
  }

  void _disableSensorStreaming(
    Sensor sensor,
    SensorConfigurationProvider configProvider,
  ) {
    for (final config in sensor.relatedConfigurations) {
      try {
        final offValue = config.offValue;
        if (offValue != null) {
          configProvider.addSensorConfiguration(
            config,
            offValue,
            markPending: false,
          );
          config.setConfiguration(offValue);
          continue;
        }

        if (config is ConfigurableSensorConfiguration &&
            config.availableOptions
                .any((option) => option is StreamSensorConfigOption)) {
          configProvider.removeSensorConfigurationOption(
            config,
            const StreamSensorConfigOption(),
            markPending: false,
          );
          final selected = configProvider.getSelectedConfigurationValue(config);
          if (selected is ConfigurableSensorConfigurationValue) {
            config.setConfiguration(selected);
          }
        }
      } catch (_) {
        // Best-effort teardown: continue even if one write fails.
      }
    }
  }

  double _configureSensorForStreaming(
    Sensor sensor,
    SensorConfigurationProvider configProvider, {
    required double fallbackFrequency,
    required int targetFrequencyHz,
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
    SensorConfigurationValue? appliedValue;
    if (values.isNotEmpty) {
      appliedValue = _selectBestConfigurationValue(
        values,
        targetFrequencyHz: targetFrequencyHz,
      );
      configProvider.addSensorConfiguration(
        configuration,
        appliedValue,
        markPending: false,
      );
    }

    final selectedValue =
        configProvider.getSelectedConfigurationValue(configuration) ??
            appliedValue;
    if (selectedValue != null) {
      configuration.setConfiguration(selectedValue);
    }

    if (selectedValue is SensorFrequencyConfigurationValue) {
      return selectedValue.frequencyHz;
    }

    return fallbackFrequency;
  }

  SensorConfigurationValue _selectBestConfigurationValue(
    List<SensorConfigurationValue> values, {
    required int targetFrequencyHz,
  }) {
    final frequencyValues =
        values.whereType<SensorFrequencyConfigurationValue>().toList();
    if (frequencyValues.isEmpty) {
      return values.first;
    }

    SensorFrequencyConfigurationValue? nextBigger;
    SensorFrequencyConfigurationValue? maxValue;
    for (final value in frequencyValues) {
      if (maxValue == null || value.frequencyHz > maxValue.frequencyHz) {
        maxValue = value;
      }
      if (value.frequencyHz >= targetFrequencyHz &&
          (nextBigger == null || value.frequencyHz < nextBigger.frequencyHz)) {
        nextBigger = value;
      }
    }

    return nextBigger ?? maxValue ?? values.first;
  }

  PpgOpticalSample? _extractPpgOpticalSample(
    Sensor sensor,
    SensorDoubleValue data,
  ) {
    if (data.values.isEmpty) {
      return null;
    }

    int? findAxisIndex(List<String> keywords) {
      for (var i = 0; i < sensor.axisNames.length; i++) {
        final axis = sensor.axisNames[i].toLowerCase();
        if (keywords.any(axis.contains)) {
          return i;
        }
      }
      return null;
    }

    double valueAt(int? index, double fallback) {
      if (index != null && index >= 0 && index < data.values.length) {
        return data.values[index];
      }
      return fallback;
    }

    final fallbackRed = data.values[0];
    final fallbackIr = data.values.length > 1 ? data.values[1] : fallbackRed;
    final fallbackGreen = data.values.length > 2 ? data.values[2] : fallbackRed;
    final fallbackAmbient = data.values.length > 3 ? data.values[3] : 0.0;

    // Usually channels are [red, ir, green, ambient], but we prefer axis-name
    // matching when available to avoid firmware-order mismatches.
    final red = valueAt(findAxisIndex(['red']), fallbackRed);
    final ir = valueAt(findAxisIndex(['ir', 'infrared']), fallbackIr);
    final green = valueAt(findAxisIndex(['green']), fallbackGreen);
    final ambient = valueAt(findAxisIndex(['ambient']), fallbackAmbient);

    return PpgOpticalSample(
      timestamp: data.timestamp,
      red: red,
      ir: ir,
      green: green,
      ambient: ambient,
    );
  }

  @override
  Widget build(BuildContext context) {
    final ppgFilter = _ppgFilter;
    final displayPpgSignalStream = _displayPpgSignalStream;
    return PlatformScaffold(
      appBar: PlatformAppBar(
        title: PlatformText('Heart Tracker'),
      ),
      body: ppgFilter == null || displayPpgSignalStream == null
          ? const Center(child: PlatformCircularProgressIndicator())
          : _buildContent(context, ppgFilter, displayPpgSignalStream),
    );
  }

  Widget _buildContent(
    BuildContext context,
    PpgFilter ppgFilter,
    Stream<(int, double)> displayPpgSignalStream,
  ) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
      children: [
        DeviceRow(
          group: WearableDisplayGroup.single(wearable: widget.wearable),
        ),
        const SizedBox(height: 12),
        StreamBuilder<PpgSignalQuality>(
          stream: ppgFilter.signalQualityStream,
          initialData: PpgSignalQuality.unavailable,
          builder: (context, snapshot) {
            final quality = snapshot.data ?? PpgSignalQuality.unavailable;
            return _SignalQualityCard(quality: quality);
          },
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: StreamBuilder<double?>(
                stream: ppgFilter.heartRateStream,
                builder: (context, snapshot) {
                  final bpm = snapshot.data;
                  return _MetricCard(
                    title: 'Heart Rate',
                    icon: Icons.favorite_rounded,
                    value: bpm != null && bpm.isFinite
                        ? bpm.toStringAsFixed(0)
                        : '--',
                    unit: 'BPM',
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
                  return _MetricCard(
                    title: 'HRV',
                    icon: Icons.monitor_heart_rounded,
                    value: hrv != null && hrv.isFinite
                        ? hrv.toStringAsFixed(0)
                        : '--',
                    unit: 'ms',
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
                Row(
                  children: [
                    Icon(
                      Icons.show_chart_rounded,
                      size: 18,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'PPG Signal',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Display uses the same filtered signal used for HR/HRV.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 88,
                  child: RollingChart(
                    dataSteam: displayPpgSignalStream,
                    timestampExponent: widget.ppgSensor.timestampExponent,
                    timeWindow: 10,
                    showXAxis: false,
                    showYAxis: false,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            'This view is a basic demonstration of real-time heartbeat tracking. '
            'With advanced algorithms and stronger motion-robust sensor fusion, '
            'heart-rate extraction can be made substantially more reliable in dynamic conditions.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final String value;
  final String unit;

  const _MetricCard({
    required this.title,
    required this.icon,
    required this.value,
    required this.unit,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  size: 18,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 6),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  value,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(width: 4),
                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Text(
                    unit,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SignalQualityCard extends StatelessWidget {
  final PpgSignalQuality quality;

  const _SignalQualityCard({
    required this.quality,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final (label, hint, icon, color) = _presentQuality(colorScheme);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      icon,
                      size: 18,
                      color: color,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Heartbeat Signal',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ],
                ),
                Container(
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: color,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              hint,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  (String, String, IconData, Color) _presentQuality(ColorScheme colors) {
    switch (quality) {
      case PpgSignalQuality.unavailable:
        return (
          'Unavailable',
          'No stable heartbeat waveform yet. Ensure stable wearable placement.',
          Icons.portable_wifi_off_rounded,
          colors.onSurfaceVariant,
        );
      case PpgSignalQuality.bad:
        return (
          'Bad',
          'Signal is noisy. Reduce motion and improve wearable contact.',
          Icons.signal_cellular_connected_no_internet_4_bar_rounded,
          colors.error,
        );
      case PpgSignalQuality.fair:
        return (
          'Fair',
          'Heartbeat is partially visible. Hold still for a clearer reading.',
          Icons.network_check_rounded,
          Colors.orange.shade700,
        );
      case PpgSignalQuality.good:
        return (
          'Good',
          'Signal quality is good for HR and HRV estimation.',
          Icons.check_circle_rounded,
          Colors.green.shade700,
        );
    }
  }
}
