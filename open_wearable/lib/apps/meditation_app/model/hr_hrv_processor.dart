import 'dart:async';
import 'dart:math';

import '../configs/bio_adaptive_mode_config.dart';
import 'hr_hrv_diagnostics.dart';
import 'pulse_interval_rmssd.dart';

class HeartRateSample {
  final int heartRate;
  final double? rmssd;

  const HeartRateSample({
    required this.heartRate,
    required this.rmssd,
  });
}

/// Mirrors the Heart Tracker page's PpgFilter pipeline (see
/// apps/heart_tracker/model/ppg_filter.dart): adaptive channel selection,
/// ambient-light cancellation, accelerometer-referenced motion cancellation,
/// motion-aware outlier suppression, DC-block + band-pass filtering, bounded
/// normalization, then a windowed (~1 Hz) peak detector (10s regular / 30s
/// demo buffer) with quality gating. Detected beats feed the HR estimate and
/// a rolling RR-interval history (regular: up to 5 minutes, minimum 1 minute;
/// demo: 30 seconds) used for RMSSD. Kept as a separate copy (not an import)
/// so the meditation app
/// doesn't depend on the heart_tracker app.
///
/// Unlike the Heart Tracker page, this has no gyroscope and no optical
/// temperature input, so the in-ear temperature gate is simply omitted.
///
/// NOTE: assumes the accelerometer stream reports m/s^2 (gravity ~9.81) —
/// same assumption the heart_tracker pipeline makes. If this device's
/// accelerometer reports g-units or raw counts instead, the motion
/// thresholds below will be miscalibrated.
///
/// NOTE: heart_tracker_page.dart validates this pipeline with both PPG and
/// accelerometer streamed at 50Hz. This app streams PPG at 200Hz and the
/// accelerometer at a requested 25Hz instead. PPG-stage constants below are
/// scaled for 200Hz; motion-reference EMA coefficients are derived from the
/// sensor's selected accelerometer rate to preserve their time constants.
class HrHrvProcessor {
  final double sampleFreq;
  final double accelerometerFreq;
  final int timestampExponent;
  final bool publishBestEffortEstimates;
  final HrHrvDiagnosticSink? diagnostics;
  final DateTime Function() _now;

  static const double _minBeatIntervalSec = 0.25;

  // Narrower than the 30-240 bpm accepted for a live reading: a resting
  // baseline taken from a seated person has far less room than a momentary
  // estimate, and halved or doubled beat detection lands outside this.
  static const double _minimumPlausibleBaselineBpm = 40;
  static const double _maximumPlausibleBaselineBpm = 120;
  static const double _maxBeatIntervalSec = 2.0;

  late final _AdaptiveOpticalChannelSelector _channelSelector;
  final _AmbientLightCanceler _ambientCanceler = _AmbientLightCanceler();
  late final _MotionNoiseSuppressor _motionSuppressor;
  late final _MultiReferenceMotionCanceler _imuCanceler;
  late final _HighPassFilter _dcBlockFilter;
  late final _BandPassFilter _bandPassFilter;

  // The beat-timing path deliberately uses its own filter instances fed
  // straight from the selected optical channel, so it never inherits the
  // smoothing the main chain applies upstream of these stages.
  late final _HighPassFilter _beatDcBlockFilter;
  late final _BandPassFilter _beatBandPassFilter;
  final _BoundedSignalNormalizer _normalizer = _BoundedSignalNormalizer();

  HrHrvSignalCapture? _conditionedCapture;

  /// The channel the beat-path filters currently hold state for.
  String? _beatPathChannel;

  final List<_ConditionedSample> _buffer = [];
  final List<_ConditionedSample> _deadlineEvidence = [];
  bool _collectDeadlineEvidence = false;
  int _baselineEvidenceStartIndex = 0;
  int _lastDeadlineEvaluationCount = -1;
  HeartRateSample? _deadlineEstimate;
  late final double _ticksPerSecond;
  late final double _ticksToMilliseconds;
  late final double _windowDurationTicks;
  late final double _minimumWindowTicks;
  late final double _evaluationPeriodTicks;
  double _lastEvaluationTick = double.negativeInfinity;
  double _lastDetectorComparisonTick = double.negativeInfinity;
  int? _firstMeasurementTimestamp;
  _PeakDetectionMode? _activePeakDetectionMode;
  int _poorPeakWindowCount = 0;
  int _lastCrediblePeakPairCount = 0;
  String _lastRmssdSource = 'unavailable';
  int? _traceLastPpgTimestamp;
  int? _traceHealthStartTimestamp;
  int _traceSampleCount = 0;
  int _traceGapCount = 0;
  int _traceNonIncreasingCount = 0;
  int _traceChannelChanges = 0;
  double _traceMaximumGapMs = 0;
  double _traceMinimumSelectedOptical = double.infinity;
  double _traceMaximumSelectedOptical = double.negativeInfinity;
  int _traceNonFiniteSelectedOpticalCount = 0;
  String? _tracePreviousChannel;

  double _hrEstimate = 75.0;
  double _hrCovariance = 1.0;
  bool _hasMeasuredHeartRate = false;
  final double _hrProcessNoise = 0.02;
  final double _hrMeasurementNoise = 5.0;

  // Rolling RR-interval history used for HRV (RMSSD): grows to a 5-minute
  // window and then slides, with at least 1 minute of history required
  // before HRV is reported (matches short-term HRV recording-length
  // guidance, e.g. Shaffer & Ginsberg 2017). Kept separate from `_buffer`,
  // which only holds the last 10s of conditioned *signal* for peak
  // detection — RR intervals detected from that signal are accumulated
  // here instead of being discarded once the signal buffer trims them.
  final List<_TimestampedInterval> _rrHistory = [];
  int? _lastRecordedPeakTimestamp;
  late final double _hrvWindowTicks;
  double _hrvMinimumWindowTicks = 0;

  DateTime? _firstSampleTime;
  DateTime? _lastEmitTime;
  static const Duration _warmupDuration =
      BioAdaptiveModeConfig.processorWarmupDuration;
  static const Duration _emitInterval =
      BioAdaptiveModeConfig.metricEmitInterval;

  final StreamController<HeartRateSample> _metricStreamController =
      StreamController<HeartRateSample>.broadcast();
  bool _measurementEnabled = true;

  Stream<HeartRateSample> get biometricStream => _metricStreamController.stream;

  HeartRateSample? _latestSample;
  HeartRateSample? _bestEffortEstimate;
  double _bestEffortQuality = double.negativeInfinity;

  /// Last emitted heart-rate/RMSSD sample, read synchronously — unlike
  /// [biometricStream], which only delivers *future* values to listeners.
  HeartRateSample? get latestSample => _latestSample;

  /// Highest-quality physiologically plausible estimate observed since
  /// measurement began. Unlike [latestSample], this may come from a window
  /// below the stricter continuous-monitoring publication threshold.
  HeartRateSample? get bestEffortEstimate => _bestEffortEstimate;

  /// Produces the demo's final estimate from its complete 30-second baseline.
  /// If that window is unusable, the separate 30-second calibration window is
  /// available as a deadline rescue. This is deliberately separate from the
  /// live production-quality stream and runs only when the baseline expires.
  HeartRateSample? finalizeBaselineEstimate() {
    if (!publishBestEffortEstimates) return _bestEffortEstimate;
    if (_deadlineEstimate != null) return _deadlineEstimate;

    // If the previous attempt failed, wait for roughly one additional second
    // of PPG before repeating the comparatively expensive full-window pass.
    if (_lastDeadlineEvaluationCount >= 0 &&
        _deadlineEvidence.length - _lastDeadlineEvaluationCount < sampleFreq) {
      return _bestEffortEstimate;
    }
    _lastDeadlineEvaluationCount = _deadlineEvidence.length;

    final retainedEstimate = _estimateRetainedBaseline();
    final resolved = retainedEstimate ?? _bestEffortEstimate ?? _latestSample;
    final selectedSource = retainedEstimate != null
        ? 'retained_signal'
        : _bestEffortEstimate != null
            ? 'best_effort'
            : _latestSample != null
                ? 'latest_published'
                : 'none';
    HrHrvDiagnosticSettings.logSummary(
      'Meditation baseline: HR=${resolved?.heartRate ?? "n/a"} BPM, '
      'RMSSD=${resolved?.rmssd?.toStringAsFixed(1) ?? "n/a"} ms, '
      'source=$selectedSource, '
      'detector=${_activePeakDetectionMode?.name ?? "unselected"}',
    );
    _trace('baseline_deadline', {
      'retained_samples': _deadlineEvidence.length,
      'calibration_samples': _baselineEvidenceStartIndex,
      'baseline_samples':
          _deadlineEvidence.length - _baselineEvidenceStartIndex,
      'selected_source': selectedSource,
      'heart_rate_bpm': resolved?.heartRate,
      'rmssd_ms': resolved?.rmssd,
    });
    if (resolved != null && resolved.rmssd != null) {
      _deadlineEstimate = resolved;
      _bestEffortEstimate = resolved;
      _collectDeadlineEvidence = false;
      _deadlineEvidence.clear();
    }
    return resolved;
  }

  /// Warms the complete signal-conditioning chain without admitting samples
  /// to the HR/HRV estimator. Filter state is deliberately retained.
  void beginCalibration() {
    if (!_measurementEnabled) return;
    _trace('phase_changed', {'phase': 'calibration'});
    // A new calibration re-opens the channel choice; the earbud may have been
    // refitted since the last measurement.
    _channelSelector.releaseCommitment();
    _measurementEnabled = false;
    _deadlineEvidence.clear();
    _deadlineEstimate = null;
    _baselineEvidenceStartIndex = 0;
    _lastDeadlineEvaluationCount = -1;
    _collectDeadlineEvidence = publishBestEffortEstimates;
    _clearEstimatorState();
  }

  /// Starts a fresh physiological measurement window after filter warm-up.
  /// Calibration samples cannot enter peak detection or RR history.
  void beginMeasurement() {
    if (_measurementEnabled) return;
    _trace('phase_changed', {'phase': 'measurement'});
    // Calibration exists to warm the filters; by its end there is enough
    // evidence to pick an optical channel. Freezing it here stops the
    // per-sample switching that costs beats mid-measurement.
    if (BioAdaptiveModeConfig.commitOpticalChannelAtMeasurementStart) {
      _channelSelector.commit();
      _trace('optical_channel_committed', {
        'channel': _channelSelector.committedChannel,
        'green_perfusion': _channelSelector.greenPerfusion,
        'red_perfusion': _channelSelector.redPerfusion,
        'infrared_perfusion': _channelSelector.infraredPerfusion,
      });
    }
    _baselineEvidenceStartIndex = _deadlineEvidence.length;
    _clearEstimatorState();
    _measurementEnabled = true;
  }

  void _emit(HeartRateSample sample) {
    _latestSample = sample;
    _trace('metric_published', {
      'heart_rate_bpm': sample.heartRate,
      'rmssd_ms': sample.rmssd,
    });
    _metricStreamController.add(sample);
  }

  void _trace(String event, Map<String, Object?> values) {
    diagnostics?.call({'event': event, ...values});
  }

