// ignore_for_file: cancel_subscriptions

import 'dart:async';
import 'dart:collection';
import 'dart:math';

import 'package:open_wearable/apps/heart_tracker/model/band_pass_filter.dart';

enum PpgSignalQuality {
  unavailable,
  bad,
  fair,
  good,
}

class PpgOpticalSample {
  final int timestamp;
  final double red;
  final double ir;
  final double green;
  final double ambient;

  const PpgOpticalSample({
    required this.timestamp,
    required this.red,
    required this.ir,
    required this.green,
    required this.ambient,
  });
}

class PpgVitals {
  final double? heartRateBpm;
  final double? hrvRmssdMs;
  final PpgSignalQuality signalQuality;

  const PpgVitals({
    required this.heartRateBpm,
    required this.hrvRmssdMs,
    required this.signalQuality,
  });

  const PpgVitals.invalid({
    this.signalQuality = PpgSignalQuality.unavailable,
  })  : heartRateBpm = null,
        hrvRmssdMs = null;
}

class PpgFilter {
  final Stream<PpgOpticalSample> inputStream;
  final Stream<(int, double)>? motionStream;
  final double sampleFreq;
  final int timestampExponent;

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
    _displaySignalStream = _sampleStream
        .map((sample) => (sample.timestamp, sample.signal))
        .asBroadcastStream();
    return _displaySignalStream!;
  }

  Stream<double?> get heartRateStream =>
      _metricsStream.map((vitals) => vitals.heartRateBpm);

  Stream<double?> get hrvStream =>
      _metricsStream.map((vitals) => vitals.hrvRmssdMs);

  Stream<PpgSignalQuality> get signalQualityStream =>
      _metricsStream.map((vitals) => vitals.signalQuality).distinct();

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
        rawGreen: sample.green,
        rawAmbient: sample.ambient,
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
          rawGreen: raw[i].rawGreen,
          rawAmbient: raw[i].rawAmbient,
          signal: average,
          motionLevel: raw[i].motionLevel,
        ),
      );
    }
    return smoothed;
  }

  List<int> _detectPeaksOpenRing(
    List<_MotionAwareSample> samples, {
    required double thresholdRatio,
    required double minIntervalSec,
  }) {
    final buffer = _smoothBuffer(samples, radius: 2);
    if (buffer.length < 3) {
      return const [];
    }
    var minValue = double.infinity;
    var maxValue = -double.infinity;
    var sum = 0.0;
    for (final sample in buffer) {
      minValue = min(minValue, sample.signal);
      maxValue = max(maxValue, sample.signal);
      sum += sample.signal;
    }
    if (!minValue.isFinite || !maxValue.isFinite) {
      return const [];
    }
    final mean = sum / buffer.length;
    final dynamicThreshold = mean + ((maxValue - mean) * thresholdRatio);

    final ticksPerSecond = pow(10, -timestampExponent).toDouble();
    final minDistanceTicks = max(
      _minPeakDistanceTicks,
      minIntervalSec * ticksPerSecond,
    );
    final peakTimestamps = <int>[];
    var i = 0;

    while (i < buffer.length) {
      if (buffer[i].signal >= dynamicThreshold) {
        var regionMaxIdx = i;
        var regionMaxVal = buffer[i].signal;
        var j = i + 1;
        while (j < buffer.length && buffer[j].signal >= dynamicThreshold) {
          if (buffer[j].signal > regionMaxVal) {
            regionMaxVal = buffer[j].signal;
            regionMaxIdx = j;
          }
          j += 1;
        }
        final candidateTimestamp = buffer[regionMaxIdx].timestamp;
        final canAdd = peakTimestamps.isEmpty ||
            (candidateTimestamp - peakTimestamps.last).toDouble() >=
                minDistanceTicks;
        if (canAdd) {
          peakTimestamps.add(candidateTimestamp);
        }
        i = j;
      } else {
        i += 1;
      }
    }

    return peakTimestamps;
  }

  ({double? heartRateBpm, List<int> peakTimestamps}) _estimateHeartRateByPeak(
    List<_MotionAwareSample> samples, {
    required double ticksPerSecond,
  }) {
    final peaks = _detectPeaksOpenRing(
      samples,
      thresholdRatio: 0.0,
      minIntervalSec: 0.4,
    );
    if (peaks.length < 2) {
      return (heartRateBpm: null, peakTimestamps: peaks);
    }

    final intervalsSeconds = <double>[];
    for (var i = 1; i < peaks.length; i++) {
      final intervalSeconds =
          (peaks[i] - peaks[i - 1]).toDouble() / max(1.0, ticksPerSecond);
      if (intervalSeconds >= 0.30 && intervalSeconds <= 1.50) {
        intervalsSeconds.add(intervalSeconds);
      }
    }
    if (intervalsSeconds.isEmpty) {
      return (heartRateBpm: null, peakTimestamps: peaks);
    }

    intervalsSeconds.sort();
    final medianIntervalSeconds =
        intervalsSeconds[intervalsSeconds.length ~/ 2];
    final heartRate = 60.0 / medianIntervalSeconds;
    if (!heartRate.isFinite || heartRate < 35 || heartRate > 210) {
      return (heartRateBpm: null, peakTimestamps: peaks);
    }

    return (heartRateBpm: heartRate, peakTimestamps: peaks);
  }

  double? _estimateHeartRateByFft(
    List<_MotionAwareSample> samples, {
    required double estimatedSampleFreqHz,
  }) {
    if (samples.length < 32 || estimatedSampleFreqHz <= 1.0) {
      return null;
    }

    final values =
        samples.map((sample) => sample.signal).toList(growable: false);
    final mean = values.reduce((a, b) => a + b) / values.length;
    final centered =
        values.map((value) => value - mean).toList(growable: false);

    var fftSize = 1;
    while (fftSize < centered.length) {
      fftSize <<= 1;
    }
    final minHz = 35.0 / 60.0;
    final maxHz = 210.0 / 60.0;
    var minBin = (minHz * fftSize / estimatedSampleFreqHz).floor();
    var maxBin = (maxHz * fftSize / estimatedSampleFreqHz).ceil();
    minBin = min(max(minBin, 1), fftSize ~/ 2);
    maxBin = min(max(maxBin, minBin), fftSize ~/ 2);
    if (maxBin <= minBin) {
      return null;
    }

    var bestBin = -1;
    var bestPower = -double.infinity;
    for (var k = minBin; k <= maxBin; k++) {
      var real = 0.0;
      var imag = 0.0;
      for (var n = 0; n < centered.length; n++) {
        final angle = 2 * pi * k * n / fftSize;
        real += centered[n] * cos(angle);
        imag -= centered[n] * sin(angle);
      }
      final power = (real * real) + (imag * imag);
      if (power > bestPower) {
        bestPower = power;
        bestBin = k;
      }
    }
    if (bestBin < 0 || !bestPower.isFinite || bestPower <= 1e-9) {
      return null;
    }

    final dominantFrequencyHz = bestBin * estimatedSampleFreqHz / fftSize;
    final heartRate = dominantFrequencyHz * 60.0;
    if (!heartRate.isFinite || heartRate < 35 || heartRate > 210) {
      return null;
    }
    return heartRate;
  }

  double _estimateEffectiveSampleFreqHz(
    List<_MotionAwareSample> samples, {
    required double ticksPerSecond,
  }) {
    if (samples.length < 2) {
      return sampleFreq;
    }
    final durationTicks =
        (samples.last.timestamp - samples.first.timestamp).toDouble();
    if (durationTicks <= 0) {
      return sampleFreq;
    }
    final estimated = ((samples.length - 1) * ticksPerSecond) / durationTicks;
    if (!estimated.isFinite || estimated < 5 || estimated > 200) {
      return sampleFreq;
    }
    return estimated;
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

  PpgSignalQuality _classifyQuality(double score) {
    if (!score.isFinite || score <= 0) {
      return PpgSignalQuality.unavailable;
    }
    if (score < 0.30) {
      return PpgSignalQuality.bad;
    }
    if (score < 0.62) {
      return PpgSignalQuality.fair;
    }
    return PpgSignalQuality.good;
  }

  ({double score, double averageMotion, double averageAmbient})
      _estimateRecentRawQualityScore(
    List<_MotionAwareSample> samples, {
    required int latestTimestamp,
    required double ticksPerSecond,
  }) {
    final qualityWindowTicks = 3.0 * ticksPerSecond;
    final recent = samples
        .where(
          (sample) => sample.timestamp >= latestTimestamp - qualityWindowTicks,
        )
        .toList(growable: false);
    final minimumSamples = max(8, (sampleFreq * 1.2).round());
    if (recent.length < minimumSamples) {
      return (score: 0.0, averageMotion: 0.0, averageAmbient: 0.0);
    }

    final rawValues =
        recent.map((sample) => sample.rawGreen).toList(growable: false);
    final meanRawAbs =
        rawValues.map((value) => value.abs()).reduce((a, b) => a + b) /
            rawValues.length;
    if (!meanRawAbs.isFinite || meanRawAbs <= 1e-6) {
      return (score: 0.0, averageMotion: 0.0, averageAmbient: 0.0);
    }

    final minRaw = rawValues.reduce(min);
    final maxRaw = rawValues.reduce(max);
    final rangeRaw = maxRaw - minRaw;
    final stdRaw = _standardDeviation(rawValues);
    final normalizedRange = rangeRaw / meanRawAbs;
    final normalizedStd = stdRaw / meanRawAbs;

    final averageMotion =
        recent.map((sample) => sample.motionLevel).reduce((a, b) => a + b) /
            recent.length;
    final averageAmbient =
        recent.map((sample) => sample.rawAmbient).reduce((a, b) => a + b) /
            recent.length;

    final rangeScore = ((normalizedRange - 0.004) / 0.045).clamp(0.0, 1.0);
    final stdScore = ((normalizedStd - 0.0015) / 0.015).clamp(0.0, 1.0);
    final motionScore = (1.0 - (averageMotion / 2.4)).clamp(0.0, 1.0);

    var score = ((0.45 * rangeScore) + (0.35 * stdScore) + (0.20 * motionScore))
        .clamp(0.0, 1.0);

    // Make accelerometer motion a strong quality prior:
    // heavy movement should almost always mark PPG quality as bad.
    if (averageMotion >= 1.55) {
      score = min(score, 0.10);
    } else if (averageMotion >= 1.20) {
      score = min(score, 0.24);
    } else if (averageMotion >= 0.95) {
      score = min(score, 0.45);
    }

    return (
      score: score,
      averageMotion: averageMotion,
      averageAmbient: averageAmbient,
    );
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
        yield const PpgVitals.invalid(
          signalQuality: PpgSignalQuality.unavailable,
        );
        continue;
      }
      final recentQuality = _estimateRecentRawQualityScore(
        buffer,
        latestTimestamp: sample.timestamp,
        ticksPerSecond: ticksPerSecond,
      );
      var qualityScore = recentQuality.score;
      final recentMotion = recentQuality.averageMotion;
      final recentAmbient = recentQuality.averageAmbient;

      if (recentMotion >= 1.55) {
        yield const PpgVitals.invalid(
          signalQuality: PpgSignalQuality.bad,
        );
        continue;
      }
      if (recentAmbient > 180.0) {
        yield const PpgVitals.invalid(
          signalQuality: PpgSignalQuality.bad,
        );
        continue;
      }

      final peakEstimate = _estimateHeartRateByPeak(
        buffer,
        ticksPerSecond: ticksPerSecond,
      );
      final peaks = peakEstimate.peakTimestamps;
      final peakHeartRate = peakEstimate.heartRateBpm;
      final effectiveSampleFreqHz = _estimateEffectiveSampleFreqHz(
        buffer,
        ticksPerSecond: ticksPerSecond,
      );
      final fftHeartRate = _estimateHeartRateByFft(
        buffer,
        estimatedSampleFreqHz: effectiveSampleFreqHz,
      );

      final peakScore = (peaks.length / 8.0).clamp(0.0, 1.0);
      qualityScore =
          ((0.72 * qualityScore) + (0.28 * peakScore)).clamp(0.0, 1.0);

      double? heartRate;
      if (peakHeartRate != null && fftHeartRate != null) {
        if ((peakHeartRate - fftHeartRate).abs() <= 15.0) {
          heartRate = (peakHeartRate + fftHeartRate) / 2.0;
          qualityScore = min(1.0, qualityScore + 0.12);
        } else {
          heartRate = peakHeartRate;
        }
      } else {
        heartRate = peakHeartRate ?? fftHeartRate;
      }
      if (peakHeartRate != null) {
        qualityScore = min(1.0, qualityScore + 0.05);
      }
      if (fftHeartRate != null) {
        qualityScore = min(1.0, qualityScore + 0.03);
      }

      final ibiTicks = <double>[];
      for (var i = 1; i < peaks.length; i++) {
        final interval = (peaks[i] - peaks[i - 1]).toDouble();
        final intervalSeconds = interval / ticksPerSecond;
        if (interval > 0 &&
            intervalSeconds >= 0.30 &&
            intervalSeconds <= 1.50) {
          ibiTicks.add(interval);
        }
      }
      if (ibiTicks.length >= 2) {
        final robustIbiTicks = _removeIbiOutliers(ibiTicks);
        final meanIbiTicks =
            robustIbiTicks.reduce((a, b) => a + b) / robustIbiTicks.length;
        if (meanIbiTicks.isFinite && meanIbiTicks > 0) {
          final ibiVariation =
              _standardDeviation(robustIbiTicks) / meanIbiTicks;
          if (ibiVariation.isFinite) {
            final rhythmScore = (1.0 - (ibiVariation / 0.55)).clamp(0.0, 1.0);
            qualityScore =
                ((0.78 * qualityScore) + (0.22 * rhythmScore)).clamp(0.0, 1.0);
          }
        }
      }

      final classifiedQuality = _classifyQuality(qualityScore);
      if (classifiedQuality == PpgSignalQuality.bad ||
          classifiedQuality == PpgSignalQuality.unavailable) {
        yield PpgVitals.invalid(
          signalQuality: classifiedQuality,
        );
        continue;
      }

      if (heartRate == null) {
        yield PpgVitals.invalid(
          signalQuality: classifiedQuality,
        );
        continue;
      }
      final smoothedHeartRate = _kalmanUpdateHeartRate(heartRate);

      double? smoothedHrvMs;
      if (ibiTicks.length >= 2) {
        final robustIbiTicks = _removeIbiOutliers(ibiTicks);
        final rmssdTicks = _computeRmssd(robustIbiTicks);
        if (rmssdTicks != null && rmssdTicks.isFinite && rmssdTicks > 0) {
          final hrvMs = rmssdTicks * ticksToMilliseconds;
          if (hrvMs.isFinite && hrvMs >= 5 && hrvMs <= 300) {
            smoothedHrvMs = _smoothHrv(hrvMs);
          }
        }
      }

      yield PpgVitals(
        heartRateBpm: smoothedHeartRate,
        hrvRmssdMs: smoothedHrvMs,
        signalQuality: classifiedQuality,
      );
    }
  }
}

class _MotionAwareSample {
  final int timestamp;
  final double rawGreen;
  final double rawAmbient;
  final double signal;
  final double motionLevel;

  const _MotionAwareSample({
    required this.timestamp,
    required this.rawGreen,
    required this.rawAmbient,
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
