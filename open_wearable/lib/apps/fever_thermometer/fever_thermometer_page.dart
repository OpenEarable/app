import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart';
import 'package:open_wearable/models/device_name_formatter.dart';
import 'package:open_wearable/models/sensor_streams.dart';
import 'package:open_wearable/view_models/sensor_configuration_provider.dart';
import 'package:open_wearable/view_models/wearables_provider.dart';
import 'package:open_wearable/widgets/sensors/sensor_page_spacing.dart';
import 'package:provider/provider.dart';

class FeverThermometerPage extends StatefulWidget {
  final Wearable wearable;
  final Sensor? opticalTemperatureSensor;
  final Sensor? ppgSensor;
  final SensorConfigurationProvider sensorConfigProvider;

  const FeverThermometerPage({
    super.key,
    required this.wearable,
    required this.opticalTemperatureSensor,
    required this.ppgSensor,
    required this.sensorConfigProvider,
  });

  @override
  State<FeverThermometerPage> createState() => _FeverThermometerPageState();
}

class _FeverThermometerPageState extends State<FeverThermometerPage> {
  static const double _coreOffsetCelsius = 0.4;
  static const int _temperatureTargetFrequencyHz = 10;
  static const int _ppgTargetFrequencyHz = 25;
  static const int _maxTrendPoints = 140;
  static const double _smoothingFactor = 0.24;
  static const Duration _minimumStabilizationDuration = Duration(minutes: 5);
  static const double _inEarAmbientThreshold = 180.0;

  final Map<SensorConfiguration, SensorConfigurationValue?>
      _savedConfigurations = {};