  HrHrvProcessor({
    required this.sampleFreq,
    required this.accelerometerFreq,
    required this.timestampExponent,
    Duration? hrvMinimumWindow,
    Duration? metricWindowDuration,
    this.publishBestEffortEstimates = false,
    this.diagnostics,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now {
    _motionSuppressor = _MotionNoiseSuppressor(
      accelerometerFreq: accelerometerFreq,
    );
    _imuCanceler = _MultiReferenceMotionCanceler(
      accelerometerFreq: accelerometerFreq,
    );
    _channelSelector = _AdaptiveOpticalChannelSelector(
      useNormalizedRanking: BioAdaptiveModeConfig.useNormalizedChannelSelection,
      minimumDwellSamples:
          (BioAdaptiveModeConfig.opticalChannelDwell.inMilliseconds *
                  sampleFreq /
                  1000)
              .round(),
    );
    _dcBlockFilter = _HighPassFilter(cutoffFreq: 0.12, sampleFreq: sampleFreq);
    _bandPassFilter = _BandPassFilter(
      sampleFreq: sampleFreq,
      lowCut: 0.45,
      highCut: 5.5,
    );
    // Same coefficients: the band itself is not the problem, only what the
    // signal has been through before reaching it. Measured on real data,
    // 0.45-5.5 Hz and 0.7-3.0 Hz perform identically here.
    _beatDcBlockFilter =
        _HighPassFilter(cutoffFreq: 0.12, sampleFreq: sampleFreq);
    _beatBandPassFilter = _BandPassFilter(
      sampleFreq: sampleFreq,
      lowCut: 0.45,
      highCut: 5.5,
    );

    final diagnosticSink = diagnostics;
    if (diagnosticSink != null &&
        HrHrvDiagnosticSettings.signalCaptureEnabled) {
      // The conditioned waveform is what every detector actually sees. Keeping
      // it alongside the raw capture lets an offline replay prove it
      // reproduces the device's own conditioning before trusting its verdict.
      _conditionedCapture = HrHrvSignalCapture(
        event: 'ppg_conditioned_block',
        channelNames: const ['signal', 'motion'],
        sink: diagnosticSink,
        fractionDigits: 5,
      );
    }

    _ticksPerSecond = pow(10, -timestampExponent).toDouble();
    _ticksToMilliseconds = pow(10, timestampExponent + 3).toDouble();
    final configuredMetricWindowSeconds = metricWindowDuration == null
        ? null
        : metricWindowDuration.inMicroseconds / 1000000.0;
    _windowDurationTicks = (configuredMetricWindowSeconds ??
            BioAdaptiveModeConfig.defaultHeartRateWindowSeconds) *
        _ticksPerSecond;
    _minimumWindowTicks = (configuredMetricWindowSeconds ??
            BioAdaptiveModeConfig.defaultMetricEligibilityWindowSeconds) *
        _ticksPerSecond;
    _evaluationPeriodTicks = max(1.0, _ticksPerSecond);
    _hrvWindowTicks = (configuredMetricWindowSeconds ??
            BioAdaptiveModeConfig.defaultHrvHistoryWindowSeconds) *
        _ticksPerSecond;
    this.hrvMinimumWindow = hrvMinimumWindow ?? _defaultHrvMinimumWindow;
    _trace('processor_created', {
      'configured_ppg_hz': sampleFreq,
      'configured_accelerometer_hz': accelerometerFreq,
      'imu_gravity_alpha': _imuCanceler.gravityAlpha,
      'imu_dynamic_alpha': _imuCanceler.dynamicAlpha,
      'imu_scale_alpha': _imuCanceler.scaleAlpha,
      'motion_gravity_alpha': _motionSuppressor.gravityAlpha,
      'motion_level_alpha': _motionSuppressor.motionAlpha,
      'timestamp_exponent': timestampExponent,
      'metric_window_ms': _windowDurationTicks * _ticksToMilliseconds,
      'metric_eligibility_ms': _minimumWindowTicks * _ticksToMilliseconds,
      'hrv_history_window_ms': _hrvWindowTicks * _ticksToMilliseconds,
      'hrv_minimum_window_ms': _hrvMinimumWindowTicks * _ticksToMilliseconds,
      'best_effort_enabled': publishBestEffortEstimates,
    });
  }

  /// Minimum RR-history span required before RMSSD is reported at all.
  ///
  /// Defaults to 60s per short-term HRV recording-length guidance (Shaffer &
  /// Ginsberg 2017), which is correct for a real session but longer than the
  /// demo's compressed calibration+baseline phases — with the default, the
  /// demo's baseline phase ends before the first non-null RMSSD ever arrives,
  /// so the RMSSD baseline never adapts. Demo flows shorten this; the 5-minute
  /// *upper* window ([_hrvWindowTicks]) is deliberately not adjustable, since
  /// shortening it costs real accuracy rather than just latency.
  static const Duration _defaultHrvMinimumWindow =
      BioAdaptiveModeConfig.defaultHrvMinimumWindow;

  set hrvMinimumWindow(Duration window) {
    _hrvMinimumWindowTicks =
        (window.inMicroseconds / 1000000.0) * _ticksPerSecond;
  }

  Duration get hrvMinimumWindow => Duration(
        microseconds:
            ((_hrvMinimumWindowTicks / _ticksPerSecond) * 1000000).round(),
      );

  Duration get heartRateWindow => _durationFromTicks(_windowDurationTicks);
  Duration get metricEligibilityWindow =>
      _durationFromTicks(_minimumWindowTicks);
  Duration get hrvHistoryWindow => _durationFromTicks(_hrvWindowTicks);

  Duration _durationFromTicks(double ticks) => Duration(
        microseconds: ((ticks / _ticksPerSecond) * 1000000).round(),
      );

  /// Feeds a raw accelerometer sample (m/s^2). Used only for motion
  /// cancellation/gating, not for HR/HRV itself.
  void processAccelerometerSample(int timestamp, double x, double y, double z) {
    final magnitude = sqrt((x * x) + (y * y) + (z * z));
    _motionSuppressor.updateMotionMagnitude(magnitude);
    _imuCanceler.updateMotion(x: x, y: y, z: z);
  }

  void processPpgSample(
    int timestamp,
    double red,
    double ir,
    double green,
    double ambient,
  ) {
    final selectedOpticalSignal =
        _channelSelector.select(green: green, red: red, ir: ir);
    if (diagnostics != null) {
      _tracePpgHealth(timestamp, selectedOpticalSignal);
    }
    final ambientCanceled = _ambientCanceler.filter(
      green: selectedOpticalSignal,
      ambient: ambient,
    );
    final motionLevel = _motionSuppressor.motionLevel;
    final imuCleaned =
        _imuCanceler.filter(ambientCanceled, motionLevel: motionLevel);
    final motionSuppressed = _motionSuppressor.filter(imuCleaned);
    final dcBlocked = _dcBlockFilter.filter(motionSuppressed);
    final bandPassed = _bandPassFilter.filter(dcBlocked);
    final bounded = _normalizer.filter(bandPassed, motionLevel: motionLevel);

    // Fed from the selected channel directly, in parallel with the chain
    // above, so the sharp systolic edge survives for beat timing. A channel
    // change is a step of tens of thousands of counts; the conditioned path
    // absorbs that in its normalizer, this one has nothing to absorb it, so
    // restart the filters rather than let them ring through the step.
    final currentChannel = _channelSelector.selectedChannel;
    if (_beatPathChannel != null && _beatPathChannel != currentChannel) {
      _beatDcBlockFilter.reset();
      _beatBandPassFilter.reset();
      _trace('beat_path_filters_reset', {
        'from': _beatPathChannel,
        'to': currentChannel,
      });
    }
    _beatPathChannel = currentChannel;

    final beatSignal = _beatBandPassFilter.filter(
      _beatDcBlockFilter.filter(selectedOpticalSignal),
    );

    final conditionedSample = _ConditionedSample(
      timestamp: timestamp,
      signal: bounded,
      beatSignal: beatSignal,
      motionLevel: motionLevel,
    );
    _conditionedCapture?.add(
      timestamp,
      [bounded, motionLevel],
      context: {
        'phase': _measurementEnabled ? 'measurement' : 'calibration',
        'channel': _channelSelector.selectedChannel,
      },
    );

    if (_collectDeadlineEvidence) {
      _deadlineEvidence.add(conditionedSample);
    }

    if (!_measurementEnabled) {
      return;
    }

    _firstSampleTime ??= _now();
    _firstMeasurementTimestamp ??= timestamp;

    _buffer.add(conditionedSample);
    _buffer.removeWhere(
      (sample) => sample.timestamp < timestamp - _windowDurationTicks,
    );

    if ((timestamp - _lastEvaluationTick) < _evaluationPeriodTicks) {
      return;
    }
    _lastEvaluationTick = timestamp.toDouble();

    _evaluateVitals(timestamp);
  }

  void dispose() {
    _conditionedCapture?.flush();
    _conditionedCapture = null;
    _trace('processor_disposed', {});
    _metricStreamController.close();
  }

  void _tracePpgHealth(int timestamp, double selectedOpticalSignal) {
    final channel = _channelSelector.selectedChannel;
    final previousChannel = _tracePreviousChannel;
    if (previousChannel != null && previousChannel != channel) {
      _traceChannelChanges++;
    }
    _tracePreviousChannel = channel;

    final previousTimestamp = _traceLastPpgTimestamp;
    if (previousTimestamp != null) {
      final delta = timestamp - previousTimestamp;
      if (delta <= 0) {
        _traceNonIncreasingCount++;
        if (delta < 0) {
          _trace('timestamp_discontinuity', {
            'previous_timestamp_ticks': previousTimestamp,
            'current_timestamp_ticks': timestamp,
          });
          _traceHealthStartTimestamp = timestamp;
          _traceSampleCount = 0;
        }
      } else {
        final gapMs = delta * _ticksToMilliseconds;
        _traceMaximumGapMs = max(_traceMaximumGapMs, gapMs);
        if (delta > (2.5 * _ticksPerSecond / sampleFreq)) {
          _traceGapCount++;
        }
      }
    }
    _traceLastPpgTimestamp = timestamp;
    _traceHealthStartTimestamp ??= timestamp;
    _traceSampleCount++;
    if (selectedOpticalSignal.isFinite) {
      _traceMinimumSelectedOptical =
          min(_traceMinimumSelectedOptical, selectedOpticalSignal);
      _traceMaximumSelectedOptical =
          max(_traceMaximumSelectedOptical, selectedOpticalSignal);
    } else {
      _traceNonFiniteSelectedOpticalCount++;
    }

    final spanTicks = timestamp - _traceHealthStartTimestamp!;
    if (spanTicks < _ticksPerSecond) return;
    _trace('stream_health', {
      'phase': _measurementEnabled ? 'measurement' : 'calibration',
      'timestamp_ticks': timestamp,
      'sample_count': _traceSampleCount,
      'observed_hz': spanTicks > 0
          ? ((_traceSampleCount - 1) * _ticksPerSecond / spanTicks)
          : null,
      'gap_count': _traceGapCount,
      'non_increasing_timestamp_count': _traceNonIncreasingCount,
      'maximum_gap_ms': _traceMaximumGapMs,
      'selected_channel': channel,
      'channel_changes': _traceChannelChanges,
      'selected_optical_min': _traceMinimumSelectedOptical.isFinite
          ? _traceMinimumSelectedOptical
          : null,
      'selected_optical_max': _traceMaximumSelectedOptical.isFinite
          ? _traceMaximumSelectedOptical
          : null,
      'non_finite_selected_optical_count': _traceNonFiniteSelectedOpticalCount,
    });
    _traceHealthStartTimestamp = timestamp;
    _traceSampleCount = 1;
    _traceGapCount = 0;
    _traceNonIncreasingCount = 0;
    _traceMaximumGapMs = 0;
    _traceChannelChanges = 0;
    _traceMinimumSelectedOptical = double.infinity;
    _traceMaximumSelectedOptical = double.negativeInfinity;
    _traceNonFiniteSelectedOpticalCount = 0;
  }

  void _evaluateVitals(int latestTimestamp) {
    final measurementSpanTicks =
        latestTimestamp - (_firstMeasurementTimestamp ?? latestTimestamp);
    final observedWindowTicks = _buffer.isEmpty
        ? 0.0
        : (_buffer.last.timestamp - _buffer.first.timestamp).toDouble();
    // Eligibility is elapsed measurement time, not the exact distance between
    // the first and last samples surviving a trailing window. With irregular
    // delivery a 30-second buffer commonly spans 29.9x seconds forever.
    if (_buffer.length < 20 || measurementSpanTicks < _minimumWindowTicks) {
      _trace('evaluation_skipped', {
        'reason': 'insufficient_window',
        'timestamp_ticks': latestTimestamp,
        'measurement_span_ms': measurementSpanTicks * _ticksToMilliseconds,
        'window_span_ms': observedWindowTicks * _ticksToMilliseconds,
        'buffer_samples': _buffer.length,
      });
      return;
    }

    final recentQuality =
        _estimateRecentWaveformQualityScore(latestTimestamp: latestTimestamp);
    var qualityScore = recentQuality.score;
    final recentMotion = recentQuality.averageMotion;

    // Production monitoring rejects heavy motion immediately. The conference
    // demo still evaluates the pulse waveform so its fixed deadline can retain
    // a low-confidence, beat-derived candidate instead of producing no value.
    if (recentMotion >= 1.45 && !publishBestEffortEstimates) {
      _trace('evaluation_skipped', {
        'reason': 'heavy_motion',
        'timestamp_ticks': latestTimestamp,
        'average_motion': recentMotion,
        'waveform_quality_score': qualityScore,
      });
      return;
    }

    final effectiveSampleFreqHz = _estimateEffectiveSampleFreqHz();
    final peakEstimate = _selectLivePeakEstimate(effectiveSampleFreqHz);
    if (!publishBestEffortEstimates || _deadlineEstimate != null) {
      _maybeCompareDetectors(
        _buffer,
        effectiveSampleFreqHz,
        context: 'monitoring',
      );
    }
    final peaks = peakEstimate.peakTimestamps;
    final peakHeartRate = peakEstimate.heartRateBpm;
    _lastCrediblePeakPairCount = peakEstimate.crediblePairCount;

    final peakScore = (peaks.length / 8.0).clamp(0.0, 1.0);
    qualityScore = ((0.78 * qualityScore) + (0.22 * peakScore)).clamp(0.0, 1.0);

    final ibiTicks = <double>[];
    final intervalSequence = <double?>[];
    for (var i = 1; i < peaks.length; i++) {
      final interval = (peaks[i] - peaks[i - 1]).toDouble();
      final intervalSeconds = interval / _ticksPerSecond;
      if (interval > 0 &&
          intervalSeconds >= _minBeatIntervalSec &&
          intervalSeconds <= _maxBeatIntervalSec) {
        ibiTicks.add(interval);
        intervalSequence.add(interval);
      } else {
        intervalSequence.add(null);
      }
    }
    if (ibiTicks.length >= 2) {
      final robustIbiTicks = _removeIbiOutliers(ibiTicks);
      final meanIbiTicks =
          robustIbiTicks.reduce((a, b) => a + b) / robustIbiTicks.length;
      if (meanIbiTicks.isFinite && meanIbiTicks > 0) {
        final ibiVariation = _standardDeviation(robustIbiTicks) / meanIbiTicks;
        if (ibiVariation.isFinite) {
          final rhythmScore = (1.0 - (ibiVariation / 0.55)).clamp(0.0, 1.0);
          qualityScore =
              ((0.78 * qualityScore) + (0.22 * rhythmScore)).clamp(0.0, 1.0);
        }
      }
    }

    final currentBestEffort = _considerBestEffortEstimate(
      heartRate: peakHeartRate,
      intervalSequence: intervalSequence,
      qualityScore: qualityScore,
    );

    final classifiedQuality = _classifyQuality(qualityScore);
    _tracePeakEvaluation(
      timestamp: latestTimestamp,
      qualityScore: qualityScore,
      averageMotion: recentMotion,
      qualityClass: classifiedQuality,
      estimatedSampleFreqHz: effectiveSampleFreqHz,
      peaks: peaks,
      validIntervals: ibiTicks,
      intervalSequence: intervalSequence,
      peakHeartRate: peakHeartRate,
      detectionMode: peakEstimate.mode.name,
      bestEffort: currentBestEffort,
    );
    if (classifiedQuality == _SignalQuality.bad ||
        classifiedQuality == _SignalQuality.unavailable) {
      if (publishBestEffortEstimates && currentBestEffort != null) {
        _lastRmssdSource = 'window_best_effort';
        _maybeEmit(
          currentBestEffort.heartRate.toDouble(),
          currentBestEffort.rmssd,
        );
      }
      return;
    }
    if (peakHeartRate == null) {
      return;
    }

    final smoothedHeartRate = _kalmanUpdateHeartRate(peakHeartRate);

    // Before the detector mode is selected, successive evaluations may use
    // different pulse polarities. None of those provisional beat times may
    // enter the long-lived RR history.
    if (_activePeakDetectionMode != null) {
      _updateRrHistory(peaks, latestTimestamp);
    }
    final rollingRmssdMs = _computeRollingRmssdMs(latestTimestamp);
    final rmssdMs = rollingRmssdMs ??
        (publishBestEffortEstimates ? currentBestEffort?.rmssd : null);
    _lastRmssdSource = rollingRmssdMs != null
        ? 'rolling_history'
        : rmssdMs != null
            ? 'window_best_effort'
            : 'unavailable';
    _trace('rolling_metric', {
      'timestamp_ticks': latestTimestamp,
      'smoothed_heart_rate_bpm': smoothedHeartRate,
      'rmssd_ms': rmssdMs,
      'rmssd_source': _lastRmssdSource,
      'rr_history_count': _rrHistory.length,
      'rr_history_span_ms': _rrHistory.length >= 2
          ? (_rrHistory.last.timestamp - _rrHistory.first.timestamp) *
              _ticksToMilliseconds
          : 0,
    });

    _maybeEmit(smoothedHeartRate, rmssdMs);
  }

  void _tracePeakEvaluation({
    required int timestamp,
    required double qualityScore,
    required double averageMotion,
    required _SignalQuality qualityClass,
    required double estimatedSampleFreqHz,
    required List<int> peaks,
    required List<double> validIntervals,
    required List<double?> intervalSequence,
    required double? peakHeartRate,
    required String detectionMode,
    required HeartRateSample? bestEffort,
  }) {
    if (diagnostics == null) return;
    final intervals = <Map<String, Object?>>[];
    for (var index = 1; index < peaks.length; index++) {
      final milliseconds =
          (peaks[index] - peaks[index - 1]) * _ticksToMilliseconds;
      intervals.add({
        'ending_peak_ticks': peaks[index],
        'interval_ms': milliseconds,
        'within_absolute_range': milliseconds >= 250 && milliseconds <= 2000,
      });
    }
    final filtered = _removeIbiOutliers(validIntervals);
    final rmssdEstimate = PulseIntervalRmssd.estimate(
      intervalSequence,
      allowSparse: true,
    );
    _trace('peak_evaluation', {
      'timestamp_ticks': timestamp,
      'window_span_ms': _buffer.length < 2
          ? 0.0
          : (_buffer.last.timestamp - _buffer.first.timestamp) *
              _ticksToMilliseconds,
      'effective_sample_hz': estimatedSampleFreqHz,
      'quality_score': qualityScore,
      'quality_class': qualityClass.name,
      'average_motion': averageMotion,
      'selected_channel': _channelSelector.selectedChannel,
      'peak_timestamps_ticks': peaks,
      'intervals': intervals,
      'range_accepted_intervals_ms':
          validIntervals.map((value) => value * _ticksToMilliseconds).toList(),
      'median_filtered_intervals_ms':
          filtered.map((value) => value * _ticksToMilliseconds).toList(),
      'rmssd_pair_count': rmssdEstimate.pairCount,
      'rmssd_method': rmssdEstimate.method,
      'peak_heart_rate_bpm': peakHeartRate,
      'peak_detection_mode': detectionMode,
      'best_effort_heart_rate_bpm': bestEffort?.heartRate,
      'best_effort_rmssd_ms': bestEffort?.rmssd,
    });
  }

  /// Folds newly-detected peaks (from the current 10s regular / 30s demo
  /// signal window) into
  /// the rolling RR-interval history, then prunes entries older than the
  /// 5-minute HRV window. `peaks` is a *full* re-detection over the last
  /// full signal window each call (not incremental), so only peaks newer than the
  /// last one already recorded are turned into intervals — this avoids
  /// double-counting the same beat across overlapping evaluation cycles
  /// while still correctly bridging the interval from the last recorded
  /// peak into the first newly-seen one.
  void _updateRrHistory(List<int> peaks, int latestTimestamp) {
    var previousPeak = _lastRecordedPeakTimestamp;
    final traceIntervals =
        diagnostics == null ? null : <Map<String, Object?>>[];
    for (final peak in peaks) {
      if (previousPeak != null && peak > previousPeak) {
        final intervalTicks = (peak - previousPeak).toDouble();
        final intervalSeconds = intervalTicks / _ticksPerSecond;
        final accepted = intervalSeconds >= _minBeatIntervalSec &&
            intervalSeconds <= _maxBeatIntervalSec;
        traceIntervals?.add({
          'previous_peak_ticks': previousPeak,
          'ending_peak_ticks': peak,
          'interval_ms': intervalTicks * _ticksToMilliseconds,
          'accepted': accepted,
          'reason':
              accepted ? 'within_absolute_range' : 'outside_absolute_range',
        });
        if (accepted) {
          _rrHistory.add(
            _TimestampedInterval(
              startingPeakTimestamp: previousPeak,
              timestamp: peak,
              intervalTicks: intervalTicks,
            ),
          );
        }
      }
      if (previousPeak == null || peak > previousPeak) {
        previousPeak = peak;
      }
    }
    _lastRecordedPeakTimestamp = previousPeak;

    _rrHistory.removeWhere(
      (entry) => entry.timestamp < latestTimestamp - _hrvWindowTicks,
    );
    if (traceIntervals != null) {
      _trace('rr_history_update', {
        'timestamp_ticks': latestTimestamp,
        'new_intervals': traceIntervals,
        'history_count': _rrHistory.length,
        'history_span_ms': _rrHistory.length >= 2
            ? (_rrHistory.last.timestamp - _rrHistory.first.timestamp) *
                _ticksToMilliseconds
            : 0,
      });
    }
  }

  /// RMSSD over the rolling RR-interval history: grows from a 1-minute
  /// minimum up to a 5-minute sliding window, recomputed every evaluation
  /// cycle alongside HR (matching Shaffer & Ginsberg 2017 short-term HRV
  /// recording lengths), rather than smoothed frame-to-frame.
  double? _computeRollingRmssdMs(int latestTimestamp) {
    if (_rrHistory.length < 2) {
      return null;
    }
    if (_hrvMinimumWindowTicks >= _hrvWindowTicks) {
      // In the demo the minimum and maximum are both 30 seconds. Interval
      // endpoints cannot span that entire window after old entries are
      // pruned. Require 30 seconds of measurement plus RR coverage reaching
      // back to within one physiologically valid beat of the window start.
      final measurementStart = _firstMeasurementTimestamp;
      final minimumCoverageTicks =
          _hrvMinimumWindowTicks - (_maxBeatIntervalSec * _ticksPerSecond);
      if (measurementStart == null ||
          latestTimestamp - measurementStart < _hrvMinimumWindowTicks ||
          latestTimestamp - _rrHistory.first.startingPeakTimestamp <
              minimumCoverageTicks) {
        return null;
      }
    } else {
      // Keep the production mode's full history-span requirement unchanged.
      final historySpanTicks =
          (_rrHistory.last.timestamp - _rrHistory.first.timestamp).toDouble();
      if (historySpanTicks < _hrvMinimumWindowTicks) return null;
    }

    final intervalSequence = <double?>[];
    for (var i = 0; i < _rrHistory.length; i++) {
      if (i > 0 &&
          _rrHistory[i].startingPeakTimestamp != _rrHistory[i - 1].timestamp) {
        intervalSequence.add(null);
      }
      intervalSequence.add(_rrHistory[i].intervalTicks);
    }
    final estimate = PulseIntervalRmssd.estimate(
      intervalSequence,
      allowSparse: true,
    );
    _trace('rolling_rmssd_quality', {
      'timestamp_ticks': latestTimestamp,
      'pair_count': estimate.pairCount,
      'method': estimate.method,
      'last_interval_age_ms':
          (latestTimestamp - _rrHistory.last.timestamp) * _ticksToMilliseconds,
    });
    final rmssdTicks = estimate.ticks;
    if (rmssdTicks == null || !rmssdTicks.isFinite || rmssdTicks <= 0) {
      return null;
    }

    final hrvMs = rmssdTicks * _ticksToMilliseconds;
    if (!hrvMs.isFinite || hrvMs < 5 || hrvMs > 300) {
      return null;
    }
    return hrvMs;
  }

  HeartRateSample? _estimateRetainedBaseline() {
    if (_deadlineEvidence.length < 8) return null;

    final splitIndex = _baselineEvidenceStartIndex.clamp(
      0,
      _deadlineEvidence.length,
    );
    final baselineSamples = _deadlineEvidence.sublist(splitIndex);
    final baselineEstimate = _estimateRetainedSamples(
      baselineSamples,
      sourceLabel: 'baseline',
    );
    if (baselineEstimate != null) return baselineEstimate;

    // The complete 30-second baseline is always the primary source. Only if
    // that separate window contains no usable beat sequence do we evaluate
    // the preceding 30-second calibration window as the deadline rescue.
    final calibrationSamples = _deadlineEvidence.sublist(0, splitIndex);
    if (calibrationSamples.isEmpty) return null;
    final calibrationEnd = calibrationSamples.last.timestamp;
    final calibrationWindowStart = calibrationEnd - _windowDurationTicks;
    final rescueSamples = calibrationSamples
        .where((sample) => sample.timestamp >= calibrationWindowStart)
        .toList(growable: false);
    return _estimateRetainedSamples(
      rescueSamples,
      sourceLabel: 'calibration_rescue',
    );
  }

  HeartRateSample? _estimateRetainedSamples(
    List<_ConditionedSample> samples, {
    required String sourceLabel,
  }) {
    if (samples.length < 8) {
      _trace('retained_window', {
        'source': sourceLabel,
        'sample_count': samples.length,
        'result': 'too_few_samples',
      });
      return null;
    }

    final effectiveSampleFreq = _estimateEffectiveSampleFreqHz(samples);
    // The deadline uses the same peak detector and quality ranking as live
    // monitoring. It may choose a mode on the complete baseline window, then
    // retains that mode for monitoring so the RR history never joins peaks
    // from different polarities or sensitivities.
    final peakEstimate = _bestPeakEstimate(
      samples,
      effectiveSampleFreq,
      comparisonContext: sourceLabel == 'baseline'
          ? 'baseline_deadline'
          : 'calibration_rescue',
    );

    final ibiTicks = <double>[];
    final intervalSequence = <double?>[];
    final peaks = peakEstimate.peakTimestamps;
    for (var i = 1; i < peaks.length; i++) {
      final interval = (peaks[i] - peaks[i - 1]).toDouble();
      final intervalSeconds = interval / _ticksPerSecond;
      if (intervalSeconds >= _minBeatIntervalSec &&
          intervalSeconds <= _maxBeatIntervalSec) {
        ibiTicks.add(interval);
        intervalSequence.add(interval);
      } else {
        intervalSequence.add(null);
      }
    }
    _trace('retained_window', {
      'source': sourceLabel,
      'sample_count': samples.length,
      'span_ms': (samples.last.timestamp - samples.first.timestamp) *
          _ticksToMilliseconds,
      'effective_sample_hz': effectiveSampleFreq,
      'peak_detection_mode': peakEstimate.mode.name,
      'credible_pair_count': peakEstimate.crediblePairCount,
      'accepted_interval_count': peakEstimate.acceptedIntervalCount,
      'peak_timestamps_ticks': peaks,
      'range_accepted_intervals_ms':
          ibiTicks.map((value) => value * _ticksToMilliseconds).toList(),
    });
    if (ibiTicks.length < 2) return null;

    final robustIntervals = _removeIbiOutliers(ibiTicks);
    if (robustIntervals.length < 2) return null;
    final sortedIntervals = List<double>.of(robustIntervals)..sort();
    final medianInterval = sortedIntervals[sortedIntervals.length ~/ 2];
    if (!medianInterval.isFinite || medianInterval <= 0) return null;

    final heartRate = 60.0 * _ticksPerSecond / medianInterval;
    final rmssdEstimate =
        PulseIntervalRmssd.estimate(intervalSequence, allowSparse: true);
    final rmssdTicks = rmssdEstimate.ticks;
    if (!heartRate.isFinite ||
        heartRate < 30 ||
        heartRate > 240 ||
        rmssdTicks == null ||
        !rmssdTicks.isFinite) {
      return null;
    }
    final rawRmssdMs = rmssdTicks * _ticksToMilliseconds;
    // A baseline is the reference every later stress decision is measured
    // against, so an implausible one is worse than none: it re-arms the
    // detector at a threshold real physiology clears immediately. Observed in
    // the field as hr=31 with rmssd saturated at the 300 ms ceiling, which
    // armed a 3% demo threshold at 32 bpm and fired stress within seconds.
    if (rawRmssdMs >= 300.0 ||
        heartRate < _minimumPlausibleBaselineBpm ||
        heartRate > _maximumPlausibleBaselineBpm) {
      _trace('retained_rejected', {
        'source': sourceLabel,
        'heart_rate_bpm': heartRate,
        'raw_rmssd_ms': rawRmssdMs,
        'reason': rawRmssdMs >= 300.0 ? 'rmssd_saturated' : 'heart_rate_range',
      });
      return null;
    }
    final rmssdMs = rawRmssdMs.clamp(0.0, 300.0);
    _trace('retained_result', {
      'source': sourceLabel,
      'heart_rate_bpm': heartRate,
      'raw_rmssd_ms': rmssdTicks * _ticksToMilliseconds,
      'reported_rmssd_ms': rmssdMs,
      'rmssd_pair_count': rmssdEstimate.pairCount,
      'rmssd_method': rmssdEstimate.method,
      'peak_detection_mode': peakEstimate.mode.name,
      'median_filtered_intervals_ms':
          robustIntervals.map((value) => value * _ticksToMilliseconds).toList(),
    });
    _activatePeakDetectionMode(peakEstimate.mode);
    return HeartRateSample(
      heartRate: heartRate.round(),
      rmssd: rmssdMs,
    );
  }

  HeartRateSample? _considerBestEffortEstimate({
    required double? heartRate,
    required List<double?> intervalSequence,
    required double qualityScore,
  }) {
    if (heartRate == null || !qualityScore.isFinite) {
      return null;
    }

    final rmssdTicks = PulseIntervalRmssd.estimate(
      intervalSequence,
      allowSparse: true,
    ).ticks;
    if (rmssdTicks == null || !rmssdTicks.isFinite || rmssdTicks < 0) {
      return null;
    }

    final rmssdMs = rmssdTicks * _ticksToMilliseconds;
    if (!rmssdMs.isFinite || rmssdMs < 0 || rmssdMs > 300) return null;

    final candidate = HeartRateSample(
      heartRate: heartRate.round(),
      rmssd: rmssdMs,
    );

    if (_bestEffortEstimate == null || qualityScore >= _bestEffortQuality) {
      _bestEffortQuality = qualityScore;
      _bestEffortEstimate = candidate;
    }
    return candidate;
  }

  void _maybeEmit(double heartRate, double? rmssd) {
    final firstSampleTime = _firstSampleTime;
    if (firstSampleTime == null ||
        _now().difference(firstSampleTime) < _warmupDuration) {
      return;
    }

    final now = _now();
    if (_lastEmitTime != null &&
        now.difference(_lastEmitTime!) < _emitInterval) {
      return;
    }
    _lastEmitTime = now;

    _emit(HeartRateSample(heartRate: heartRate.round(), rmssd: rmssd));
    HrHrvDiagnosticSettings.logSummary(
      'Meditation metrics: HR=${heartRate.round()} BPM, '
      'RMSSD=${rmssd?.toStringAsFixed(1) ?? "n/a"} ms, '
      'source=$_lastRmssdSource, '
      'clean_pairs=$_lastCrediblePeakPairCount, '
      'detector=${_activePeakDetectionMode?.name ?? "unselected"}',
    );
  }

  void _clearEstimatorState() {
    _firstSampleTime = null;
    _firstMeasurementTimestamp = null;
    _lastEmitTime = null;
    _lastEvaluationTick = double.negativeInfinity;
    _lastDetectorComparisonTick = double.negativeInfinity;
    _buffer.clear();
    // RR history can outlive `_buffer` (5-minute history vs 10s regular
    // signal window), so it must be
    // cleared explicitly — otherwise a new measurement window inherits the
    // previous one's intervals, immediately satisfies the minimum-span gate,
    // and reports RMSSD computed from earlier beats.
    _rrHistory.clear();
    _lastRecordedPeakTimestamp = null;
    _latestSample = null;
    _bestEffortEstimate = null;
    _bestEffortQuality = double.negativeInfinity;
    _hrEstimate = 75.0;
    _hrCovariance = 1.0;
    _hasMeasuredHeartRate = false;
    _activePeakDetectionMode = null;
    _poorPeakWindowCount = 0;
    _lastCrediblePeakPairCount = 0;
    _lastRmssdSource = 'unavailable';
  }

  ({double score, double averageMotion}) _estimateRecentWaveformQualityScore({
    required int latestTimestamp,
    List<_ConditionedSample>? source,
  }) {
    final qualityWindowTicks = 3.0 * _ticksPerSecond;
    final recent = (source ?? _buffer)
        .where(
          (sample) => sample.timestamp >= latestTimestamp - qualityWindowTicks,
        )
        .toList(growable: false);
    final minimumSamples = max(8, (sampleFreq * 1.2).round());
    if (recent.length < minimumSamples) {
      return (score: 0.0, averageMotion: 0.0);
    }

    final filteredValues =
        recent.map((sample) => sample.signal).toList(growable: false);
    final meanFilteredAbs =
        filteredValues.map((value) => value.abs()).reduce((a, b) => a + b) /
            filteredValues.length;
    if (!meanFilteredAbs.isFinite || meanFilteredAbs <= 1e-6) {
      return (score: 0.0, averageMotion: 0.0);
    }

    final minFiltered = filteredValues.reduce(min);
    final maxFiltered = filteredValues.reduce(max);
    final rangeFiltered = maxFiltered - minFiltered;
    final stdFiltered = _standardDeviation(filteredValues);

    final averageMotion =
        recent.map((sample) => sample.motionLevel).reduce((a, b) => a + b) /
            recent.length;
    final rangeScore = ((rangeFiltered - 0.08) / 0.95).clamp(0.0, 1.0);
    final stdScore = ((stdFiltered - 0.025) / 0.30).clamp(0.0, 1.0);
    final motionScore = (1.0 - (averageMotion / 2.2)).clamp(0.0, 1.0);

    var score = ((0.45 * rangeScore) + (0.35 * stdScore) + (0.20 * motionScore))
        .clamp(0.0, 1.0);

    if (averageMotion >= 1.45) {
      score = min(score, 0.10);
    } else if (averageMotion >= 1.12) {
      score = min(score, 0.24);
    } else if (averageMotion >= 0.88) {
      score = min(score, 0.45);
    }

    return (score: score, averageMotion: averageMotion);
  }

  _SignalQuality _classifyQuality(double score) {
    if (!score.isFinite || score <= 0) {
      return _SignalQuality.unavailable;
    }
    if (score < 0.30) {
      return _SignalQuality.bad;
    }
    if (score < 0.62) {
      return _SignalQuality.fair;
    }
    return _SignalQuality.good;
  }

  double _estimateEffectiveSampleFreqHz([
    List<_ConditionedSample>? source,
  ]) {
    final samples = source ?? _buffer;
    if (samples.length < 2) {
      return sampleFreq;
    }
    final durationTicks =
        (samples.last.timestamp - samples.first.timestamp).toDouble();
    if (durationTicks <= 0) {
      return sampleFreq;
    }
    final estimated = ((samples.length - 1) * _ticksPerSecond) / durationTicks;
    if (!estimated.isFinite || estimated < 5 || estimated > 200) {
      return sampleFreq;
    }
    return estimated;
  }

  _PeakCandidate _selectLivePeakEstimate(double effectiveSampleFreqHz) {
    final activeMode = _activePeakDetectionMode;
    if (activeMode != null) {
      final active = _peakCandidate(
        _buffer,
        effectiveSampleFreqHz,
        activeMode,
      );
      if (active.crediblePairCount >= 2) {
        _poorPeakWindowCount = 0;
        return active;
      }
      _poorPeakWindowCount++;
      if (_poorPeakWindowCount < 5 || _poorPeakWindowCount % 5 != 0) {
        return active;
      }

      // A sustained loss of usable beats can follow a change in earbud fit or
      // optical channel. Re-select only if another detector is clearly better;
      // changing peak polarity without clearing RR history fabricates beats.
      final replacement = _bestPeakEstimate(_buffer, effectiveSampleFreqHz);
      if (replacement.mode != activeMode &&
          replacement.crediblePairCount >= 4 &&
          replacement.crediblePairCount >= active.crediblePairCount + 3) {
        _activatePeakDetectionMode(replacement.mode);
        return replacement;
      }
      return active;
    }

    final best = _bestPeakEstimate(_buffer, effectiveSampleFreqHz);
    final measurementStart = _firstMeasurementTimestamp;
    final windowReady = measurementStart != null &&
        _buffer.last.timestamp - measurementStart >=
            min(_windowDurationTicks, 10.0 * _ticksPerSecond);
    if (windowReady && best.crediblePairCount >= 2) {
      _activatePeakDetectionMode(best.mode);
    }
    return best;
  }

  void _activatePeakDetectionMode(_PeakDetectionMode mode) {
    final previous = _activePeakDetectionMode;
    if (previous == mode) return;
    if (previous != null) {
      _rrHistory.clear();
      _lastRecordedPeakTimestamp = null;
    }
    _activePeakDetectionMode = mode;
    _poorPeakWindowCount = 0;
    _trace('peak_detector_selected', {
      'mode': mode.name,
      'previous_mode': previous?.name,
    });
  }

  _PeakCandidate _bestPeakEstimate(
    List<_ConditionedSample> samples,
    double effectiveSampleFreqHz, {
    String? comparisonContext,
  }) {
    const selectable = _PeakDetectionMode.values;
    final active = _activePeakDetectionMode;
    final modes = <_PeakDetectionMode>[
      if (active != null && selectable.contains(active)) active,
      ...selectable.where((mode) => mode != active),
    ];
    var best = _peakCandidate(samples, effectiveSampleFreqHz, modes.first);
    for (final mode in modes.skip(1)) {
      final candidate = _peakCandidate(samples, effectiveSampleFreqHz, mode);
      if (candidate.isBetterThan(best)) best = candidate;
    }
    if (comparisonContext != null &&
        _detectorComparisonDue(samples.last.timestamp)) {
      _reportDetectorComparison(
        samples,
        effectiveSampleFreqHz,
        best,
        context: comparisonContext,
      );
    }
    return best;
  }

  bool _detectorComparisonDue(int latestTimestamp) =>
      (HrHrvDiagnosticSettings.detectorComparisonEnabled ||
          HrHrvDiagnosticSettings.beatQualityEnabled ||
          diagnostics != null) &&
      latestTimestamp - _lastDetectorComparisonTick >= 30 * _ticksPerSecond;

  void _maybeCompareDetectors(
    List<_ConditionedSample> samples,
    double effectiveSampleFreqHz, {
    required String context,
  }) {
    final measurementStart = _firstMeasurementTimestamp;
    if (samples.isEmpty ||
        measurementStart == null ||
        samples.last.timestamp - measurementStart < 30 * _ticksPerSecond ||
        !_detectorComparisonDue(samples.last.timestamp)) {
      return;
    }
    // Shadow evaluation only: its result never changes the selected mode,
    // rolling beat history, published metrics, or meditation state.
    _bestPeakEstimate(
      samples,
      effectiveSampleFreqHz,
      comparisonContext: context,
    );
  }

  void _reportDetectorComparison(
    List<_ConditionedSample> samples,
    double effectiveSampleFreqHz,
    _PeakCandidate best, {
    required String context,
  }) {
    final latestTimestamp = samples.last.timestamp;
    _lastDetectorComparisonTick = latestTimestamp.toDouble();
    final spanMs =
        (latestTimestamp - samples.first.timestamp) * _ticksToMilliseconds;
    // Every candidate is evaluated here — both detector families and both
    // signal paths — so a single traced run compares all of them on identical
    // windows, whichever combination is currently driving the metrics.
    final ordered = [
      for (final beatPath in const [false, true])
        for (final mode in _PeakDetectionMode.values)
          _peakCandidate(
            samples,
            effectiveSampleFreqHz,
            mode,
            beatPath: beatPath,
          ),
    ];
    if (diagnostics != null) {
      _trace(
        'detector_comparison',
        {
          'context': context,
          'timestamp_ticks': latestTimestamp,
          'window_span_ms': spanMs,
          'sample_count': samples.length,
          'active_mode': _activePeakDetectionMode?.name,
          'ranked_best_mode': best.mode.name,
          'candidates': ordered
              .map(
                (candidate) => {
                  'mode': candidate.mode.name,
                  'signal_path': candidate.signalPath,
                  'peak_count': candidate.peakTimestamps.length,
                  'heart_rate_bpm': candidate.heartRateBpm,
                  'rmssd_ms': candidate.rmssdTicks == null
                      ? null
                      : candidate.rmssdTicks! * _ticksToMilliseconds,
                  'rmssd_method': candidate.rmssdMethod,
                  'clean_pair_count': candidate.crediblePairCount,
                  'accepted_interval_count': candidate.acceptedIntervalCount,
                  'rejected_interval_count': candidate.rejectedIntervalCount,
                  'last_peak_age_ms': candidate.peakTimestamps.isEmpty
                      ? null
                      : (latestTimestamp - candidate.peakTimestamps.last) *
                          _ticksToMilliseconds,
                },
              )
              .toList(),
        },
      );
    }
    HrHrvDiagnosticSettings.logDetectorComparison(
      'Meditation detector comparison: $context, '
      'window=${spanMs.toStringAsFixed(0)} ms, '
      'active=${_activePeakDetectionMode?.name ?? "unselected"}, '
      'best=${best.mode.name}',
    );
    for (final candidate in ordered) {
      final rmssdMs = candidate.rmssdTicks == null
          ? 'n/a'
          : (candidate.rmssdTicks! * _ticksToMilliseconds).toStringAsFixed(1);
      HrHrvDiagnosticSettings.logDetectorComparison(
        '  ${candidate.mode.name}: '
        'peaks=${candidate.peakTimestamps.length}, '
        'clean_pairs=${candidate.crediblePairCount}, '
        'accepted=${candidate.acceptedIntervalCount}, '
        'rejected=${candidate.rejectedIntervalCount}, '
        'HR=${candidate.heartRateBpm?.toStringAsFixed(1) ?? "n/a"} BPM, '
        'RMSSD=$rmssdMs ms (${candidate.rmssdMethod})',
      );
    }
    _reportBeatQualitySnapshot(samples, best, ordered, context: context);
  }

  void _reportBeatQualitySnapshot(
    List<_ConditionedSample> samples,
    _PeakCandidate best,
    List<_PeakCandidate> candidates, {
    required String context,
  }) {
    if (!HrHrvDiagnosticSettings.beatQualityEnabled && diagnostics == null) {
      return;
    }
    final activeMode = _activePeakDetectionMode;
    // Candidates now cover both signal paths, so match the live path too —
    // otherwise this snapshot could describe the path that is not in use.
    final livePath = BioAdaptiveModeConfig.useLightlyFilteredBeatPath
        ? 'beat'
        : 'conditioned';
    final selected = activeMode == null
        ? best
        : candidates.firstWhere(
            (candidate) =>
                candidate.mode == activeMode &&
                candidate.signalPath == livePath,
            orElse: () => best,
          );
    final latestTimestamp = samples.last.timestamp;
    final windowSpanMs =
        (latestTimestamp - samples.first.timestamp) * _ticksToMilliseconds;
    final recentQuality = _estimateRecentWaveformQualityScore(
      latestTimestamp: latestTimestamp,
      source: samples,
    );
    final intervalsMs = <int>[];
    final rejectedPositions = <int>[];
    for (var index = 1; index < selected.peakTimestamps.length; index++) {
      final intervalTicks =
          selected.peakTimestamps[index] - selected.peakTimestamps[index - 1];
      intervalsMs.add((intervalTicks * _ticksToMilliseconds).round());
      final intervalSeconds = intervalTicks / _ticksPerSecond;
      if (intervalSeconds < _minBeatIntervalSec ||
          intervalSeconds > _maxBeatIntervalSec) {
        rejectedPositions.add(index - 1);
      }
    }
    final lastPeakAgeMs = selected.peakTimestamps.isEmpty
        ? null
        : (latestTimestamp - selected.peakTimestamps.last) *
            _ticksToMilliseconds;
    final effectiveSampleHz = _estimateEffectiveSampleFreqHz(samples);
    if (diagnostics != null) {
      _trace('beat_quality_snapshot', {
        'context': context,
        'timestamp_ticks': latestTimestamp,
        'mode': selected.mode.name,
        'window_span_ms': windowSpanMs,
        'sample_count': samples.length,
        'effective_sample_hz': effectiveSampleHz,
        'current_optical_channel': _channelSelector.selectedChannel,
        'waveform_quality_last_3s': recentQuality.score,
        'motion_last_3s': recentQuality.averageMotion,
        'peak_count': selected.peakTimestamps.length,
        'clean_pair_count': selected.crediblePairCount,
        'last_peak_age_ms': lastPeakAgeMs,
        'intervals_ms': intervalsMs,
        'rejected_interval_positions': rejectedPositions,
      });
    }
    HrHrvDiagnosticSettings.logBeatQuality(
      'Meditation beat quality: $context, '
      'mode=${selected.mode.name}, '
      'window_ms=${windowSpanMs.toStringAsFixed(0)}, '
      'samples=${samples.length}, '
      'effective_hz=${effectiveSampleHz.toStringAsFixed(1)}, '
      'channel=${_channelSelector.selectedChannel}, '
      'quality_3s=${recentQuality.score.toStringAsFixed(2)}, '
      'motion_3s=${recentQuality.averageMotion.toStringAsFixed(2)}, '
      'peaks=${selected.peakTimestamps.length}, '
      'clean_pairs=${selected.crediblePairCount}, '
      'last_peak_age_ms=${lastPeakAgeMs?.toStringAsFixed(0) ?? "n/a"}',
    );
    final rejected = rejectedPositions.toSet();
    HrHrvDiagnosticSettings.logBeatQuality(
      'Meditation beat intervals (ms; ! = outside 250-2000): '
      '${[
        for (var index = 0; index < intervalsMs.length; index++)
          '${intervalsMs[index]}${rejected.contains(index) ? "!" : ""}',
      ].join(" ")}',
    );
  }

