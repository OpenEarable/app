// ignore_for_file: cancel_subscriptions

import 'dart:async';
import 'dart:collection';
import 'dart:math';

import 'package:open_wearable/apps/heart_tracker/model/band_pass_filter.dart';

class PpgOpticalSample {
  final int timestamp;
  final double green;
  final double ambient;

  const PpgOpticalSample({
    required this.timestamp,
    required this.green,
    required this.ambient,
  });
}

class PpgVitals {
  final double? heartRateBpm;
  final double? hrvRmssdMs;

  const PpgVitals({
    required this.heartRateBpm,
    required this.hrvRmssdMs,
  });

  const PpgVitals.invalid()
      : heartRateBpm = null,
        hrvRmssdMs = null;
}

class PpgFilter {
  final Stream<PpgOpticalSample> inputStream;
  final Stream<(int, double)>? motionStream;
  final double sampleFreq;
  final int timestampExponent;

  final double _minProminence = 0.12;
  late final double _minPeakDistanceTicks;

  double _hrEstimate = 75.0;
  double _hrCovariance = 1.0;
  final double _hrProcessNoise = 0.02;
  final double _hrMeasurementNoise = 5.0;

  double _hrvEstimateMs = 35.0;
  final double _hrvSmoothingAlpha = 0.18;

  StreamSubscription<(int, double)>? _motionSubscription;
  Stream<_MotionAwareSample>? _processedStream;
  Stream<(int, double)>? _displaySignalStream;
  Stream<PpgVitals>? _vitalsStream;

  PpgFilter({
    required this.inputStream,
    required this.sampleFreq,
    required this.timestampExponent,
    this.motionStream,
  }) {
    final ticksPerSecond = pow(10, -timestampExponent).toDouble();
    _minPeakDistanceTicks = max(1.0, 0.30 * ticksPerSecond);
  }

  Stream<(int, double)> get displaySignalStream {
    if (_displaySignalStream != null) {
      return _displaySignalStream!;
    }
    final proxyWaveform = _ProxyPpgWaveformSynthesizer(
      timestampExponent: timestampExponent,
    );
    _displaySignalStream = _sampleStream
        .map((sample) => (sample.timestamp, proxyWaveform.next(sample)))
        .asBroadcastStream();
    return _displaySignalStream!;
  }

  Stream<double?> get heartRateStream =>
      _metricsStream.map((vitals) => vitals.heartRateBpm);

  Stream<double?> get hrvStream =>
      _metricsStream.map((vitals) => vitals.hrvRmssdMs);

  void dispose() {
    final subscription = _motionSubscription;
    _motionSubscription = null;
    if (subscription != null) {
      unawaited(subscription.cancel());
    }
  }

  Stream<_MotionAwareSample> get _sampleStream {
    if (_processedStream != null) {
      return _processedStream!;
    }
    _processedStream = _createProcessedStream().asBroadcastStream();
    return _processedStream!;
  }

  Stream<PpgVitals> get _metricsStream {
    if (_vitalsStream != null) {
      return _vitalsStream!;
    }
    _vitalsStream = _createVitalsStream().asBroadcastStream();
    return _vitalsStream!;
  }

  Stream<_MotionAwareSample> _createProcessedStream() {
    final ambientCanceler = _AmbientLightCanceler();
    final motionSuppressor = _MotionNoiseSuppressor();
    final bandPassFilter = BandPassFilter(
      sampleFreq: sampleFreq,
      lowCut: 0.7,
      highCut: 4.0,
    );
    final normalizer = _BoundedSignalNormalizer();

    if (motionStream != null) {
      _motionSubscription = motionStream!.listen((event) {
        motionSuppressor.updateMotionMagnitude(event.$2);
      });
    }

    return inputStream.map((sample) {
      final ambientCanceled = ambientCanceler.filter(
        green: sample.green,
        ambient: sample.ambient,
      );
      final motionSuppressed = motionSuppressor.filter(ambientCanceled);
      final bandPassed = bandPassFilter.filter(motionSuppressed);
      final bounded = normalizer.filter(
        bandPassed,
        motionLevel: motionSuppressor.motionLevel,
      );
      return _MotionAwareSample(
        timestamp: sample.timestamp,
        signal: bounded,
        motionLevel: motionSuppressor.motionLevel,
      );
    });
  }

