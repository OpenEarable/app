import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart';
import 'package:open_wearable/apps/heart_tracker/model/open_ring_classic_heart_processor.dart';
import 'package:open_wearable/apps/heart_tracker/model/ppg_filter.dart';
import 'package:open_wearable/apps/heart_tracker/widgets/rowling_chart.dart';
import 'package:open_wearable/models/device_name_formatter.dart';
import 'package:open_wearable/models/wearable_display_group.dart';
import 'package:open_wearable/view_models/sensor_configuration_provider.dart';
import 'package:open_wearable/widgets/devices/devices_page.dart';
import 'package:provider/provider.dart';

class HeartTrackerPage extends StatefulWidget {
  final Wearable wearable;
  final Sensor ppgSensor;
  final Sensor? accelerometerSensor;
  final Sensor? opticalTemperatureSensor;

  const HeartTrackerPage({
    super.key,
    required this.wearable,
    required this.ppgSensor,
    this.accelerometerSensor,
    this.opticalTemperatureSensor,
  });

  @override
  State<HeartTrackerPage> createState() => _HeartTrackerPageState();
}

class _HeartTrackerPageState extends State<HeartTrackerPage> {
  PpgFilter? _ppgFilter;
  OpenRingClassicHeartProcessor? _openRingProcessor;
  Stream<(int, double)>? _displayPpgSignalStream;
  Stream<double?>? _heartRateStream;
  Stream<double?>? _hrvStream;
  Stream<PpgSignalQuality>? _signalQualityStream;
  bool _usesOpenRingPipeline = false;
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
      final opticalTemperatureSensor = widget.opticalTemperatureSensor;

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
      if (opticalTemperatureSensor != null) {
        _configureSensorForStreaming(
          opticalTemperatureSensor,
          configProvider,
          fallbackFrequency: 5.0,
          targetFrequencyHz: 5,
        );
      }

      final ppgStream = ppgSensor.sensorStream
          .map<PpgOpticalSample?>((data) {
            final values = _sensorValuesAsDoubles(data);
            if (values == null) {
              return null;
            }
            return _extractPpgOpticalSample(ppgSensor, data, values);
          })
          .where((sample) => sample != null)
          .cast<PpgOpticalSample>()
          .asBroadcastStream();

      Stream<PpgMotionSample>? accelerometerMotionStream;
      if (accelerometerSensor != null) {
        accelerometerMotionStream = accelerometerSensor.sensorStream
            .map<PpgMotionSample?>((data) {
              final values = _sensorValuesAsDoubles(data);
              if (values == null) {
                return null;
              }
              return _extractImuMotionSample(
                accelerometerSensor,
                data,
                values,
              );
            })
            .where((sample) => sample != null)
            .cast<PpgMotionSample>()
            .asBroadcastStream();
      }

      Stream<PpgTemperatureSample>? opticalTemperatureStream;
      if (opticalTemperatureSensor != null) {
        opticalTemperatureStream = opticalTemperatureSensor.sensorStream
            .map<PpgTemperatureSample?>((data) {
              final values = _sensorValuesAsDoubles(data);
              if (values == null) {
                return null;
              }
              return _extractOpticalTemperatureSample(
                opticalTemperatureSensor,
                data,
                values,
              );
            })
            .where((sample) => sample != null)
            .cast<PpgTemperatureSample>()
            .asBroadcastStream();
      }

      if (!mounted) {
        return;
      }
      if (_isOpenRingWearable(widget.wearable.name)) {
        final openRingProcessor = OpenRingClassicHeartProcessor(
          inputStream: ppgStream,
          sampleFreq: sampleFreq,
        );
        setState(() {
          _displayPpgSignalStream = openRingProcessor.displaySignalStream;
          _heartRateStream = openRingProcessor.heartRateStream;
          _hrvStream = openRingProcessor.hrvStream;
          _signalQualityStream = openRingProcessor.signalQualityStream;
          _openRingProcessor = openRingProcessor;
          _usesOpenRingPipeline = true;
        });
        return;
      }

      final ppgFilter = PpgFilter(
        inputStream: ppgStream,
        motionStream: accelerometerMotionStream,
        opticalTemperatureStream: opticalTemperatureStream,
        sampleFreq: sampleFreq,
        timestampExponent: ppgSensor.timestampExponent,
      );
      setState(() {
        _displayPpgSignalStream = ppgFilter.displaySignalStream;
        _heartRateStream = ppgFilter.heartRateStream;
        _hrvStream = ppgFilter.hrvStream;
        _signalQualityStream = ppgFilter.signalQualityStream;
        _ppgFilter = ppgFilter;
        _usesOpenRingPipeline = false;
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
      final opticalTemperatureSensor = widget.opticalTemperatureSensor;
      if (opticalTemperatureSensor != null) {
        _disableSensorStreaming(opticalTemperatureSensor, configProvider);
      }
    }
    _ppgFilter?.dispose();
    _openRingProcessor?.dispose();
    super.dispose();
  }