  _PeakCandidate _peakCandidate(
    List<_ConditionedSample> samples,
    double effectiveSampleFreqHz,
    _PeakDetectionMode mode, {
    bool? beatPath,
  }) {
    final useBeatPath =
        beatPath ?? BioAdaptiveModeConfig.useLightlyFilteredBeatPath;
    final estimate = _estimateHeartRateByPeak(
      estimatedSampleFreqHz: effectiveSampleFreqHz,
      source: samples,
      amplitudeScale: mode.sensitive ? 0.12 : 0.35,
      minimumAmplitude: mode.sensitive ? 0.002 : 0.04,
      minimumSignalStd: mode.sensitive ? 1e-8 : 1e-4,
      signalPolarity: mode.polarity,
      refractoryScale: mode.sensitive ? 1.0 : 0.85,
      beatPath: useBeatPath,
    );
    final peaks = estimate.peakTimestamps;
    final intervals = <double?>[];
    var acceptedCount = 0;
    for (var i = 1; i < peaks.length; i++) {
      final interval = (peaks[i] - peaks[i - 1]).toDouble();
      final seconds = interval / _ticksPerSecond;
      if (seconds >= _minBeatIntervalSec && seconds <= _maxBeatIntervalSec) {
        intervals.add(interval);
        acceptedCount++;
      } else {
        intervals.add(null);
      }
    }
    final rmssd = PulseIntervalRmssd.estimate(intervals);
    return _PeakCandidate(
      mode: mode,
      signalPath: useBeatPath ? 'beat' : 'conditioned',
      heartRateBpm: estimate.heartRateBpm,
      peakTimestamps: peaks,
      crediblePairCount:
          rmssd.method == 'adjacent_median_filtered' ? rmssd.pairCount : 0,
      rmssdTicks: rmssd.ticks,
      rmssdMethod: rmssd.method,
      acceptedIntervalCount: acceptedCount,
      rejectedIntervalCount: intervals.length - acceptedCount,
    );
  }