  double _kalmanUpdateHeartRate(double measurement) {
    if (!measurement.isFinite) {
      return _hrEstimate;
    }

    _hrCovariance += _hrProcessNoise;
    final gain = _hrCovariance / (_hrCovariance + _hrMeasurementNoise);
    _hrEstimate += gain * (measurement - _hrEstimate);
    _hrCovariance *= (1 - gain);
    return _hrEstimate;
  }

  double _smoothHrv(double measurementMs) {
    if (!measurementMs.isFinite || measurementMs <= 0) {
      return _hrvEstimateMs;
    }
    _hrvEstimateMs = (_hrvEstimateMs * (1.0 - _hrvSmoothingAlpha)) +
        (measurementMs * _hrvSmoothingAlpha);
    return _hrvEstimateMs;
  }

  List<_MotionAwareSample> _smoothBuffer(
    List<_MotionAwareSample> raw, {
    int radius = 2,
  }) {
    final smoothed = <_MotionAwareSample>[];
    for (var i = 0; i < raw.length; i++) {
      final start = max(0, i - radius);
      final end = min(raw.length - 1, i + radius);
      final average = raw
              .sublist(start, end + 1)
              .map((sample) => sample.signal)
              .reduce((a, b) => a + b) /
          (end - start + 1);
      smoothed.add(
        _MotionAwareSample(
          timestamp: raw[i].timestamp,
          signal: average,
          motionLevel: raw[i].motionLevel,
        ),
      );
    }
    return smoothed;
  }

