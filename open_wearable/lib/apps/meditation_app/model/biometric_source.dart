import 'dart:async';
import 'dart:math';

import 'package:open_earable_flutter/open_earable_flutter.dart';
import 'package:open_wearable/view_models/sensor_configuration_provider.dart';
import 'package:flutter/foundation.dart';

import '../configs/bio_adaptive_mode_config.dart';
import 'hr_hrv_processor.dart';
import 'hr_hrv_diagnostics.dart';
import 'sensor_sample_decoding.dart';
import 'activity_tracker.dart';

abstract interface class BiometricSource {
  // The stream of HR/HRV samples, needs to be broadcasted
  Stream<HeartRateSample> get biometrics;

  // Current activity level, needs to be broadcasted
  ValueListenable<ActivityLevel> get activityLevel;

  // Whether stress detection should be suppressed (e.g. due to high activity)
  bool get suppressStressDetection;

  /// Whether sensor samples are still arriving.
  ///
  /// Goes false when the stream stops delivering, whether the earbud dropped,
  /// the BLE link stalled, or the sensor was turned off. Without it a dead
  /// link is indistinguishable from a poor signal: the session keeps counting
  /// down a baseline it can never finish.
  ValueListenable<bool> get signalAlive;

  /// Resolves the strongest baseline estimate available at the end of a
  /// time-constrained measurement. Sensor implementations may use retained
  /// conditioned signal that is intentionally not part of the live stream.
  HeartRateSample? finalizeBaselineEstimate();

  void beginCalibration();
  void beginMeasurement();
  void start();
  void pause();
  void resume();
  void dispose();
}

class SensorBiometricSource implements BiometricSource {
  // Lightweight A/B check: no JSONL recording or per-sample timing.
  static const bool _logPpgRate =
      kDebugMode && bool.fromEnvironment('MEDITATION_PPG_RATE_LOG');

  final Sensor ppgSensor;
  final Sensor accelerometerSensor;
  final Sensor gyroscopeSensor;
  final SensorConfigurationProvider sensorConfigProvider;

  final Duration? hrvMinimumWindow;
  final Duration? metricWindowDuration;
  final bool publishBestEffortEstimates;
  final bool startInCalibration;

  SensorBiometricSource({
    required this.ppgSensor,
    required this.accelerometerSensor,
    required this.gyroscopeSensor,
    required this.sensorConfigProvider,
    this.hrvMinimumWindow,
    this.metricWindowDuration,
    this.publishBestEffortEstimates = false,
    this.startInCalibration = false,
  });

  late final Stream<PpgOpticalSample> _ppgStream;
  late final Stream<PpgMotionSample> _accelerometerStream;
  late final HrHrvProcessor _processor;
  late final ActivityTracker _activityTracker;
  HrHrvDiagnosticsRecorder? _diagnosticsRecorder;
  HrHrvSignalCapture? _rawPpgCapture;
  HrHrvSignalCapture? _rawMotionCapture;
  Stopwatch? _ppgDeliveryClock;
  Timer? _ppgDeliveryTimer;
  int _ppgDeliveryWindowStartUs = 0;
  int _ppgDeliveredCount = 0;
  int _ppgProcessingTotalUs = 0;
  int _ppgProcessingMaximumUs = 0;
  int? _ppgLastDeliveredTimestamp;
  Stopwatch? _ppgRateClock;
  Timer? _ppgRateTimer;
  int _ppgRateWindowStartMs = 0;
  int _ppgRateSampleCount = 0;
  int? _ppgRateFirstTimestamp;
  int? _ppgRateLastTimestamp;

  /// Sample rates this device reports as selectable, per sensor. Populated
  /// during [start] and reported through the existing diagnostics.
  final Map<String, List<double>> _offeredFrequenciesHz = {};

  StreamSubscription<PpgOpticalSample>? _ppgSubscription;
  StreamSubscription<PpgMotionSample>? _accelSubscription;

  bool _started = false;