  ({double? heartRateBpm, List<int> peakTimestamps}) _estimateHeartRateByPeak({
    required double estimatedSampleFreqHz,
    List<_ConditionedSample>? source,
    double amplitudeScale = 0.35,
    double minimumAmplitude = 0.04,
    double minimumSignalStd = 1e-4,
    double signalPolarity = 1.0,
    double refractoryScale = 0.85,
    bool beatPath = false,
  }) {
    final samples = source ?? _buffer;
    if (samples.length < 8) {
      return (heartRateBpm: null, peakTimestamps: const []);
    }

    final signal = samples
        .map((sample) => sample.valueFor(beatPath: beatPath))
        .toList(growable: false);
    final mean = signal.reduce((a, b) => a + b) / signal.length;
    final centered = signal
        .map((value) => (value - mean) * signalPolarity)
        .toList(growable: false);

    final signalStd = _standardDeviation(centered);
    if (!signalStd.isFinite || signalStd < minimumSignalStd) {
      return (heartRateBpm: null, peakTimestamps: const []);
    }

    final safeSampleFreq =
        estimatedSampleFreqHz.isFinite && estimatedSampleFreqHz > 0
            ? estimatedSampleFreqHz
            : sampleFreq;
    // The lightly filtered path preserves the dicrotic notch that the
    // smoothing stages used to blur away, so it needs a wider refractory to
    // avoid counting it as a beat.
    final minimumBeatInterval = beatPath
        ? BioAdaptiveModeConfig.beatPathMinimumBeatIntervalSeconds
        : _minBeatIntervalSec * refractoryScale;
    final minPeakDistanceSamples = max(
      1,
      (safeSampleFreq * minimumBeatInterval).round(),
    );
    final amplitudeThreshold =
        max(minimumAmplitude, signalStd * amplitudeScale);

    final peakIndices = <int>[];
    for (var i = 1; i < centered.length - 1; i++) {
      final current = centered[i];
      if (!current.isFinite || current < amplitudeThreshold) {
        continue;
      }
      final isLocalMaximum =
          current >= centered[i - 1] && current > centered[i + 1];
      if (!isLocalMaximum) {
        continue;
      }

      if (peakIndices.isNotEmpty &&
          (i - peakIndices.last) < minPeakDistanceSamples) {
        if (current > centered[peakIndices.last]) {
          peakIndices[peakIndices.length - 1] = i;
        }
        continue;
      }
      peakIndices.add(i);
    }

    final peaks = peakIndices
        .map((index) => samples[index].timestamp)
        .toList(growable: false);

    return _estimateHeartRateFromPeakTimestamps(peaks);
  }