  bool _isOpenRingWearable(String wearableName) {
    final normalizedRaw = wearableName.trim().toLowerCase();
    if (normalizedRaw.startsWith('openring') ||
        normalizedRaw.startsWith('bcl')) {
      return true;
    }

    final normalizedDisplay =
        formatWearableDisplayName(wearableName).trim().toLowerCase();
    return normalizedDisplay.startsWith('openring');
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

  List<double>? _sensorValuesAsDoubles(SensorValue data) {
    if (data is SensorDoubleValue) {
      return data.values;
    }
    if (data is SensorIntValue) {
      return data.values
          .map((value) => value.toDouble())
          .toList(growable: false);
    }
    return null;
  }

  PpgOpticalSample? _extractPpgOpticalSample(
    Sensor sensor,
    SensorValue data,
    List<double> values,
  ) {
    if (values.isEmpty) {
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
      if (index != null && index >= 0 && index < values.length) {
        return values[index];
      }
      return fallback;
    }

    final fallbackRed = values[0];
    final fallbackIr = values.length > 1 ? values[1] : fallbackRed;
    final fallbackGreen = values.length > 2 ? values[2] : fallbackRed;
    final fallbackAmbient = values.length > 3 ? values[3] : 0.0;

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

  PpgMotionSample _extractImuMotionSample(
    Sensor sensor,
    SensorValue data,
    List<double> values,
  ) {
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
      if (index != null && index >= 0 && index < values.length) {
        return values[index];
      }
      return fallback;
    }

    final fallbackX = values.isNotEmpty ? values[0] : 0.0;
    final fallbackY = values.length > 1 ? values[1] : 0.0;
    final fallbackZ = values.length > 2 ? values[2] : 0.0;

    final x = valueAt(findAxisIndex(['x']), fallbackX);
    final y = valueAt(findAxisIndex(['y']), fallbackY);
    final z = valueAt(findAxisIndex(['z']), fallbackZ);

    return PpgMotionSample(
      timestamp: data.timestamp,
      x: x,
      y: y,
      z: z,
    );
  }

  PpgTemperatureSample? _extractOpticalTemperatureSample(
    Sensor sensor,
    SensorValue data,
    List<double> values,
  ) {
    if (values.isEmpty) {
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

    final axisIndex = findAxisIndex(['temp', 'temperature']) ?? 0;
    if (axisIndex < 0 || axisIndex >= values.length) {
      return null;
    }
    final celsius = values[axisIndex];
    if (!celsius.isFinite) {
      return null;
    }
    return PpgTemperatureSample(
      timestamp: data.timestamp,
      celsius: celsius,
    );
  }

  @override
  Widget build(BuildContext context) {
    final displayPpgSignalStream = _displayPpgSignalStream;
    final heartRateStream = _heartRateStream;
    final hrvStream = _hrvStream;
    final signalQualityStream = _signalQualityStream;
    return PlatformScaffold(
      appBar: PlatformAppBar(
        title: PlatformText('Heart Tracker'),
      ),
      body: displayPpgSignalStream == null ||
              heartRateStream == null ||
              hrvStream == null ||
              signalQualityStream == null
          ? const Center(child: PlatformCircularProgressIndicator())
          : _buildContent(
              context,
              displayPpgSignalStream,
              heartRateStream,
              hrvStream,
              signalQualityStream,
              usesOpenRingPipeline: _usesOpenRingPipeline,
            ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    Stream<(int, double)> displayPpgSignalStream,
    Stream<double?> heartRateStream,
    Stream<double?> hrvStream,
    Stream<PpgSignalQuality> signalQualityStream, {
    required bool usesOpenRingPipeline,
  }) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
      children: [
        DeviceRow(
          group: WearableDisplayGroup.single(wearable: widget.wearable),
        ),
        const SizedBox(height: 12),
        StreamBuilder<PpgSignalQuality>(
          stream: signalQualityStream,
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
                stream: heartRateStream,
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
                stream: hrvStream,
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
        _SignalPanelCard(
          title: 'Filtered PPG',
          subtitle: usesOpenRingPipeline
              ? 'OpenRing physiological preprocessing and classic peak-based heart-rate estimation.'
              : 'Noise-suppressed PPG signal via NLMS Motion-ANC.',
          icon: Icons.show_chart_rounded,
          chartStream: displayPpgSignalStream,
          timestampExponent: widget.ppgSensor.timestampExponent,
          fixedMeasureMin: usesOpenRingPipeline ? null : -1.6,
          fixedMeasureMax: usesOpenRingPipeline ? null : 1.6,
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
                      Icons.menu_book_rounded,
                      size: 18,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Algorithm Citation',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                if (usesOpenRingPipeline) ...[
                  Text(
                    'OpenRing processing path: physiological signal filter and classic adaptive peak detection adapted from Tsinghua OpenRing source '
                    '(SignalFilters.java, ClassicAlgorithmProcessor.java).',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Device citation: τ-Ring: A Smart Ring Platform for Multimodal Physiological and Behavioral Sensing '
                    '(Tang et al., UbiComp Companion, 2025). arXiv:2508.00778',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ] else ...[
                  Text(
                    'Beat detection: MSPTDfast v2 '
                    '(Charlton et al., 2025). '
                    'DOI: 10.1088/1361-6579/adb89e',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Motion artifact suppression: multi-reference NLMS Motion-ANC '
                    'adapted from padasip (MIT, Cejnek & Vrba, 2022). '
                    'DOI: 10.1016/j.jocs.2022.101887',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Implementation optimized for real-time, smartphone-class '
                    'compute using streaming filters and bounded state.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.warning_amber_rounded,
                size: 13,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  'This view is for demonstration purposes only. It is not a medical device and must not be used for diagnosis, treatment, or emergency decisions.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ),
            ],
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

class _SignalPanelCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Stream<(int, double)> chartStream;
  final int timestampExponent;
  final double? fixedMeasureMin;
  final double? fixedMeasureMax;

  const _SignalPanelCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.chartStream,
    required this.timestampExponent,
    this.fixedMeasureMin,
    this.fixedMeasureMax,
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
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 88,
              child: RollingChart(
                dataSteam: chartStream,
                timestampExponent: timestampExponent,
                timeWindow: 5,
                showXAxis: false,
                showYAxis: false,
                fixedMeasureMin: fixedMeasureMin,
                fixedMeasureMax: fixedMeasureMax,
              ),
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