  @override
  Stream<HeartRateSample> get biometrics => _processor.biometricStream;

  @override
  ValueListenable<ActivityLevel> get activityLevel =>
      _activityTracker.activityLevel;

  @override
  bool get suppressStressDetection =>
      _activityTracker.shouldSuppressStressDetection();

  @override
  HeartRateSample? finalizeBaselineEstimate() =>
      _processor.finalizeBaselineEstimate();

  @override
  void start() {
    // Configure the sensor for streaming and get the sample frequency
    final double ppgFreq = _configureSensorForStreaming(
      ppgSensor,
      sensorConfigProvider,
      fallbackFrequency: BioAdaptiveModeConfig.ppgFallbackFrequencyHz,
      targetFrequencyHz: BioAdaptiveModeConfig.ppgTargetFrequencyHz,
    );
    final double accelerometerFreq = _configureSensorForStreaming(
      accelerometerSensor,
      sensorConfigProvider,
      fallbackFrequency: BioAdaptiveModeConfig.accelerometerFallbackFrequencyHz,
      targetFrequencyHz: BioAdaptiveModeConfig.accelerometerTargetFrequencyHz,
    );
    final double gyroscopeFreq = _configureSensorForStreaming(
      gyroscopeSensor,
      sensorConfigProvider,
      fallbackFrequency: BioAdaptiveModeConfig.gyroscopeFallbackFrequencyHz,
      targetFrequencyHz: BioAdaptiveModeConfig.gyroscopeTargetFrequencyHz,
    );
    if (_logPpgRate) {
      debugPrint('Meditation selected sensor rates: PPG=$ppgFreq Hz, '
          'accelerometer=$accelerometerFreq Hz, '
          'gyroscope=$gyroscopeFreq Hz');
      _offeredFrequenciesHz.forEach((sensorName, frequencies) {
        debugPrint('Meditation rates offered by $sensorName: $frequencies');
      });
    }

    // Create the streams for PPG, accelerometer and gyroscope data
    _ppgStream = ppgSensor.sensorStream
        .map<PpgOpticalSample?>((data) {
          final values = sensorValuesAsDoubles(data);
          if (values == null) {
            return null;
          }
          return extractPpgOpticalSample(ppgSensor, data, values);
        })
        .where((sample) => sample != null)
        .cast<PpgOpticalSample>()
        .asBroadcastStream();

    _accelerometerStream = accelerometerSensor.sensorStream
        .map<PpgMotionSample?>((data) {
          final values = sensorValuesAsDoubles(data);
          if (values == null) {
            return null;
          }
          return extractImuMotionSample(
            accelerometerSensor,
            data,
            values,
          );
        })
        .where((sample) => sample != null)
        .cast<PpgMotionSample>()
        .asBroadcastStream();

    final gyroscopeStream = gyroscopeSensor.sensorStream
        .map<PpgMotionSample?>((data) {
          final values = sensorValuesAsDoubles(data);
          if (values == null) {
            return null;
          }
          return extractImuMotionSample(
            gyroscopeSensor,
            data,
            values,
          );
        })
        .where((sample) => sample != null)
        .cast<PpgMotionSample>()
        .asBroadcastStream();

    // Create the HR/HRV processor and activity tracker
    if (HrHrvDiagnosticSettings.enabled) {
      _diagnosticsRecorder = HrHrvDiagnosticsRecorder();
      _diagnosticsRecorder?.record({
        'event': 'sensor_metadata',
        'ppg_axis_names': ppgSensor.axisNames,
        'accelerometer_axis_names': accelerometerSensor.axisNames,
        'configured_ppg_hz': ppgFreq,
        'configured_accelerometer_hz': accelerometerFreq,
        'configured_gyroscope_hz': gyroscopeFreq,
        'offered_frequencies_hz': _offeredFrequenciesHz,
        'requested_ppg_hz': BioAdaptiveModeConfig.ppgTargetFrequencyHz,
        'requested_accelerometer_hz':
            BioAdaptiveModeConfig.accelerometerTargetFrequencyHz,
        'requested_gyroscope_hz':
            BioAdaptiveModeConfig.gyroscopeTargetFrequencyHz,
        'ppg_timestamp_exponent': ppgSensor.timestampExponent,
        'accelerometer_timestamp_exponent':
            accelerometerSensor.timestampExponent,
      });
      _ppgDeliveryClock = Stopwatch()..start();

      if (HrHrvDiagnosticSettings.signalCaptureEnabled) {
        final sink = _diagnosticsRecorder!.record;
        // The raw optical and motion streams are what the processor consumes,
        // so capturing them here makes an offline replay exact rather than
        // approximate: conditioning can be re-run with different filters.
        _rawPpgCapture = HrHrvSignalCapture(
          event: 'ppg_raw_block',
          channelNames: const ['red', 'ir', 'green', 'ambient'],
          sink: sink,
        );
        _rawMotionCapture = HrHrvSignalCapture(
          event: 'imu_raw_block',
          channelNames: const ['x', 'y', 'z'],
          sink: sink,
          blockSize: 50,
        );
      }
    }
    if (_logPpgRate) {
      _ppgRateClock = Stopwatch()..start();
    }
    _processor = HrHrvProcessor(
      sampleFreq: ppgFreq,
      accelerometerFreq: accelerometerFreq,
      timestampExponent: ppgSensor.timestampExponent,
      hrvMinimumWindow: hrvMinimumWindow,
      metricWindowDuration: metricWindowDuration,
      publishBestEffortEstimates: publishBestEffortEstimates,
      diagnostics: _diagnosticsRecorder?.record,
    );
    if (startInCalibration) {
      _processor.beginCalibration();
    }
    _activityTracker = ActivityTracker(
      accelerometerStream: _accelerometerStream,
      gyroscopeStream: gyroscopeStream,
      timestampExponentAccelerometer: accelerometerSensor.timestampExponent,
      timestampExponentGyroscope: gyroscopeSensor.timestampExponent,
      // The firmware reports its own angular-rate unit; the tracker converts
      // from it rather than assuming radians.
      gyroscopeUnit: gyroscopeSensor.axisUnits.isEmpty
          ? null
          : gyroscopeSensor.axisUnits.first,
    );

    // Subscribe to the streams and start processing
    _subscribe();
    _activityTracker.start();
    _started = true;
  }