  ({double? heartRateBpm, List<int> peakTimestamps})
      _estimateHeartRateFromPeakTimestamps(List<int> peaks) {
    if (peaks.length < 2) {
      return (heartRateBpm: null, peakTimestamps: peaks);
    }

    final intervalsSeconds = <double>[];
    for (var i = 1; i < peaks.length; i++) {
      final intervalSeconds =
          (peaks[i] - peaks[i - 1]).toDouble() / _ticksPerSecond;
      if (intervalSeconds >= _minBeatIntervalSec &&
          intervalSeconds <= _maxBeatIntervalSec) {
        intervalsSeconds.add(intervalSeconds);
      }
    }
    // A single peak-to-peak interval is not enough to establish a pulse
    // rhythm, even though it can be converted into a numerical BPM.
    if (intervalsSeconds.length < 2) {
      return (heartRateBpm: null, peakTimestamps: peaks);
    }

    intervalsSeconds.sort();
    final medianIntervalSeconds =
        intervalsSeconds[intervalsSeconds.length ~/ 2];
    final heartRate = 60.0 / medianIntervalSeconds;
    if (!heartRate.isFinite || heartRate < 30 || heartRate > 240) {
      return (heartRateBpm: null, peakTimestamps: peaks);
    }

    return (heartRateBpm: heartRate, peakTimestamps: peaks);
  }