  StreamSubscription<SensorValue>? _temperatureSubscription;
  StreamSubscription<SensorValue>? _ppgSubscription;
  int _temperatureAxisIndex = 0;
  double? _smoothedCoreTempCelsius;
  bool _inEarDetected = false;
  List<double> _coreTrend = const [];
  DateTime? _stabilizationStartedAt;
  int _sampleCount = 0;
  String? _temperatureStreamError;
  String? _ppgStreamError;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_startStreaming());
    });
  }

  @override
  void dispose() {
    _temperatureSubscription?.cancel();
    _ppgSubscription?.cancel();
    final temperatureSensor = widget.opticalTemperatureSensor;
    if (temperatureSensor != null) {
      unawaited(_restoreSensorConfiguration(temperatureSensor));
    }
    final ppgSensor = widget.ppgSensor;
    if (ppgSensor != null) {
      unawaited(_restoreSensorConfiguration(ppgSensor));
    }
    super.dispose();
  }

  Future<void> _startStreaming() async {
    final temperatureSensor = widget.opticalTemperatureSensor;
    if (temperatureSensor == null) {
      return;
    }

    try {
      await _prepareSensorForStreaming(
        temperatureSensor,
        targetFrequencyHz: _temperatureTargetFrequencyHz,
      );
      _temperatureAxisIndex = _resolveTemperatureAxis(temperatureSensor);
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _temperatureStreamError =
            'Could not configure optical temperature streaming.';
      });
      return;
    }

    await _temperatureSubscription?.cancel();
    _temperatureSubscription = SensorStreams.shared(temperatureSensor).listen(
      _onSensorValue,
      onError: (_) {
        if (!mounted) {
          return;
        }
        setState(() {
          _temperatureStreamError = 'Optical temperature stream failed.';
        });
      },
    );

    final ppgSensor = widget.ppgSensor;
    if (ppgSensor == null) {
      if (!mounted) {
        return;
      }
      setState(() {
        _ppgStreamError =
            'In-ear placement check unavailable. Temperature result stays hidden.';
      });
      return;
    }

    try {
      await _prepareSensorForStreaming(
        ppgSensor,
        targetFrequencyHz: _ppgTargetFrequencyHz,
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _ppgStreamError = 'Could not start the in-ear placement check.';
      });
      return;
    }

    await _ppgSubscription?.cancel();
    _ppgSubscription = SensorStreams.shared(ppgSensor).listen(
      (value) => _onPpgValue(ppgSensor, value),
      onError: (_) {
        if (!mounted) {
          return;
        }
        setState(() {
          _inEarDetected = false;
          _ppgStreamError = 'In-ear placement check failed.';
          _resetStabilizationState();
        });
      },
    );
  }

  void _onSensorValue(SensorValue sensorValue) {
    final values = _valuesFromSensorValue(sensorValue);
    if (values.isEmpty) {
      return;
    }

    final axisIndex =
        _temperatureAxisIndex < values.length ? _temperatureAxisIndex : 0;
    final opticalTemp = values[axisIndex];
    if (!opticalTemp.isFinite) {
      return;
    }

    final now = DateTime.now();

    if (!mounted) {
      return;
    }
    setState(() {
      _temperatureStreamError = null;

      if (_inEarDetected) {
        final estimatedCoreTemp = opticalTemp + _coreOffsetCelsius;
        final smoothed = _smoothedCoreTempCelsius == null
            ? estimatedCoreTemp
            : _smoothedCoreTempCelsius! * (1 - _smoothingFactor) +
                estimatedCoreTemp * _smoothingFactor;
        final nextTrend = List<double>.from(_coreTrend)..add(smoothed);
        if (nextTrend.length > _maxTrendPoints) {
          nextTrend.removeRange(0, nextTrend.length - _maxTrendPoints);
        }
        _smoothedCoreTempCelsius = smoothed;
        _coreTrend = nextTrend;
        _sampleCount += 1;
        _stabilizationStartedAt ??= now;
      }
    });
  }

  void _onPpgValue(Sensor ppgSensor, SensorValue sensorValue) {
    final ambient = _extractPpgAmbient(ppgSensor, sensorValue);
    if (ambient == null || !ambient.isFinite) {
      return;
    }

    final inEarNow = ambient < _inEarAmbientThreshold;
    if (!mounted) {
      return;
    }

    setState(() {
      final wasInEar = _inEarDetected;
      _inEarDetected = inEarNow;
      _ppgStreamError = null;
      if (wasInEar && !inEarNow) {
        _resetStabilizationState();
      }
    });
  }

  double? _extractPpgAmbient(Sensor ppgSensor, SensorValue sensorValue) {
    final values = _valuesFromSensorValue(sensorValue);
    if (values.isEmpty) {
      return null;
    }

    int? ambientAxisIndex;
    for (var i = 0; i < ppgSensor.axisNames.length; i++) {
      final axis = ppgSensor.axisNames[i].toLowerCase();
      if (axis.contains('ambient')) {
        ambientAxisIndex = i;
        break;
      }
    }

    if (ambientAxisIndex != null && ambientAxisIndex < values.length) {
      return values[ambientAxisIndex];
    }
    if (values.length > 3) {
      return values[3];
    }
    return values.last;
  }

  int _resolveTemperatureAxis(Sensor sensor) {
    for (int i = 0; i < sensor.axisNames.length; i++) {
      final axisName = sensor.axisNames[i].toLowerCase();
      if (axisName.contains('temp') || axisName.contains('temperature')) {
        return i;
      }
    }
    return 0;
  }

  List<double> _valuesFromSensorValue(SensorValue value) {
    if (value is SensorDoubleValue) {
      return value.values;
    }
    if (value is SensorIntValue) {
      return value.values.map((entry) => entry.toDouble()).toList();
    }
    return value.valueStrings
        .map(double.tryParse)
        .whereType<double>()
        .toList(growable: false);
  }

  Future<void> _prepareSensorForStreaming(
    Sensor sensor, {
    required int targetFrequencyHz,
  }) async {
    for (final config in sensor.relatedConfigurations) {
      _savedConfigurations.putIfAbsent(
        config,
        () => widget.sensorConfigProvider.getSelectedConfigurationValue(config),
      );

      if (config is ConfigurableSensorConfiguration &&
          config.availableOptions
              .any((option) => option is StreamSensorConfigOption)) {
        widget.sensorConfigProvider.addSensorConfigurationOption(
          config,
          const StreamSensorConfigOption(),
          markPending: false,
        );
      }

      final availableValues = widget.sensorConfigProvider
          .getSensorConfigurationValues(config, distinct: true);
      if (availableValues.isEmpty) {
        continue;
      }

      final selectedValue = _selectBestValue(
        availableValues,
        targetFrequencyHz: targetFrequencyHz,
      );
      widget.sensorConfigProvider.addSensorConfiguration(
        config,
        selectedValue,
        markPending: false,
      );
      config.setConfiguration(selectedValue);
    }
  }

  SensorConfigurationValue _selectBestValue(
    List<SensorConfigurationValue> values, {
    required int targetFrequencyHz,
  }) {
    if (values.length == 1) {
      return values.first;
    }

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

  Future<void> _restoreSensorConfiguration(Sensor sensor) async {
    for (final config in sensor.relatedConfigurations) {
      try {
        final savedValue = _savedConfigurations[config];
        if (savedValue != null) {
          widget.sensorConfigProvider.addSensorConfiguration(
            config,
            savedValue,
            markPending: false,
          );
          config.setConfiguration(savedValue);
          continue;
        }

        final offValue = config.offValue;
        if (offValue != null) {
          widget.sensorConfigProvider.addSensorConfiguration(
            config,
            offValue,
            markPending: false,
          );
          config.setConfiguration(offValue);
        }

        if (config is ConfigurableSensorConfiguration &&
            config.availableOptions
                .any((option) => option is StreamSensorConfigOption)) {
          widget.sensorConfigProvider.removeSensorConfigurationOption(
            config,
            const StreamSensorConfigOption(),
            markPending: false,
          );
          final selected =
              widget.sensorConfigProvider.getSelectedConfigurationValue(config);
          if (selected is ConfigurableSensorConfigurationValue) {
            config.setConfiguration(selected);
          }
        }
      } catch (_) {
        // Continue restoring the remaining configurations.
      }
    }
  }

  void _resetStabilizationState() {
    _stabilizationStartedAt = null;
    _smoothedCoreTempCelsius = null;
    _coreTrend = const [];
    _sampleCount = 0;
  }

  Duration _stabilizationElapsed(DateTime now) {
    final startedAt = _stabilizationStartedAt;
    if (startedAt == null) {
      return Duration.zero;
    }
    final elapsed = now.difference(startedAt);
    return elapsed.isNegative ? Duration.zero : elapsed;
  }

  Duration _stabilizationRemaining(DateTime now) {
    final elapsed = _stabilizationElapsed(now);
    if (elapsed >= _minimumStabilizationDuration) {
      return Duration.zero;
    }
    return _minimumStabilizationDuration - elapsed;
  }

  bool _isStabilized(DateTime now) {
    if (_stabilizationStartedAt == null) {
      return false;
    }
    return _stabilizationElapsed(now) >= _minimumStabilizationDuration;
  }

  double _stabilizationProgress(DateTime now) {
    final elapsed = _stabilizationElapsed(now).inMilliseconds;
    final total = _minimumStabilizationDuration.inMilliseconds;
    if (total <= 0) {
      return 1.0;
    }
    return (elapsed / total).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final hasPpgSensor = widget.ppgSensor != null;
    final canStabilize = hasPpgSensor && _inEarDetected;
    final isStabilized = canStabilize && _isStabilized(now);
    final stabilizationRemaining = _stabilizationRemaining(now);
    final stabilizationProgress = _stabilizationProgress(now);
    final hasStabilizationStarted =
        canStabilize && _stabilizationStartedAt != null;
    final connected = context.watch<WearablesProvider>().wearables.any(
          (wearable) => wearable.deviceId == widget.wearable.deviceId,
        );
    final theme = Theme.of(context);
    final visibleCoreTemperature =
        isStabilized ? _smoothedCoreTempCelsius : null;
    final visibleTrend = isStabilized ? _coreTrend : const <double>[];
    final feverState = switch ((isStabilized, hasPpgSensor, _inEarDetected)) {
      (true, _, _) => _feverStateFor(visibleCoreTemperature, theme),
      (false, false, _) => _ppgRequiredStateFor(theme),
      (false, true, false) => _outOfEarStateFor(theme),
      _ => _stabilizingStateFor(
          theme,
          hasSamples: hasStabilizationStarted,
          remaining: stabilizationRemaining,
        ),
    };

    return PlatformScaffold(
      appBar: PlatformAppBar(
        title: PlatformText('Fever Thermometer'),
      ),
      body: ListView(
        padding: SensorPageSpacing.pagePadding,
        children: [
          _HeroFeverCard(
            wearableName: formatWearableDisplayName(widget.wearable.name),
            connected: connected,
            state: feverState,
            coreTempCelsius: visibleCoreTemperature,
            streamError: _temperatureStreamError,
            ppgError: _ppgStreamError,
            hasPpgSensor: hasPpgSensor,
            inEarDetected: _inEarDetected,
            sampleCount: _sampleCount,
            isStabilized: isStabilized,
            hasStabilizationStarted: hasStabilizationStarted,
            stabilizationRemaining: stabilizationRemaining,
            stabilizationProgress: stabilizationProgress,
            minimumStabilizationDuration: _minimumStabilizationDuration,
          ),
          const SizedBox(height: SensorPageSpacing.sectionGap),
          _ThermometerCard(
            state: feverState,
            coreTempCelsius: visibleCoreTemperature,
            coreTrend: visibleTrend,
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: _DemoOnlyFootnote(
              text:
                  'This view is for demonstration purposes only. It is not a medical device and must not be used for diagnosis, treatment, or emergency decisions.',
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroFeverCard extends StatelessWidget {
  final String wearableName;
  final bool connected;
  final _FeverState state;
  final double? coreTempCelsius;
  final String? streamError;
  final String? ppgError;
  final bool hasPpgSensor;
  final bool inEarDetected;
  final int sampleCount;
  final bool isStabilized;
  final bool hasStabilizationStarted;
  final Duration stabilizationRemaining;
  final double stabilizationProgress;
  final Duration minimumStabilizationDuration;

  const _HeroFeverCard({
    required this.wearableName,
    required this.connected,
    required this.state,
    required this.coreTempCelsius,
    required this.streamError,
    required this.ppgError,
    required this.hasPpgSensor,
    required this.inEarDetected,
    required this.sampleCount,
    required this.isStabilized,
    required this.hasStabilizationStarted,
    required this.stabilizationRemaining,
    required this.stabilizationProgress,
    required this.minimumStabilizationDuration,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final coreText = coreTempCelsius != null
        ? '${coreTempCelsius!.toStringAsFixed(1)} °C'
        : '--.- °C';
    final statusMessage = _statusMessage(
      hasPpgSensor: hasPpgSensor,
      inEarDetected: inEarDetected,
      isStabilized: isStabilized,
      hasStabilizationStarted: hasStabilizationStarted,
      stabilizationRemaining: stabilizationRemaining,
      minimumStabilizationDuration: minimumStabilizationDuration,
      stateDetail: state.detail,
    );
    final canShowProgress = !isStabilized && hasPpgSensor && inEarDetected;
    final combinedStatusPillLabel = _combinedStatusPillLabel(
      stateLabel: state.label,
      hasPpgSensor: hasPpgSensor,
      inEarDetected: inEarDetected,
    );

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            state.gradientStart,
            state.gradientEnd,
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: state.statusColor.withValues(alpha: 0.22),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  height: 34,
                  width: 34,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.thermostat_rounded,
                    color: Colors.white,
                    size: 21,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    wearableName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                _SignalPill(
                  label: connected ? 'Connected' : 'Disconnected',
                  color: connected
                      ? const Color(0xFF2F8F5B)
                      : theme.colorScheme.error,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Text(
                    coreText,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      height: 1.02,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              statusMessage,
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.white.withValues(alpha: 0.94),
                fontWeight: FontWeight.w700,
              ),
            ),
            if (canShowProgress) ...[
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: stabilizationProgress,
                  minHeight: 7,
                  backgroundColor: Colors.white.withValues(alpha: 0.2),
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            ],
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _SignalPill(
                  label: combinedStatusPillLabel,
                  color: Colors.white.withValues(alpha: 0.14),
                  textColor: Colors.white,
                ),
                _SignalPill(
                  label: _sampleLabel(sampleCount),
                  color: Colors.white.withValues(alpha: 0.14),
                  textColor: Colors.white,
                ),
              ],
            ),
            if (streamError != null) ...[
              const SizedBox(height: 10),
              Text(
                streamError!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.errorContainer,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            if (ppgError != null) ...[
              const SizedBox(height: 6),
              Text(
                ppgError!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.errorContainer,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static String _sampleLabel(int count) {
    if (count <= 0) {
      return 'No samples yet';
    }
    return '$count samples';
  }

  static String _statusMessage({
    required bool hasPpgSensor,
    required bool inEarDetected,
    required bool isStabilized,
    required bool hasStabilizationStarted,
    required Duration stabilizationRemaining,
    required Duration minimumStabilizationDuration,
    required String stateDetail,
  }) {
    if (isStabilized) {
      return stateDetail;
    }

    if (!hasPpgSensor) {
      return 'In-ear placement check is required. Result stays hidden.';
    }

    if (!inEarDetected) {
      return 'Reinsert device to restart the timer.';
    }

    if (hasStabilizationStarted) {
      return 'Stabilizing for ${_formatClock(stabilizationRemaining)} more. Result unlocks after ${minimumStabilizationDuration.inMinutes} minutes.';
    }

    return 'Stabilization starts after first optical sample. Result is hidden until ${minimumStabilizationDuration.inMinutes} minutes are complete.';
  }

  static String _combinedStatusPillLabel({
    required String stateLabel,
    required bool hasPpgSensor,
    required bool inEarDetected,
  }) {
    if (!hasPpgSensor) {
      return '$stateLabel • In-ear check missing';
    }
    return '$stateLabel • ${inEarDetected ? 'In ear' : 'Out of ear'}';
  }

  static String _formatClock(Duration duration) {
    final totalSeconds = max(0, duration.inSeconds);
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}

class _ThermometerCard extends StatelessWidget {
  final _FeverState state;
  final double? coreTempCelsius;
  final List<double> coreTrend;

  const _ThermometerCard({
    required this.state,
    required this.coreTempCelsius,
    required this.coreTrend,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final valueText = coreTempCelsius != null
        ? '${coreTempCelsius!.toStringAsFixed(1)} °C'
        : '--.- °C';

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Fever Thermometer',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              'Adjusted core estimate with recent trend.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ThermometerGauge(
                  valueCelsius: coreTempCelsius,
                  fillColor: state.statusColor,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        valueText,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: state.statusColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        state.label,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (coreTrend.length > 1)
                        Container(
                          height: 70,
                          padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
                          decoration: BoxDecoration(
                            color: state.statusColor.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: state.statusColor.withValues(alpha: 0.2),
                            ),
                          ),
                          child: _TemperatureTrendSparkline(
                            values: coreTrend,
                            color: state.statusColor,
                          ),
                        )
                      else
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest
                                .withValues(alpha: 0.42),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'Collecting enough samples for trend view...',
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
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

class _DemoOnlyFootnote extends StatelessWidget {
  final String text;

  const _DemoOnlyFootnote({
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
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
            text,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ),
      ],
    );
  }
}

class _ThermometerGauge extends StatelessWidget {
  final double? valueCelsius;
  final Color fillColor;

  const _ThermometerGauge({
    required this.valueCelsius,
    required this.fillColor,
  });

  @override
  Widget build(BuildContext context) {
    const minCelsius = 35.0;
    const maxCelsius = 41.0;
    final theme = Theme.of(context);
    final normalized = valueCelsius == null
        ? 0.0
        : ((valueCelsius! - minCelsius) / (maxCelsius - minCelsius))
            .clamp(0.0, 1.0);
    final ticks = List<double>.generate(7, (index) => 35.0 + index.toDouble());

    return SizedBox(
      width: 122,
      height: 226,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 30,
            bottom: 20,
            child: Stack(
              alignment: Alignment.bottomCenter,
              children: [
                Container(
                  width: 34,
                  height: 162,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: theme.colorScheme.outline.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(5, 5, 5, 5),
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 340),
                        curve: Curves.easeOutCubic,
                        width: double.infinity,
                        height: max(0, 152 * normalized),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(999),
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [
                              fillColor.withValues(alpha: 0.92),
                              fillColor.withValues(alpha: 0.55),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: -18,
                  child: Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.bottomLeft,
                        end: Alignment.topRight,
                        colors: [
                          fillColor.withValues(alpha: 0.95),
                          fillColor.withValues(alpha: 0.72),
                        ],
                      ),
                      border: Border.all(
                        color: fillColor.withValues(alpha: 0.34),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          ...ticks.map((tick) {
            final fraction = (tick - minCelsius) / (maxCelsius - minCelsius);
            final topPosition = 10 + (1 - fraction) * 162;

            return Positioned(
              left: 72,
              top: topPosition,
              child: Row(
                children: [
                  Container(
                    width: 14,
                    height: 1.4,
                    color: theme.colorScheme.onSurfaceVariant
                        .withValues(alpha: 0.44),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${tick.toStringAsFixed(0)}°',
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _TemperatureTrendSparkline extends StatelessWidget {
  final List<double> values;
  final Color color;

  const _TemperatureTrendSparkline({
    required this.values,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _TrendPainter(
        values: values,
        lineColor: color,
      ),
      child: const SizedBox.expand(),
    );
  }
}

class _TrendPainter extends CustomPainter {
  final List<double> values;
  final Color lineColor;

  _TrendPainter({
    required this.values,
    required this.lineColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2 || size.width <= 0 || size.height <= 0) {
      return;
    }

    var minValue = values.first;
    var maxValue = values.first;
    for (final value in values) {
      minValue = min(minValue, value);
      maxValue = max(maxValue, value);
    }
    if ((maxValue - minValue).abs() < 0.05) {
      maxValue = minValue + 0.05;
    }

    final path = Path();
    final areaPath = Path();
    for (int i = 0; i < values.length; i++) {
      final x = (i / (values.length - 1)) * size.width;
      final normalized = (values[i] - minValue) / (maxValue - minValue);
      final y = size.height - normalized * size.height;
      if (i == 0) {
        path.moveTo(x, y);
        areaPath.moveTo(x, size.height);
        areaPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        areaPath.lineTo(x, y);
      }
    }
    areaPath.lineTo(size.width, size.height);
    areaPath.close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          lineColor.withValues(alpha: 0.28),
          lineColor.withValues(alpha: 0.02),
        ],
      ).createShader(Offset.zero & size);
    canvas.drawPath(areaPath, fillPaint);

    final linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 2.1
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, linePaint);
  }

  @override
  bool shouldRepaint(covariant _TrendPainter oldDelegate) {
    return oldDelegate.values != values || oldDelegate.lineColor != lineColor;
  }
}

class _SignalPill extends StatelessWidget {
  final String label;
  final Color color;
  final Color? textColor;

  const _SignalPill({
    required this.label,
    required this.color,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: textColor ?? Colors.white,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

class _FeverState {
  final String label;
  final String detail;
  final Color statusColor;
  final Color gradientStart;
  final Color gradientEnd;

  const _FeverState({
    required this.label,
    required this.detail,
    required this.statusColor,
    required this.gradientStart,
    required this.gradientEnd,
  });
}

String _formatClockDuration(Duration duration) {
  final totalSeconds = max(0, duration.inSeconds);
  final minutes = totalSeconds ~/ 60;
  final seconds = totalSeconds % 60;
  return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
}

_FeverState _stabilizingStateFor(
  ThemeData theme, {
  required bool hasSamples,
  required Duration remaining,
}) {
  if (!hasSamples) {
    return _FeverState(
      label: 'Waiting for data',
      detail:
          'Insert the device into your ear and keep still to start stabilization.',
      statusColor: theme.colorScheme.primary,
      gradientStart: const Color(0xFF7A6552),
      gradientEnd: const Color(0xFF9C826D),
    );
  }

  return _FeverState(
    label: 'Stabilizing',
    detail:
        'Measuring for stability. ${_formatClockDuration(remaining)} remaining before result.',
    statusColor: theme.colorScheme.primary,
    gradientStart: const Color(0xFF7A6552),
    gradientEnd: const Color(0xFF9C826D),
  );
}

_FeverState _ppgRequiredStateFor(ThemeData theme) {
  return _FeverState(
    label: 'In-ear check required',
    detail:
        'This demo needs an in-ear placement check to verify the device is inserted.',
    statusColor: theme.colorScheme.error,
    gradientStart: const Color(0xFF8A5D54),
    gradientEnd: const Color(0xFFB0766A),
  );
}

_FeverState _outOfEarStateFor(ThemeData theme) {
  return _FeverState(
    label: 'Out of ear',
    detail: 'Device appears out of ear. Reinsert it and keep it steady.',
    statusColor: theme.colorScheme.error,
    gradientStart: const Color(0xFF8A5D54),
    gradientEnd: const Color(0xFFB0766A),
  );
}

_FeverState _feverStateFor(double? value, ThemeData theme) {
  if (value == null) {
    return _FeverState(
      label: 'Waiting for data',
      detail: 'Insert device into ear to start.',
      statusColor: theme.colorScheme.primary,
      gradientStart: const Color(0xFF7A6552),
      gradientEnd: const Color(0xFF9C826D),
    );
  }

  if (value < 35.5) {
    return const _FeverState(
      label: 'Below baseline',
      detail: 'Reading is lower than typical core-body range.',
      statusColor: Color(0xFF3C86C2),
      gradientStart: Color(0xFF507DB0),
      gradientEnd: Color(0xFF6B9AC7),
    );
  }
  if (value < 37.5) {
    return const _FeverState(
      label: 'Normal',
      detail: 'Estimated core temperature is within normal range.',
      statusColor: Color(0xFF2F8F5B),
      gradientStart: Color(0xFF4B8D66),
      gradientEnd: Color(0xFF6AAC7F),
    );
  }
  if (value < 38.0) {
    return const _FeverState(
      label: 'Elevated',
      detail: 'Temperature is mildly elevated; keep monitoring.',
      statusColor: Color(0xFFC18C2C),
      gradientStart: Color(0xFFAA7A2A),
      gradientEnd: Color(0xFFCB9A41),
    );
  }
  if (value < 39.5) {
    return const _FeverState(
      label: 'Fever',
      detail: 'Estimated fever range detected.',
      statusColor: Color(0xFFC75E2F),
      gradientStart: Color(0xFFB5562D),
      gradientEnd: Color(0xFFD27A45),
    );
  }
  return const _FeverState(
    label: 'High fever',
    detail: 'High temperature estimate. Please verify with care.',
    statusColor: Color(0xFFC53A3A),
    gradientStart: Color(0xFFA73636),
    gradientEnd: Color(0xFFCD5D50),
  );
}