  @override
  void pause() {
    if (!_started) return;
    _diagnosticsRecorder?.record({'event': 'stream_paused'});
    // A paused session is not a lost signal; stop watching rather than
    // reporting the deliberate silence as a dropped earbud.
    _signalWatchdog?.cancel();
    _lastPpgSampleAt = null;
    _stopPpgDeliveryTrace();
    _stopPpgRateLog();
    _ppgSubscription?.cancel();
    _accelSubscription?.cancel();
    _activityTracker.pause();
  }

  @override
  void beginCalibration() {
    if (_started) _processor.beginCalibration();
  }

  @override
  void beginMeasurement() {
    if (_started) _processor.beginMeasurement();
  }

  @override
  void resume() {
    if (!_started) return;
    _diagnosticsRecorder?.record({'event': 'stream_resumed'});
    _startPpgDeliveryTrace();
    _subscribe();
    _activityTracker.start();
  }

  @override
  void dispose() {
    _signalWatchdog?.cancel();
    _signalAlive.dispose();
    _stopPpgDeliveryTrace();
    _stopPpgRateLog();
    _ppgSubscription?.cancel();
    _accelSubscription?.cancel();
    if (_started) {
      _activityTracker.dispose();
      _processor.dispose();
    }
    // Emit whatever is still buffered before the sink closes, so the final
    // seconds of a session survive in the capture.
    _rawPpgCapture?.flush();
    _rawMotionCapture?.flush();
    _rawPpgCapture = null;
    _rawMotionCapture = null;
    final recorder = _diagnosticsRecorder;
    _diagnosticsRecorder = null;
    if (recorder != null) {
      recorder.record({'event': 'stream_disposed'});
      unawaited(recorder.close());
    }

    scheduleMicrotask(() {
      _turnOffSensor(ppgSensor);
      _turnOffSensor(accelerometerSensor);
      _turnOffSensor(gyroscopeSensor);
    });
  }