  List<double> _removeIbiOutliers(List<double> ibiTicks) {
    if (ibiTicks.length < 3) {
      return ibiTicks;
    }

    final sorted = [...ibiTicks]..sort();
    final median = sorted[sorted.length ~/ 2];
    final low = median * 0.65;
    final high = median * 1.35;
    final filtered = ibiTicks
        .where((ibi) => ibi >= low && ibi <= high)
        .toList(growable: false);
    return filtered.length >= 2 ? filtered : ibiTicks;
  }

  double _standardDeviation(List<double> values) {
    if (values.length < 2) {
      return 0;
    }
    final mean = values.reduce((a, b) => a + b) / values.length;
    var variance = 0.0;
    for (final value in values) {
      final diff = value - mean;
      variance += diff * diff;
    }
    variance /= values.length;
    return sqrt(variance);
  }

  double _kalmanUpdateHeartRate(double measurement) {
    if (!measurement.isFinite) {
      return _hrEstimate;
    }

    if (!_hasMeasuredHeartRate) {
      _hasMeasuredHeartRate = true;
      _hrEstimate = measurement;
      return measurement;
    }

    _hrCovariance += _hrProcessNoise;
    final gain = _hrCovariance / (_hrCovariance + _hrMeasurementNoise);
    _hrEstimate += gain * (measurement - _hrEstimate);
    _hrCovariance *= (1 - gain);
    return _hrEstimate;
  }
}

enum _SignalQuality { unavailable, bad, fair, good }

enum _PeakDetectionMode {
  standardPositive(1.0, false),
  standardNegative(-1.0, false),
  sensitivePositive(1.0, true),
  sensitiveNegative(-1.0, true);

  const _PeakDetectionMode(this.polarity, this.sensitive);

  final double polarity;
  final bool sensitive;
}

class _PeakCandidate {
  final _PeakDetectionMode mode;

  /// Which signal the beats were taken from: 'conditioned' or 'beat'.
  final String signalPath;

  final double? heartRateBpm;
  final List<int> peakTimestamps;
  final int crediblePairCount;
  final double? rmssdTicks;
  final String rmssdMethod;
  final int acceptedIntervalCount;
  final int rejectedIntervalCount;

  const _PeakCandidate({
    required this.mode,
    required this.signalPath,
    required this.heartRateBpm,
    required this.peakTimestamps,
    required this.crediblePairCount,
    required this.rmssdTicks,
    required this.rmssdMethod,
    required this.acceptedIntervalCount,
    required this.rejectedIntervalCount,
  });

  // Prefer clean consecutive beat pairs over raw peak count. On a tie,
  // prefer the candidate with fewer physiologically impossible gaps, then
  // more measured intervals. The caller's ordering preserves an active mode
  // (or the stricter detector) when all evidence is equal.
  bool isBetterThan(_PeakCandidate other) {
    if (heartRateBpm == null) return false;
    if (other.heartRateBpm == null) return true;
    if (crediblePairCount != other.crediblePairCount) {
      return crediblePairCount > other.crediblePairCount;
    }
    final total = acceptedIntervalCount + rejectedIntervalCount;
    final otherTotal =
        other.acceptedIntervalCount + other.rejectedIntervalCount;
    final acceptanceComparison = (acceptedIntervalCount * otherTotal) -
        (other.acceptedIntervalCount * total);
    if (acceptanceComparison != 0) return acceptanceComparison > 0;
    return acceptedIntervalCount > other.acceptedIntervalCount;
  }
}

class _TimestampedInterval {
  final int startingPeakTimestamp;
  final int timestamp;
  final double intervalTicks;

  const _TimestampedInterval({
    required this.startingPeakTimestamp,
    required this.timestamp,
    required this.intervalTicks,
  });
}

class _ConditionedSample {
  final int timestamp;

  /// The fully conditioned waveform: motion-suppressed, IMU-cancelled and
  /// amplitude-normalized. Used for quality scoring, which is calibrated
  /// against its bounded range.
  final double signal;

  /// The same optical channel with only a DC block and band-pass applied.
  /// Retains the sharp systolic edge that the smoothing stages round off, so
  /// beat *timing* taken from it is markedly more precise.
  final double beatSignal;

  final double motionLevel;

  const _ConditionedSample({
    required this.timestamp,
    required this.signal,
    required this.beatSignal,
    required this.motionLevel,
  });

  double valueFor({required bool beatPath}) => beatPath ? beatSignal : signal;
}

class _HighPassFilter {
  final double cutoffFreq;
  final double sampleFreq;

  late final double alpha;
  double? _lastInput;
  double? _lastOutput;

  _HighPassFilter({
    required this.cutoffFreq,
    required this.sampleFreq,
  }) {
    final dt = 1.0 / sampleFreq;
    final rc = 1.0 / (2 * pi * cutoffFreq);
    alpha = rc / (rc + dt);
  }

  /// Drops accumulated state so the next sample starts a fresh response
  /// instead of being treated as a step away from the previous channel.
  void reset() {
    _lastInput = null;
    _lastOutput = null;
  }