  List<int> _detectPeaks(List<_MotionAwareSample> samples) {
    final buffer = _smoothBuffer(samples, radius: 3);
    final peakTimestamps = <int>[];

    for (var i = 1; i < buffer.length - 1; i++) {
      final prev = buffer[i - 1];
      final current = buffer[i];
      final next = buffer[i + 1];

      final lastPeak = peakTimestamps.isNotEmpty ? peakTimestamps.last : null;
      if (lastPeak != null &&
          (current.timestamp - lastPeak) < _minPeakDistanceTicks) {
        continue;
      }

      if (current.signal > prev.signal &&
          current.signal > next.signal &&
          (current.signal - prev.signal) > _minProminence &&
          (current.signal - next.signal) > _minProminence) {
        peakTimestamps.add(current.timestamp);
      }
    }

    return peakTimestamps;
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

  double? _computeRmssd(List<double> ibiTicks) {
    if (ibiTicks.length < 2) {
      return null;
    }

    var sumSquared = 0.0;
    var count = 0;
    for (var i = 1; i < ibiTicks.length; i++) {
      final delta = ibiTicks[i] - ibiTicks[i - 1];
      sumSquared += delta * delta;
      count += 1;
    }

    if (count == 0) {
      return null;
    }
    return sqrt(sumSquared / count);
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

  Stream<PpgVitals> _createVitalsStream() async* {
    final ticksPerSecond = pow(10, -timestampExponent).toDouble();
    final ticksToMilliseconds = pow(10, timestampExponent + 3).toDouble();
    final windowDurationTicks = 10.0 * ticksPerSecond;
    final minimumWindowTicks = 4.0 * ticksPerSecond;
    final evaluationPeriodTicks = max(1.0, ticksPerSecond);
    final buffer = <_MotionAwareSample>[];
    var lastEvaluationTick = double.negativeInfinity;

    await for (final sample in _sampleStream) {
      buffer.add(sample);
      buffer.removeWhere(
        (item) => item.timestamp < sample.timestamp - windowDurationTicks,
      );

      if ((sample.timestamp - lastEvaluationTick) < evaluationPeriodTicks) {
        continue;
      }
      lastEvaluationTick = sample.timestamp.toDouble();

      if (buffer.length < 20 ||
          (buffer.last.timestamp - buffer.first.timestamp) <
              minimumWindowTicks) {
        yield const PpgVitals.invalid();
        continue;
      }

      final values = buffer.map((item) => item.signal).toList(growable: false);
      final minValue = values.reduce(min);
      final maxValue = values.reduce(max);
      final signalRange = maxValue - minValue;
      final rms = sqrt(
        values.map((value) => value * value).reduce((a, b) => a + b) /
            values.length,
      );
      final averageMotion =
          buffer.map((item) => item.motionLevel).reduce((a, b) => a + b) /
              buffer.length;

      if (signalRange < 0.30 || rms < 0.10 || averageMotion > 1.9) {
        yield const PpgVitals.invalid();
        continue;
      }

      final peaks = _detectPeaks(buffer);
      if (peaks.length < 3) {
        yield const PpgVitals.invalid();
        continue;
      }

      final ibiTicks = <double>[];
      for (var i = 1; i < peaks.length; i++) {
        final interval = (peaks[i] - peaks[i - 1]).toDouble();
        if (interval > 0) {
          ibiTicks.add(interval);
        }
      }
      if (ibiTicks.length < 2) {
        yield const PpgVitals.invalid();
        continue;
      }

      final robustIbiTicks = _removeIbiOutliers(ibiTicks);
      final meanIbiTicks =
          robustIbiTicks.reduce((a, b) => a + b) / robustIbiTicks.length;
      if (!meanIbiTicks.isFinite || meanIbiTicks <= 0) {
        yield const PpgVitals.invalid();
        continue;
      }

      final ibiVariation = _standardDeviation(robustIbiTicks) / meanIbiTicks;
      if (!ibiVariation.isFinite || ibiVariation > 0.32) {
        yield const PpgVitals.invalid();
        continue;
      }

      final heartRate = 60.0 * ticksPerSecond / meanIbiTicks;
      if (!heartRate.isFinite || heartRate < 35 || heartRate > 210) {
        yield const PpgVitals.invalid();
        continue;
      }
      final smoothedHeartRate = _kalmanUpdateHeartRate(heartRate);

      final rmssdTicks = _computeRmssd(robustIbiTicks);
      if (rmssdTicks == null || !rmssdTicks.isFinite || rmssdTicks <= 0) {
        yield const PpgVitals.invalid();
        continue;
      }
      final hrvMs = rmssdTicks * ticksToMilliseconds;
      if (!hrvMs.isFinite || hrvMs < 5 || hrvMs > 250) {
        yield const PpgVitals.invalid();
        continue;
      }
      final smoothedHrvMs = _smoothHrv(hrvMs);

      yield PpgVitals(
        heartRateBpm: smoothedHeartRate,
        hrvRmssdMs: smoothedHrvMs,
      );
    }
  }
}

class _MotionAwareSample {
  final int timestamp;
  final double signal;
  final double motionLevel;

  const _MotionAwareSample({
    required this.timestamp,
    required this.signal,
    required this.motionLevel,
  });
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

    const meanAlpha = 0.02;
    const covarianceAlpha = 0.04;

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

class _MotionNoiseSuppressor {
  static const int _windowSize = 25;
  static const double _baseOutlierSigma = 3.0;
  static const double _baseStepScale = 5.5;
  static const double _baseAlpha = 0.26;

  final ListQueue<double> _history = ListQueue<double>();

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

    _gravityMagnitude = (_gravityMagnitude * 0.96) + (magnitude * 0.04);
    final dynamicMagnitude = (magnitude - _gravityMagnitude).abs();
    _motionLevel = (_motionLevel * 0.85) + (dynamicMagnitude * 0.15);
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
      _history.removeFirst();
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

    final alpha = (_baseAlpha / motionFactor).clamp(0.07, _baseAlpha);
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

    const centerAlpha = 0.01;
    const envelopeAlpha = 0.02;

    _center = (_center * (1.0 - centerAlpha)) + (value * centerAlpha);
    final centered = value - _center;
    _envelope =
        (_envelope * (1.0 - envelopeAlpha)) + (centered.abs() * envelopeAlpha);

    final normalized = centered / max(0.12, _envelope);
    final maxAbs = motionLevel > 1.2 ? 1.15 : 1.45;
    final clipped = normalized.clamp(-maxAbs, maxAbs).toDouble();

    final alpha = motionLevel > 1.2 ? 0.12 : 0.22;
    final smoothed = _lastOutput + (alpha * (clipped - _lastOutput));
    _lastOutput = smoothed;
    return smoothed;
  }
}

class _ProxyPpgWaveformSynthesizer {
  static const double _windowSeconds = 6.0;
  static const double _defaultPeriodSeconds = 0.82;
  static const double _minPeakDistanceSeconds = 0.28;
  static const double _minIbiSeconds = 0.33;
  static const double _maxIbiSeconds = 1.70;

  final double _ticksPerSecond;
  final double _windowTicks;
  final double _minPeakDistanceTicks;
  final double _minIbiTicks;
  final double _maxIbiTicks;

  final ListQueue<_MotionAwareSample> _signalWindow = ListQueue();
  final ListQueue<int> _peakWindow = ListQueue();

  _MotionAwareSample? _previousSample;
  double _previousDiff = 0.0;
  int? _lastTimestamp;
  int? _lastPeakTimestamp;

  double _periodTicks;
  double _phase = 0.0;
  double _amplitude = 0.55;
  double _heartbeatConfidence = 0.0;

  _ProxyPpgWaveformSynthesizer({
    required int timestampExponent,
  })  : _ticksPerSecond = pow(10, -timestampExponent).toDouble(),
        _windowTicks = _windowSeconds * pow(10, -timestampExponent).toDouble(),
        _periodTicks =
            _defaultPeriodSeconds * pow(10, -timestampExponent).toDouble(),
        _minPeakDistanceTicks =
            _minPeakDistanceSeconds * pow(10, -timestampExponent).toDouble(),
        _minIbiTicks = _minIbiSeconds * pow(10, -timestampExponent).toDouble(),
        _maxIbiTicks = _maxIbiSeconds * pow(10, -timestampExponent).toDouble();

  double next(_MotionAwareSample sample) {
    _appendSample(sample);
    _updatePeakDetector(sample);
    _advancePhase(sample.timestamp);

    final heartbeatVisible = _isHeartbeatVisible(sample.timestamp);
    if (!heartbeatVisible) {
      _amplitude = _amplitude * 0.92;
      if (_amplitude < 0.05) {
        _amplitude = 0.05;
      }
      return 0.0;
    }

    final quality = _qualityScore();
    final targetAmplitude = (0.40 + (0.55 * quality)).clamp(0.32, 0.95);
    _amplitude = (_amplitude * 0.87) + (targetAmplitude * 0.13);
    final waveform = _ppgTemplate(_phase);
    return (_amplitude * waveform).clamp(-1.2, 1.2).toDouble();
  }

  void _appendSample(_MotionAwareSample sample) {
    _signalWindow.addLast(sample);
    final cutoff = sample.timestamp - _windowTicks;
    while (_signalWindow.isNotEmpty && _signalWindow.first.timestamp < cutoff) {
      _signalWindow.removeFirst();
    }
    while (_peakWindow.isNotEmpty && _peakWindow.first < cutoff) {
      _peakWindow.removeFirst();
    }
  }

  void _updatePeakDetector(_MotionAwareSample sample) {
    final previous = _previousSample;
    if (previous == null) {
      _previousSample = sample;
      return;
    }

    final diff = sample.signal - previous.signal;
    if (_previousDiff > 0 && diff <= 0) {
      _tryRegisterPeak(previous);
    }

    _previousDiff = diff;
    _previousSample = sample;
  }

  void _tryRegisterPeak(_MotionAwareSample candidatePeak) {
    if (_signalWindow.length < 18 || candidatePeak.motionLevel > 2.45) {
      return;
    }

    final stats = _windowStats();
    final prominenceThreshold = max(
      0.08,
      min(0.32, stats.range * 0.16),
    );
    if (candidatePeak.signal < prominenceThreshold) {
      return;
    }

    final lastPeak = _lastPeakTimestamp;
    if (lastPeak != null) {
      final sinceLastPeak = (candidatePeak.timestamp - lastPeak).toDouble();
      if (sinceLastPeak < _minPeakDistanceTicks) {
        return;
      }
      if (sinceLastPeak < _minIbiTicks || sinceLastPeak > _maxIbiTicks) {
        _heartbeatConfidence = max(0.0, _heartbeatConfidence - 0.08);
        return;
      }

      _periodTicks = (_periodTicks * 0.82) + (sinceLastPeak * 0.18);
    }

    _lastPeakTimestamp = candidatePeak.timestamp;
    _peakWindow.addLast(candidatePeak.timestamp);
    _phase = 0.0;
    _heartbeatConfidence = min(1.0, _heartbeatConfidence + 0.24);
  }

  void _advancePhase(int timestamp) {
    final lastTimestamp = _lastTimestamp;
    _lastTimestamp = timestamp;
    if (lastTimestamp == null || _periodTicks <= 1.0) {
      return;
    }

    final deltaTicks = max(0, timestamp - lastTimestamp).toDouble();
    _phase += deltaTicks / _periodTicks;
    _phase -= _phase.floorToDouble();
  }

  bool _isHeartbeatVisible(int timestamp) {
    final lastPeak = _lastPeakTimestamp;
    if (lastPeak == null || _peakWindow.length < 2) {
      _heartbeatConfidence = max(0.0, _heartbeatConfidence - 0.02);
      return false;
    }

    final maxPeakAgeTicks = max(2.2 * _periodTicks, 2.4 * _ticksPerSecond);
    final hasRecentPeak = (timestamp - lastPeak).toDouble() <= maxPeakAgeTicks;
    final quality = _qualityScore();

    if (!hasRecentPeak || quality < 0.32 || _heartbeatConfidence < 0.20) {
      _heartbeatConfidence = max(0.0, _heartbeatConfidence - 0.04);
      return false;
    }
    return true;
  }

  double _qualityScore() {
    if (_signalWindow.length < 8) {
      return 0.0;
    }

    final stats = _windowStats();
    final rangeScore = ((stats.range - 0.22) / 0.90).clamp(0.0, 1.0);
    final rmsScore = ((stats.rms - 0.06) / 0.45).clamp(0.0, 1.0);
    final motionScore = (1.0 - (stats.averageMotion / 2.60)).clamp(0.0, 1.0);
    final peakDensity = (_peakWindow.length / 4.0).clamp(0.0, 1.0);

    return (0.30 * rangeScore) +
        (0.25 * rmsScore) +
        (0.25 * motionScore) +
        (0.20 * peakDensity);
  }

  _WindowStats _windowStats() {
    final values =
        _signalWindow.map((sample) => sample.signal).toList(growable: false);
    final minValue = values.reduce(min);
    final maxValue = values.reduce(max);
    final range = maxValue - minValue;

    final squaredSum =
        values.map((value) => value * value).reduce((a, b) => a + b);
    final rms = sqrt(squaredSum / values.length);

    final averageMotion = _signalWindow
            .map((sample) => sample.motionLevel)
            .reduce((a, b) => a + b) /
        _signalWindow.length;

    return _WindowStats(
      range: range,
      rms: rms,
      averageMotion: averageMotion,
    );
  }

  double _ppgTemplate(double phase) {
    final p = phase - phase.floorToDouble();
    final systolic = exp(
      -pow((p - 0.14) / 0.045, 2).toDouble(),
    );
    final notch = -0.38 *
        exp(
          -pow((p - 0.29) / 0.028, 2).toDouble(),
        );
    final dicrotic = 0.42 *
        exp(
          -pow((p - 0.39) / 0.055, 2).toDouble(),
        );
    final tail = -0.22 *
        exp(
          -pow((p - 0.72) / 0.16, 2).toDouble(),
        );

    final waveform = (1.18 * systolic) + notch + dicrotic + tail - 0.28;
    return waveform.clamp(-1.0, 1.0).toDouble();
  }
}

class _WindowStats {
  final double range;
  final double rms;
  final double averageMotion;

  const _WindowStats({
    required this.range,
    required this.rms,
    required this.averageMotion,
  });
}