  /// Flipped by [_signalWatchdog] when no PPG sample has arrived recently.
  final ValueNotifier<bool> _signalAlive = ValueNotifier(true);
  DateTime? _lastPpgSampleAt;
  Timer? _signalWatchdog;

  @override
  ValueListenable<bool> get signalAlive => _signalAlive;

  void _startSignalWatchdog() {
    _signalWatchdog?.cancel();
    _lastPpgSampleAt = DateTime.now();
    _signalAlive.value = true;
    _signalWatchdog = Timer.periodic(
      BioAdaptiveModeConfig.sensorSignalCheckInterval,
      (_) => _evaluateSignalLiveness(),
    );
  }

  void _evaluateSignalLiveness() {
    final last = _lastPpgSampleAt;
    if (last == null) return;
    final silentFor = DateTime.now().difference(last);
    final alive = silentFor < BioAdaptiveModeConfig.sensorSignalTimeout;
    if (alive == _signalAlive.value) return;
    _signalAlive.value = alive;
    recordDiagnosticEvent(
      alive ? 'sensor_signal_restored' : 'sensor_signal_lost',
      {'silent_ms': silentFor.inMilliseconds},
    );
  }

  /// A stream that ends or errors delivers nothing further, so the watchdog
  /// would eventually notice anyway; saying so immediately avoids the wait.
  void _onSensorStreamEnded(String sensor, [Object? error]) {
    debugPrint('Meditation $sensor stream ended${error == null ? '' : ': '
        '$error'}');
    recordDiagnosticEvent('sensor_stream_ended', {
      'sensor': sensor,
      'error_type': error?.runtimeType.toString(),
    });
    if (sensor != 'ppg') return;
    _signalAlive.value = false;
  }

  void _subscribe() {
    _startSignalWatchdog();
    _startPpgDeliveryTrace();
    _startPpgRateLog();
    _ppgSubscription?.cancel();
    _ppgSubscription = _ppgStream.listen(
      (data) {
        _lastPpgSampleAt = DateTime.now();
        if (!_signalAlive.value) _evaluateSignalLiveness();
        final clock = _ppgDeliveryClock;
        final startedUs = clock?.elapsedMicroseconds;
        _rawPpgCapture?.add(
          data.timestamp,
          [data.red, data.ir, data.green, data.ambient],
        );
        _processor.processPpgSample(
          data.timestamp,
          data.red,
          data.ir,
          data.green,
          data.ambient,
        );
        if (_ppgRateClock != null) {
          _ppgRateFirstTimestamp ??= data.timestamp;
          _ppgRateLastTimestamp = data.timestamp;
          _ppgRateSampleCount++;
        }
        if (clock != null && startedUs != null) {
          final processingUs = clock.elapsedMicroseconds - startedUs;
          _ppgDeliveredCount++;
          _ppgProcessingTotalUs += processingUs;
          if (processingUs > _ppgProcessingMaximumUs) {
            _ppgProcessingMaximumUs = processingUs;
          }
          _ppgLastDeliveredTimestamp = data.timestamp;
        }
      },
      onError: (Object error) => _onSensorStreamEnded('ppg', error),
      onDone: () => _onSensorStreamEnded('ppg'),
    );

    _accelSubscription?.cancel();
    _accelSubscription = _accelerometerStream.listen(
      (data) {
        _rawMotionCapture?.add(data.timestamp, [data.x, data.y, data.z]);
        _processor.processAccelerometerSample(
          data.timestamp,
          data.x,
          data.y,
          data.z,
        );
      },
      onError: (Object error) => _onSensorStreamEnded('accelerometer', error),
      onDone: () => _onSensorStreamEnded('accelerometer'),
    );
  }