  double filter(double x) {
    if (_lastInput == null) {
      _lastInput = x;
      _lastOutput = 0.0;
      return 0.0;
    }

    final y = alpha * ((_lastOutput ?? 0.0) + x - (_lastInput ?? 0.0));
    _lastInput = x;
    _lastOutput = y;
    return y;
  }
}

class _BandPassFilter {
  final double sampleFreq;
  final double lowCut;
  final double highCut;

  late final double a0, a1, a2, b1, b2;
  double x1 = 0, x2 = 0;
  double y1 = 0, y2 = 0;
  bool _isFirstSample = true;

  _BandPassFilter({
    required this.sampleFreq,
    required this.lowCut,
    required this.highCut,
  }) {
    final centerFreq = sqrt(lowCut * highCut);
    final bandwidth = highCut - lowCut;
    final q = centerFreq / bandwidth;

    final omega = 2 * pi * centerFreq / sampleFreq;
    final alpha = sin(omega) / (2 * q);

    final cosOmega = cos(omega);
    final norm = 1 + alpha;

    a0 = alpha / norm;
    a1 = 0;
    a2 = -alpha / norm;
    b1 = -2 * cosOmega / norm;
    b2 = (1 - alpha) / norm;
  }

  /// Returns to the pre-warm state so the next sample seeds the filter afresh
  /// rather than ringing through a step from a different optical channel.
  void reset() {
    x1 = x2 = y1 = y2 = 0;
    _isFirstSample = true;
  }

  double filter(double x) {
    // Pre-warm filter state on the first sample to avoid a step-function
    // transient: a band-pass filter has zero DC gain, so y1=y2=0 is correct,
    // but seeding x1=x2=firstSample eliminates the large initial ringing that
    // otherwise produces false peaks and a spuriously high HR for ~30 seconds.
    if (_isFirstSample) {
      _isFirstSample = false;
      x1 = x;
      x2 = x;
    }
    final y = a0 * x + a1 * x1 + a2 * x2 - b1 * y1 - b2 * y2;
    x2 = x1;
    x1 = x;
    y2 = y1;
    y1 = y;
    return y;
  }
}

class _AdaptiveOpticalChannelSelector {
  static const double _meanAlpha = 0.005;
  static const double _energyAlpha = 0.02;

  _AdaptiveOpticalChannelSelector({
    this.useNormalizedRanking = true,
    this.minimumDwellSamples = 0,
  });

  /// How long a channel must be held before another may take over.
  ///
  /// Hysteresis alone does not stop thrashing when two channels are close: one
  /// observed session switched green/infrared more than ten times during
  /// calibration, the last of them immediately after the channel was committed
  /// and therefore right at the start of the baseline window. Each switch is a
  /// step of tens of thousands of counts into the beat path's filters, and that
  /// session's baseline came out at 31 bpm from three usable intervals.
  final int minimumDwellSamples;
  int _samplesOnCurrentChannel = 0;

  /// Ranks channels by modulation relative to their own DC level (the
  /// perfusion index) rather than by absolute AC amplitude.
  ///
  /// Absolute amplitude scales with DC, so the brightest channel wins even
  /// when its pulse is the weakest. Measured on an OpenEarable v2 recording:
  /// green DC 128540 / perfusion 0.045% / cardiac SNR 33.6 dB, versus infrared
  /// DC 40890 / perfusion 0.107% / SNR 43.6 dB. The old ranking chose green
  /// 96.8% of the time and detected 73% of beats; choosing infrared with no
  /// other change detected 101%.
  final bool useNormalizedRanking;

  bool _isInitialized = false;
  double _meanGreen = 0;
  double _meanRed = 0;
  double _meanIr = 0;
  double _energyGreen = 0;
  double _energyRed = 0;
  double _energyIr = 0;
  String selectedChannel = 'none';

  bool _isCommitted = false;
  String? _committedChannel;

  String? get committedChannel => _committedChannel;

  /// Modulation relative to DC, the comparable measure of pulse strength.
  double get greenPerfusion => _perfusion(_energyGreen, _meanGreen);
  double get redPerfusion => _perfusion(_energyRed, _meanRed);
  double get infraredPerfusion => _perfusion(_energyIr, _meanIr);

  static double _perfusion(double energy, double mean) {
    final magnitude = mean.abs();
    if (!energy.isFinite || !magnitude.isFinite || magnitude < 1e-6) return 0;
    return energy / magnitude;
  }

  /// Freezes the current choice for the rest of the measurement.
  ///
  /// Re-deciding per sample is itself harmful: every switch is a discontinuity
  /// to filters that carry state. The shipped selector switched 68 times in
  /// 150 seconds. Ranking correctly but still switching recovered only 85% of
  /// beats, against 101% when the channel was held fixed.
  void commit() {
    if (_isCommitted || selectedChannel == 'none') return;
    _isCommitted = true;
    _committedChannel = selectedChannel;
  }

  void releaseCommitment() {
    _isCommitted = false;
    _committedChannel = null;
  }

  double select({
    required double green,
    required double red,
    required double ir,
  }) {
    if (!_isInitialized) {
      _isInitialized = true;
      _meanGreen = green;
      _meanRed = red;
      _meanIr = ir;
    } else {
      _meanGreen = _ema(_meanGreen, green, _meanAlpha);
      _meanRed = _ema(_meanRed, red, _meanAlpha);
      _meanIr = _ema(_meanIr, ir, _meanAlpha);
    }

    _energyGreen = _ema(_energyGreen, (green - _meanGreen).abs(), _energyAlpha);
    _energyRed = _ema(_energyRed, (red - _meanRed).abs(), _energyAlpha);
    _energyIr = _ema(_energyIr, (ir - _meanIr).abs(), _energyAlpha);

    // Statistics above keep updating while committed so diagnostics stay
    // meaningful, but the channel itself no longer moves.
    if (_isCommitted) {
      final held = switch (_committedChannel) {
        'green' => green,
        'red' => red,
        'infrared' => ir,
        _ => double.nan,
      };
      if (held.isFinite) return held;
      _isCommitted = false;
      _committedChannel = null;
    }

    if (useNormalizedRanking) {
      final ranked = _selectByPerfusion(green: green, red: red, ir: ir);
      if (ranked != null) return ranked;
    }

    final strongestAltEnergy = max(_energyRed, _energyIr);
    final greenLikelyMissing =
        green.abs() < 1e-6 && (red.abs() > 1e-3 || ir.abs() > 1e-3);
    final greenWeakComparedToAlternatives =
        strongestAltEnergy > 1e-6 && _energyGreen < (strongestAltEnergy * 0.35);
    if (greenLikelyMissing || greenWeakComparedToAlternatives) {
      final preferRed = _energyRed >= _energyIr;
      final fallback = preferRed ? red : ir;
      if (fallback.isFinite) {
        selectedChannel = preferRed ? 'red' : 'infrared';
        return fallback;
      }
    }

    if (green.isFinite) {
      selectedChannel = 'green';
      return green;
    }
    if (red.isFinite && ir.isFinite) {
      selectedChannel = red.abs() >= ir.abs() ? 'red' : 'infrared';
      return red.abs() >= ir.abs() ? red : ir;
    }
    if (red.isFinite) {
      selectedChannel = 'red';
      return red;
    }
    if (ir.isFinite) {
      selectedChannel = 'infrared';
      return ir;
    }
    selectedChannel = 'none';
    return 0;
  }

  /// A challenger must be this much better than the channel already in use
  /// before the selector moves. Without a margin, channels whose pulse strength
  /// is genuinely comparable swap on floating-point noise, and each swap is a
  /// discontinuity to the stateful filters downstream — which costs more beats
  /// than picking the slightly weaker channel ever would.
  static const double _switchMargin = 1.15;

  /// Picks the channel with the strongest pulse relative to its own DC level.
  /// Returns null while no channel has enough evidence yet, so the caller falls
  /// back to the original absolute-amplitude rule.
  double? _selectByPerfusion({
    required double green,
    required double red,
    required double ir,
  }) {
    final candidates = <({String name, double value, double perfusion})>[
      (name: 'green', value: green, perfusion: greenPerfusion),
      (name: 'red', value: red, perfusion: redPerfusion),
      (name: 'infrared', value: ir, perfusion: infraredPerfusion),
    ].where((c) => c.value.isFinite && c.perfusion > 0).toList();
    if (candidates.isEmpty) return null;

    var best = candidates.first;
    for (final candidate in candidates.skip(1)) {
      if (candidate.perfusion > best.perfusion) best = candidate;
    }

    final incumbent = candidates
        .where((candidate) => candidate.name == selectedChannel)
        .firstOrNull;
    if (incumbent != null &&
        (best.perfusion < incumbent.perfusion * _switchMargin ||
            _samplesOnCurrentChannel < minimumDwellSamples)) {
      _samplesOnCurrentChannel++;
      return incumbent.value;
    }

    if (best.name != selectedChannel) _samplesOnCurrentChannel = 0;
    selectedChannel = best.name;
    return best.value;
  }

  double _ema(double state, double value, double alpha) {
    return (state * (1.0 - alpha)) + (value * alpha);
  }
}

class _AmbientLightCanceler {
  bool _isInitialized = false;
  double _meanGreen = 0;
  double _meanAmbient = 0;
  double _ambientVariance = 1.0;
  double _greenAmbientCovariance = 0.0;
  double _ambientGain = 0.65;

  double filter({
    required double green,
    required double ambient,
  }) {
    if (!_isInitialized) {
      _isInitialized = true;
      _meanGreen = green;
      _meanAmbient = ambient;
      return 0;
    }
    const meanAlpha = 0.005;
    const covarianceAlpha = 0.01;

    _meanGreen = (_meanGreen * (1.0 - meanAlpha)) + (green * meanAlpha);
    _meanAmbient = (_meanAmbient * (1.0 - meanAlpha)) + (ambient * meanAlpha);

    final centeredGreen = green - _meanGreen;
    final centeredAmbient = ambient - _meanAmbient;

    _ambientVariance = (_ambientVariance * (1.0 - covarianceAlpha)) +
        ((centeredAmbient * centeredAmbient) * covarianceAlpha);
    _greenAmbientCovariance =
        (_greenAmbientCovariance * (1.0 - covarianceAlpha)) +
            ((centeredGreen * centeredAmbient) * covarianceAlpha);

    if (_ambientVariance > 1e-6) {
      _ambientGain = (_greenAmbientCovariance / _ambientVariance).clamp(
        0.0,
        2.0,
      );
    }

    final cleaned = centeredGreen - (_ambientGain * centeredAmbient);
    return -cleaned;
  }
}

// The reference filter's motion EMAs were specified per sample at 50 Hz.
// Keep their real-time response unchanged when the selected IMU rate changes.
double _sensorEmaAlphaAtRate(double alphaAt50Hz, double frequencyHz) {
  final safeFrequency =
      frequencyHz.isFinite && frequencyHz > 0 ? frequencyHz : 50.0;
  return 1.0 - pow(1.0 - alphaAt50Hz, 50.0 / safeFrequency).toDouble();
}

class _MultiReferenceMotionCanceler {
  final double gravityAlpha;
  final double dynamicAlpha;
  final double scaleAlpha;
  final _PadasipStyleMultiInputNlmsCanceler _canceler =
      _PadasipStyleMultiInputNlmsCanceler(
    tapsPerAxis: 16,
  );

  _MultiReferenceMotionCanceler({required double accelerometerFreq})
      : gravityAlpha = _sensorEmaAlphaAtRate(0.04, accelerometerFreq),
        dynamicAlpha = _sensorEmaAlphaAtRate(0.18, accelerometerFreq),
        scaleAlpha = _sensorEmaAlphaAtRate(0.06, accelerometerFreq);