  /// Session events share the same local, debug-only trace as the PPG data.
  void recordDiagnosticEvent(
    String event, [
    Map<String, Object?> values = const {},
  ]) {
    _diagnosticsRecorder?.record({'event': event, ...values});
  }

  void _startPpgDeliveryTrace() {
    final clock = _ppgDeliveryClock;
    if (clock == null || _ppgDeliveryTimer != null) return;
    _ppgDeliveryWindowStartUs = clock.elapsedMicroseconds;
    _ppgDeliveredCount = 0;
    _ppgProcessingTotalUs = 0;
    _ppgProcessingMaximumUs = 0;
    _ppgDeliveryTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final elapsedUs = clock.elapsedMicroseconds;
      final count = _ppgDeliveredCount;
      recordDiagnosticEvent('ppg_delivery', {
        'wall_elapsed_ms': (elapsedUs - _ppgDeliveryWindowStartUs) / 1000.0,
        'sample_count': count,
        'processing_mean_us': count == 0 ? null : _ppgProcessingTotalUs / count,
        'processing_max_us': count == 0 ? null : _ppgProcessingMaximumUs,
        'last_sensor_timestamp_ticks': _ppgLastDeliveredTimestamp,
      });
      _ppgDeliveryWindowStartUs = elapsedUs;
      _ppgDeliveredCount = 0;
      _ppgProcessingTotalUs = 0;
      _ppgProcessingMaximumUs = 0;
    });
  }

  void _stopPpgDeliveryTrace() {
    _ppgDeliveryTimer?.cancel();
    _ppgDeliveryTimer = null;
  }

  void _startPpgRateLog() {
    final clock = _ppgRateClock;
    if (clock == null || _ppgRateTimer != null) return;
    _ppgRateWindowStartMs = clock.elapsedMilliseconds;
    _ppgRateSampleCount = 0;
    _ppgRateFirstTimestamp = null;
    _ppgRateLastTimestamp = null;
    _ppgRateTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      final nowMs = clock.elapsedMilliseconds;
      final wallSeconds = (nowMs - _ppgRateWindowStartMs) / 1000.0;
      final first = _ppgRateFirstTimestamp;
      final last = _ppgRateLastTimestamp;
      final sensorSeconds = first == null || last == null
          ? null
          : (last - first) * pow(10, ppgSensor.timestampExponent).toDouble();
      debugPrint('Meditation PPG delivery: '
          '${(wallSeconds > 0 ? _ppgRateSampleCount / wallSeconds : 0).toStringAsFixed(1)} samples/s '
          '($_ppgRateSampleCount in ${wallSeconds.toStringAsFixed(1)}s; '
          'sensor span ${sensorSeconds?.toStringAsFixed(1) ?? "n/a"}s)');
      _ppgRateWindowStartMs = nowMs;
      _ppgRateSampleCount = 0;
      _ppgRateFirstTimestamp = null;
      _ppgRateLastTimestamp = null;
    });
  }

  void _stopPpgRateLog() {
    _ppgRateTimer?.cancel();
    _ppgRateTimer = null;
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
    // The selectable rates come from the device's sensor scheme at runtime, so
    // they cannot be read from the app's configuration. Record them so a single
    // instrumented run reveals which rates this firmware actually offers.
    _offeredFrequenciesHz[sensor.sensorName] = values
        .whereType<SensorFrequencyConfigurationValue>()
        .map((value) => value.frequencyHz)
        .toList(growable: false)
      ..sort();
    SensorConfigurationValue? appliedValue;
    if (values.isNotEmpty) {
      appliedValue = selectBestConfigurationValue(
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

  void _turnOffSensor(Sensor sensor) {
    final configuration = sensor.relatedConfigurations.firstOrNull;
    final offValue = configuration?.offValue;
    if (configuration == null || offValue == null) {
      return;
    }

    sensorConfigProvider.addSensorConfiguration(
      configuration,
      offValue,
      markPending: false,
    );
    configuration.setConfiguration(offValue);
  }
}

/// Replays the recording-derived stress trajectory from the original app.
///
/// The centre line is the original two-minute scenario: HR 71 -> 80 -> 97
/// BPM and RMSSD 80 -> 50 -> 12 ms. The first transition lasts 90 seconds and
/// the stress spike lasts another 30 seconds. The small mean-reverting
/// variation is also retained from the original implementation so the signal
/// has the same natural character instead of looking perfectly linear.
class RecordedStressBiometricSource implements BiometricSource {
  final ValueNotifier<ActivityLevel> _activityLevel;

  static const double baselineHeartRate =
      BioAdaptiveModeConfig.recordedStressBaselineHeartRate;
  static const double baselineRmssd =
      BioAdaptiveModeConfig.recordedStressBaselineRmssd;
  static const double buildUpHeartRate =
      BioAdaptiveModeConfig.recordedStressBuildUpHeartRate;
  static const double buildUpRmssd =
      BioAdaptiveModeConfig.recordedStressBuildUpRmssd;
  static const double peakHeartRate =
      BioAdaptiveModeConfig.recordedStressPeakHeartRate;
  static const double peakRmssd = BioAdaptiveModeConfig.recordedStressPeakRmssd;

  RecordedStressBiometricSource({
    required ActivityLevel restingActivityLevel,
  }) : _activityLevel = ValueNotifier<ActivityLevel>(restingActivityLevel);

  final _controller = StreamController<HeartRateSample>.broadcast();

  final Stopwatch _clock = Stopwatch();
  Timer? _timer;
  bool _measurementEnabled = true;
  HeartRateSample? _latestEstimate;
  bool _relaxationActive = false;
  double _relaxationStartHr = peakHeartRate;
  double _relaxationStartHrv = peakRmssd;

  /// The scripted source generates its own samples, so its signal is only
  /// absent once it has been stopped.
  final ValueNotifier<bool> _signalAlive = ValueNotifier(true);

  @override
  ValueListenable<bool> get signalAlive => _signalAlive;

  @override
  Stream<HeartRateSample> get biometrics => _controller.stream;

  @override
  ValueListenable<ActivityLevel> get activityLevel => _activityLevel;

  @override
  bool get suppressStressDetection => false;

  @override
  HeartRateSample? finalizeBaselineEstimate() => _latestEstimate;

  @override
  void beginCalibration() {
    _measurementEnabled = false;
    _latestEstimate = null;
  }

  @override
  void beginMeasurement() {
    _measurementEnabled = true;
  }

  // --- Ornstein-Uhlenbeck wandering state (gives the ramp a realistic wobble)
  double _hrOuState = 0;
  double _hrvOuState = 0;
  double _gaussianSpare = 0;
  bool _hasGaussianSpare = false;
  final Random _random = Random();
  static const double _ouAlpha = BioAdaptiveModeConfig.recordedStressOuAlpha;

  static const double _hrOuSigmaStep =
      BioAdaptiveModeConfig.recordedStressHrOuSigmaStep;
  static const double _buildUpEndSec =
      BioAdaptiveModeConfig.recordedStressBuildUpEndSeconds;
  static const double _spikeEndSec =
      BioAdaptiveModeConfig.recordedStressSpikeEndSeconds;

  // The original app started this six-minute recovery when the meditation
  // began, allowing its normal HR-based early-exit behavior to remain intact.
  static const double _relaxationTargetHr =
      BioAdaptiveModeConfig.relaxationTargetHeartRate;
  static const double _relaxationTargetHrv =
      BioAdaptiveModeConfig.relaxationTargetRmssd;
  static const double _relaxationDurationSec =
      BioAdaptiveModeConfig.relaxationDurationSeconds;

  @override
  void start() {
    _resetScenarioState();
    _latestEstimate = null;
    _clock
      ..reset()
      ..start();
    _startTimer();
  }

  @override
  void pause() {
    _clock.stop();
    _timer?.cancel();
  }

  @override
  void resume() {
    _clock.start();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.close();
    _activityLevel.dispose();
  }

  void _resetScenarioState() {
    _hrOuState = 0;
    _hrvOuState = 0;
    _hasGaussianSpare = false;
    _relaxationActive = false;
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(
      BioAdaptiveModeConfig.recordedStressSampleInterval,
      (_) {
        _emitNextSample();
      },
    );
  }

  void _emitNextSample() {
    if (!_measurementEnabled) return;
    final tSec = _clock.elapsed.inSeconds.toDouble();
    final (hr, hrv) = _relaxationActive
        ? _relaxationValues(tSec)
        : stressTrajectoryAt(_clock.elapsed);

    // Mean-reverting random walk around the deterministic trend.
    _hrOuState = (_ouAlpha * _hrOuState) + (_hrOuSigmaStep * _gaussian());
    final hrvOuSigma = (hrv * 0.025).clamp(0.5, 3.0);
    _hrvOuState = (_ouAlpha * _hrvOuState) + (hrvOuSigma * _gaussian());

    // Floors only — an upper clamp here would quietly clip a caller that asked
    // for a peak above it.
    final noisyHr = max(1.0, hr + _hrOuState);
    final noisyHrv = max(1.0, hrv + _hrvOuState);

    final sample = HeartRateSample(
      heartRate: noisyHr.round(),
      rmssd: noisyHrv,
    );
    _latestEstimate = sample;
    _controller.add(sample);
  }

  /// Returns the exact centre line of the old recording-derived scenario.
  /// Exposed as a pure function so its keyframes cannot silently drift.
  static (double heartRate, double rmssd) stressTrajectoryAt(
    Duration elapsed,
  ) {
    final tSec = max(0, elapsed.inSeconds).toDouble();
    if (tSec <= _buildUpEndSec) {
      final fraction = tSec / _buildUpEndSec;
      return (
        baselineHeartRate + (buildUpHeartRate - baselineHeartRate) * fraction,
        baselineRmssd - (baselineRmssd - buildUpRmssd) * fraction,
      );
    }

    final fraction = ((tSec - _buildUpEndSec) / (_spikeEndSec - _buildUpEndSec))
        .clamp(0.0, 1.0);
    return (
      buildUpHeartRate + (peakHeartRate - buildUpHeartRate) * fraction,
      buildUpRmssd - (buildUpRmssd - peakRmssd) * fraction,
    );
  }

  /// Switches from the stress recording into the original gradual recovery
  /// once the adaptive meditation has started.
  void startRelaxationScenario() {
    final latest = _latestEstimate;
    _relaxationStartHr = latest?.heartRate.toDouble() ?? peakHeartRate;
    _relaxationStartHrv = latest?.rmssd ?? peakRmssd;
    _relaxationActive = true;
    _clock
      ..reset()
      ..start();
  }

  (double heartRate, double rmssd) _relaxationValues(double tSec) {
    final fraction = (tSec / _relaxationDurationSec).clamp(0.0, 1.0);
    final eased = fraction * (2.0 - fraction);
    return (
      _relaxationStartHr + (_relaxationTargetHr - _relaxationStartHr) * eased,
      _relaxationStartHrv +
          (_relaxationTargetHrv - _relaxationStartHrv) * eased,
    );
  }

  /// Polar Box-Muller transform — standard-normal samples for the OU wandering.
  double _gaussian() {
    if (_hasGaussianSpare) {
      _hasGaussianSpare = false;
      return _gaussianSpare;
    }
    double u, v, s;
    do {
      u = _random.nextDouble() * 2 - 1;
      v = _random.nextDouble() * 2 - 1;
      s = u * u + v * v;
    } while (s >= 1.0 || s == 0.0);
    final mul = sqrt(-2.0 * log(s) / s);
    _gaussianSpare = v * mul;
    _hasGaussianSpare = true;
    return u * mul;
  }
}