  bool _isInitialized = false;
  double _gravityX = 0;
  double _gravityY = 0;
  double _gravityZ = 0;
  double _dynamicX = 0;
  double _dynamicY = 0;
  double _dynamicZ = 0;
  double _referenceScaleX = 0.2;
  double _referenceScaleY = 0.2;
  double _referenceScaleZ = 0.2;

  void updateMotion({
    required double x,
    required double y,
    required double z,
  }) {
    if (!_isInitialized) {
      _isInitialized = true;
      _gravityX = x;
      _gravityY = y;
      _gravityZ = z;
      _dynamicX = 0;
      _dynamicY = 0;
      _dynamicZ = 0;
      _referenceScaleX = 0.2;
      _referenceScaleY = 0.2;
      _referenceScaleZ = 0.2;
      return;
    }

    _gravityX = (_gravityX * (1.0 - gravityAlpha)) + (x * gravityAlpha);
    _gravityY = (_gravityY * (1.0 - gravityAlpha)) + (y * gravityAlpha);
    _gravityZ = (_gravityZ * (1.0 - gravityAlpha)) + (z * gravityAlpha);

    final hpX = x - _gravityX;
    final hpY = y - _gravityY;
    final hpZ = z - _gravityZ;
    _referenceScaleX =
        (_referenceScaleX * (1.0 - scaleAlpha)) + (hpX.abs() * scaleAlpha);
    _referenceScaleY =
        (_referenceScaleY * (1.0 - scaleAlpha)) + (hpY.abs() * scaleAlpha);
    _referenceScaleZ =
        (_referenceScaleZ * (1.0 - scaleAlpha)) + (hpZ.abs() * scaleAlpha);

    final normalizedHpX = hpX / max(0.08, _referenceScaleX);
    final normalizedHpY = hpY / max(0.08, _referenceScaleY);
    final normalizedHpZ = hpZ / max(0.08, _referenceScaleZ);
    _dynamicX =
        (_dynamicX * (1.0 - dynamicAlpha)) + (normalizedHpX * dynamicAlpha);
    _dynamicY =
        (_dynamicY * (1.0 - dynamicAlpha)) + (normalizedHpY * dynamicAlpha);
    _dynamicZ =
        (_dynamicZ * (1.0 - dynamicAlpha)) + (normalizedHpZ * dynamicAlpha);
  }

  double filter(
    double value, {
    required double motionLevel,
  }) {
    if (!_isInitialized) {
      return value;
    }
    return _canceler.filter(
      signal: value,
      referenceX: _dynamicX,
      referenceY: _dynamicY,
      referenceZ: _dynamicZ,
      motionLevel: motionLevel,
    );
  }
}

/// Multi-input normalized LMS adaptive canceller adapted from the update rule
/// used in the open-source `padasip` NLMS implementation (MIT):
/// https://github.com/matousc89/padasip
class _PadasipStyleMultiInputNlmsCanceler {
  // filter() below runs once per PPG sample. heart_tracker's PpgFilter uses
  // baseMu=0.08/leakage=0.00025 at its validated 50Hz PPG rate; this app
  // streams PPG at 200Hz (4x), so these are the equivalent rates that give
  // the same real-time adaptation speed at 200Hz. _maxMu is an upper
  // saturation ceiling (already "as fast as possible"), so it doesn't need
  // rate-adjusting.
  static const double _baseMu = 0.0206;
  static const double _maxMu = 1.0;
  static const double _epsilon = 1e-6;
  static const double _leakage = 0.0000625;

  final int tapsPerAxis;
  late final List<double> _weights;
  late final List<double> _historyX;
  late final List<double> _historyY;
  late final List<double> _historyZ;
  late final List<double> _featureVector;

  bool _isInitialized = false;
  double _smoothedError = 0;

  _PadasipStyleMultiInputNlmsCanceler({
    required this.tapsPerAxis,
  }) {
    final length = max(3, tapsPerAxis * 3);
    _weights = List<double>.filled(length, 0, growable: false);
    _historyX = List<double>.filled(tapsPerAxis, 0, growable: false);
    _historyY = List<double>.filled(tapsPerAxis, 0, growable: false);
    _historyZ = List<double>.filled(tapsPerAxis, 0, growable: false);
    _featureVector = List<double>.filled(length, 0, growable: false);
  }

  double filter({
    required double signal,
    required double referenceX,
    required double referenceY,
    required double referenceZ,
    required double motionLevel,
  }) {
    if (!signal.isFinite ||
        !referenceX.isFinite ||
        !referenceY.isFinite ||
        !referenceZ.isFinite) {
      return signal;
    }
    if (!_isInitialized) {
      _isInitialized = true;
      _smoothedError = signal;
    }

    _push(_historyX, referenceX);
    _push(_historyY, referenceY);
    _push(_historyZ, referenceZ);
    _composeFeatureVector();

    final predictedNoise = _dot(_weights, _featureVector);
    final error = signal - predictedNoise;
    final norm = _epsilon + _dot(_featureVector, _featureVector);

    final motionScale = (motionLevel / 1.6).clamp(0.0, 1.0);
    final mu = _baseMu + ((_maxMu - _baseMu) * motionScale);
    final step = (mu * error) / norm;

    for (var i = 0; i < _weights.length; i++) {
      final updatedWeight =
          ((1.0 - _leakage) * _weights[i]) + (step * _featureVector[i]);
      _weights[i] = updatedWeight.clamp(-4.0, 4.0);
    }

    // 0.22/0.11 at heart_tracker's validated 50Hz PPG rate; equivalent at
    // this app's 200Hz PPG rate.
    final smoothAlpha = motionLevel > 1.0 ? 0.0602 : 0.0287;
    _smoothedError =
        (_smoothedError * (1.0 - smoothAlpha)) + (error * smoothAlpha);
    return _smoothedError;
  }

  void _push(List<double> history, double sample) {
    for (var i = history.length - 1; i > 0; i--) {
      history[i] = history[i - 1];
    }
    history[0] = sample;
  }

  void _composeFeatureVector() {
    var index = 0;
    for (var i = 0; i < tapsPerAxis; i++) {
      _featureVector[index++] = _historyX[i];
    }
    for (var i = 0; i < tapsPerAxis; i++) {
      _featureVector[index++] = _historyY[i];
    }
    for (var i = 0; i < tapsPerAxis; i++) {
      _featureVector[index++] = _historyZ[i];
    }
  }

  double _dot(List<double> a, List<double> b) {
    var sum = 0.0;
    for (var i = 0; i < a.length; i++) {
      sum += a[i] * b[i];
    }
    return sum;
  }
}

class _MotionNoiseSuppressor {
  // filter() below runs once per PPG sample. heart_tracker's PpgFilter uses
  // a 25-sample window (500ms) and stepScale=5.5/baseAlpha=0.26 at its
  // validated 50Hz PPG rate. This app streams PPG at 200Hz (4x), so 100
  // samples covers the same 500ms, and stepScale/baseAlpha are the
  // equivalent rates that give the same real-time behavior at 200Hz.
  static const int _windowSize = 100;
  static const double _baseOutlierSigma = 3.0;
  static const double _baseStepScale = 1.375;
  static const double _baseAlpha = 0.0725;

  final double gravityAlpha;
  final double motionAlpha;

  _MotionNoiseSuppressor({required double accelerometerFreq})
      : gravityAlpha = _sensorEmaAlphaAtRate(0.04, accelerometerFreq),
        motionAlpha = _sensorEmaAlphaAtRate(0.15, accelerometerFreq);

  final List<double> _history = [];

  bool _isInitialized = false;
  double _lastOutput = 0;
  double _gravityMagnitude = 9.81;
  double _motionLevel = 0;

  double get motionLevel => _motionLevel;

  void updateMotionMagnitude(double magnitude) {
    if (!_isInitialized) {
      _gravityMagnitude = magnitude;
      _motionLevel = 0;
      return;
    }

    _gravityMagnitude =
        (_gravityMagnitude * (1.0 - gravityAlpha)) + (magnitude * gravityAlpha);
    final dynamicMagnitude = (magnitude - _gravityMagnitude).abs();
    final dynamicScale = max(0.08, _gravityMagnitude.abs() * 0.02);
    final normalizedDynamicMagnitude = dynamicMagnitude / dynamicScale;
    _motionLevel = ((_motionLevel * (1.0 - motionAlpha)) +
            (normalizedDynamicMagnitude * motionAlpha))
        .clamp(
      0.0,
      8.0,
    );
  }

  double filter(double rawValue) {
    if (!_isInitialized) {
      _isInitialized = true;
      _lastOutput = rawValue;
      _history
        ..clear()
        ..addAll(List<double>.filled(_windowSize, rawValue));
      return rawValue;
    }

    if (_history.length >= _windowSize) {
      _history.removeAt(0);
    }
    _history.add(rawValue);

    final median = _medianOf(_history);
    final mad = _medianOf(_history.map((value) => (value - median).abs()));
    final sigma = max(1e-3, mad * 1.4826);

    final motionFactor = 1.0 + min(_motionLevel / 0.85, 2.8);
    final outlierSigma = _baseOutlierSigma / motionFactor;
    final minBound = median - (sigma * outlierSigma);
    final maxBound = median + (sigma * outlierSigma);
    final clipped = rawValue.clamp(minBound, maxBound).toDouble();

    final stepLimit = max(1e-3, (_baseStepScale * sigma) / motionFactor);
    final stepped = _lastOutput +
        (clipped - _lastOutput).clamp(-stepLimit, stepLimit).toDouble();

    // Floor 0.07 at heart_tracker's validated 50Hz PPG rate; equivalent at
    // this app's 200Hz PPG rate.
    final alpha = (_baseAlpha / motionFactor).clamp(0.018, _baseAlpha);
    final smoothed = _lastOutput + (alpha * (stepped - _lastOutput));
    _lastOutput = smoothed;
    return smoothed;
  }

  double _medianOf(Iterable<double> values) {
    final sorted = values.toList(growable: false)..sort();
    if (sorted.isEmpty) {
      return 0;
    }
    final middle = sorted.length ~/ 2;
    if (sorted.length.isOdd) {
      return sorted[middle];
    }
    return (sorted[middle - 1] + sorted[middle]) / 2;
  }
}

class _BoundedSignalNormalizer {
  bool _isInitialized = false;
  double _center = 0;
  double _envelope = 0.25;
  double _lastOutput = 0;

  double filter(
    double value, {
    required double motionLevel,
  }) {
    if (!_isInitialized) {
      _isInitialized = true;
      _center = value;
      _envelope = max(0.18, value.abs());
      _lastOutput = 0;
      return 0;
    }

    // heart_tracker's PpgFilter uses 0.01/0.02 at its validated 50Hz PPG
    // rate. This app streams PPG at 200Hz (4x), so these are the equivalent
    // alphas that give the same real-time EMA time constant at 200Hz.
    const centerAlpha = 0.0025;
    const envelopeAlpha = 0.005;

    _center = (_center * (1.0 - centerAlpha)) + (value * centerAlpha);
    final centered = value - _center;
    _envelope =
        (_envelope * (1.0 - envelopeAlpha)) + (centered.abs() * envelopeAlpha);

    final normalized = centered / max(0.12, _envelope);
    final maxAbs = motionLevel > 1.2 ? 1.15 : 1.45;
    final clipped = normalized.clamp(-maxAbs, maxAbs).toDouble();

    // 0.12/0.22 at heart_tracker's validated 50Hz PPG rate; equivalent at
    // this app's 200Hz PPG rate.
    final alpha = motionLevel > 1.2 ? 0.0315 : 0.0602;
    final smoothed = _lastOutput + (alpha * (clipped - _lastOutput));
    _lastOutput = smoothed;
    return smoothed;
  }
}
