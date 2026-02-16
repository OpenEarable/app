// ignore_for_file: cancel_subscriptions

import 'dart:async';
import 'dart:collection';
import 'dart:math';

import 'package:open_wearable/apps/heart_tracker/model/band_pass_filter.dart';
import 'package:open_wearable/apps/heart_tracker/model/msptd_fast_v2_detector.dart';

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

class PpgMotionSample {
  final int timestamp;
  final double x;
  final double y;
  final double z;

  const PpgMotionSample({
    required this.timestamp,
    required this.x,
    required this.y,
    required this.z,
  });

  double get magnitude => sqrt((x * x) + (y * y) + (z * z));
}

class PpgTemperatureSample {
  final int timestamp;
  final double celsius;

  const PpgTemperatureSample({
    required this.timestamp,
    required this.celsius,
  });
}

class PpgFilter {
  final Stream<PpgOpticalSample> inputStream;
  final Stream<PpgMotionSample>? motionStream;
  final Stream<PpgTemperatureSample>? opticalTemperatureStream;
  final double sampleFreq;
  final int timestampExponent;

  final MsptdFastV2Detector _msptdDetector = const MsptdFastV2Detector();

  double _hrEstimate = 75.0;
  double _hrCovariance = 1.0;
  final double _hrProcessNoise = 0.02;
  final double _hrMeasurementNoise = 5.0;

  double _hrvEstimateMs = 35.0;
  final double _hrvSmoothingAlpha = 0.18;

  StreamSubscription<PpgMotionSample>? _motionSubscription;
  StreamSubscription<PpgTemperatureSample>? _temperatureSubscription;
  Stream<_MotionAwareSample>? _processedStream;
  Stream<(int, double)>? _rawSignalStream;
  Stream<(int, double)>? _displaySignalStream;
  Stream<PpgVitals>? _vitalsStream;

  double? _latestOpticalTemperatureCelsius;
  int? _latestOpticalTemperatureTimestamp;

  static const double _reasonableInEarTemperatureCelsius = 32.0;
  static const double _maxTemperatureSampleAgeSec = 20.0;

  PpgFilter({
    required this.inputStream,
    required this.sampleFreq,
    required this.timestampExponent,
    this.motionStream,
    this.opticalTemperatureStream,
  });

  Stream<(int, double)> get displaySignalStream {
    if (_displaySignalStream != null) {
      return _displaySignalStream!;
    }
    _displaySignalStream = _sampleStream
        .map((sample) => (sample.timestamp, sample.signal))
        .asBroadcastStream();
    return _displaySignalStream!;
  }

  Stream<(int, double)> get rawSignalStream {
    if (_rawSignalStream != null) {
      return _rawSignalStream!;
    }
    _rawSignalStream = _sampleStream
        .map((sample) => (sample.timestamp, sample.rawGreen))
        .asBroadcastStream();
    return _rawSignalStream!;
  }

  Stream<double?> get heartRateStream =>
      _metricsStream.map((vitals) => vitals.heartRateBpm);

  Stream<double?> get hrvStream =>
      _metricsStream.map((vitals) => vitals.hrvRmssdMs);

  Stream<PpgSignalQuality> get signalQualityStream =>
      _metricsStream.map((vitals) => vitals.signalQuality).distinct();

  void dispose() {
    final motionSubscription = _motionSubscription;
    _motionSubscription = null;
    if (motionSubscription != null) {
      unawaited(motionSubscription.cancel());
    }

    final temperatureSubscription = _temperatureSubscription;
    _temperatureSubscription = null;
    if (temperatureSubscription != null) {
      unawaited(temperatureSubscription.cancel());
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
    final imuCanceler = _MultiReferenceMotionCanceler();
    final bandPassFilter = BandPassFilter(
      sampleFreq: sampleFreq,
      lowCut: 0.7,
      highCut: 4.0,
    );
    final normalizer = _BoundedSignalNormalizer();

    if (motionStream != null) {
      _motionSubscription = motionStream!.listen((event) {
        motionSuppressor.updateMotionMagnitude(event.magnitude);
        imuCanceler.updateMotion(event);
      });
    }
    if (opticalTemperatureStream != null) {
      _temperatureSubscription = opticalTemperatureStream!.listen((sample) {
        _latestOpticalTemperatureCelsius = sample.celsius;
        _latestOpticalTemperatureTimestamp = sample.timestamp;
      });
    }

    return inputStream.map((sample) {
      final ambientCanceled = ambientCanceler.filter(
        green: sample.green,
        ambient: sample.ambient,
      );
      final imuCleaned = imuCanceler.filter(
        ambientCanceled,
        motionLevel: motionSuppressor.motionLevel,
      );
      final motionSuppressed = motionSuppressor.filter(imuCleaned);
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

  ({double? heartRateBpm, List<int> peakTimestamps}) _estimateHeartRateByPeak(
    List<_MotionAwareSample> samples, {
    required double ticksPerSecond,
    required double estimatedSampleFreqHz,
  }) {
    if (samples.length < 8) {
      return (heartRateBpm: null, peakTimestamps: const []);
    }

    // Match MSPTDfast-v2 usage: run beat detection on the raw PPG waveform
    // (lightly centered only) and let the detector handle detrending/scales.
    final signal =
        samples.map((sample) => sample.rawGreen).toList(growable: false);
    final mean = signal.reduce((a, b) => a + b) / signal.length;
    final centered =
        signal.map((value) => value - mean).toList(growable: false);
    final msptdIndices = _msptdDetector.detectPeakIndices(
      centered,
      sampleFreqHz: estimatedSampleFreqHz,
    );

    final peaks = msptdIndices
        .where((index) => index >= 0 && index < samples.length)
        .map((index) => samples[index].timestamp)
        .toList(growable: false);

    return _estimateHeartRateFromPeakTimestamps(
      peaks,
      ticksPerSecond: ticksPerSecond,
    );
  }

  ({double? heartRateBpm, List<int> peakTimestamps})
      _estimateHeartRateFromPeakTimestamps(
    List<int> peaks, {
    required double ticksPerSecond,
  }) {
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

  ({double score, double averageMotion}) _estimateRecentWaveformQualityScore(
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
      return (score: 0.0, averageMotion: 0.0);
    }

    // Score waveform quality from the filtered signal that is displayed.
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
    // Filtered signal is normalized/bounded, so fixed thresholds are stable.
    final rangeScore = ((rangeFiltered - 0.08) / 0.95).clamp(0.0, 1.0);
    final stdScore = ((stdFiltered - 0.025) / 0.30).clamp(0.0, 1.0);
    final motionScore = (1.0 - (averageMotion / 2.2)).clamp(0.0, 1.0);

    var score = ((0.45 * rangeScore) + (0.35 * stdScore) + (0.20 * motionScore))
        .clamp(0.0, 1.0);

    // Make accelerometer motion a strong quality prior:
    // heavy movement should almost always mark PPG quality as bad.
    if (averageMotion >= 1.45) {
      score = min(score, 0.10);
    } else if (averageMotion >= 1.12) {
      score = min(score, 0.24);
    } else if (averageMotion >= 0.88) {
      score = min(score, 0.45);
    }

    return (
      score: score,
      averageMotion: averageMotion,
    );
  }

  ({bool hasFreshTemperatureSample, bool inEarByTemperature})
      _estimateInEarByOpticalTemperature({
    required int latestTimestamp,
    required double ticksPerSecond,
  }) {
    if (opticalTemperatureStream == null) {
      return (hasFreshTemperatureSample: false, inEarByTemperature: true);
    }

    final latestTemperature = _latestOpticalTemperatureCelsius;
    final latestTemperatureTimestamp = _latestOpticalTemperatureTimestamp;
    if (latestTemperature == null || latestTemperatureTimestamp == null) {
      return (hasFreshTemperatureSample: false, inEarByTemperature: false);
    }

    final maxAgeTicks = _maxTemperatureSampleAgeSec * ticksPerSecond;
    if (latestTimestamp - latestTemperatureTimestamp > maxAgeTicks) {
      return (hasFreshTemperatureSample: false, inEarByTemperature: false);
    }

    return (
      hasFreshTemperatureSample: true,
      inEarByTemperature:
          latestTemperature >= _reasonableInEarTemperatureCelsius,
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
      final recentQuality = _estimateRecentWaveformQualityScore(
        buffer,
        latestTimestamp: sample.timestamp,
        ticksPerSecond: ticksPerSecond,
      );
      var qualityScore = recentQuality.score;
      final recentMotion = recentQuality.averageMotion;

      if (recentMotion >= 1.45) {
        yield const PpgVitals.invalid(
          signalQuality: PpgSignalQuality.bad,
        );
        continue;
      }

      final inEarTemperature = _estimateInEarByOpticalTemperature(
        latestTimestamp: sample.timestamp,
        ticksPerSecond: ticksPerSecond,
      );
      if (opticalTemperatureStream != null) {
        if (!inEarTemperature.hasFreshTemperatureSample) {
          yield const PpgVitals.invalid(
            signalQuality: PpgSignalQuality.unavailable,
          );
          continue;
        }
        if (!inEarTemperature.inEarByTemperature) {
          yield const PpgVitals.invalid(
            signalQuality: PpgSignalQuality.bad,
          );
          continue;
        }
      }

      final effectiveSampleFreqHz = _estimateEffectiveSampleFreqHz(
        buffer,
        ticksPerSecond: ticksPerSecond,
      );
      final peakEstimate = _estimateHeartRateByPeak(
        buffer,
        ticksPerSecond: ticksPerSecond,
        estimatedSampleFreqHz: effectiveSampleFreqHz,
      );
      final peaks = peakEstimate.peakTimestamps;
      final peakHeartRate = peakEstimate.heartRateBpm;

      final peakScore = (peaks.length / 8.0).clamp(0.0, 1.0);
      qualityScore =
          ((0.78 * qualityScore) + (0.22 * peakScore)).clamp(0.0, 1.0);

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

      if (peakHeartRate == null) {
        yield PpgVitals.invalid(
          signalQuality: classifiedQuality,
        );
        continue;
      }
      final smoothedHeartRate = _kalmanUpdateHeartRate(peakHeartRate);

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

class _MultiReferenceMotionCanceler {
  final _PadasipStyleMultiInputNlmsCanceler _canceler =
      _PadasipStyleMultiInputNlmsCanceler(
    tapsPerAxis: 8,
  );

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

  void updateMotion(PpgMotionSample sample) {
    if (!_isInitialized) {
      _isInitialized = true;
      _gravityX = sample.x;
      _gravityY = sample.y;
      _gravityZ = sample.z;
      _dynamicX = 0;
      _dynamicY = 0;
      _dynamicZ = 0;
      _referenceScaleX = 0.2;
      _referenceScaleY = 0.2;
      _referenceScaleZ = 0.2;
      return;
    }

    const gravityAlpha = 0.04;
    const dynamicAlpha = 0.18;
    const scaleAlpha = 0.06;

    _gravityX = (_gravityX * (1.0 - gravityAlpha)) + (sample.x * gravityAlpha);
    _gravityY = (_gravityY * (1.0 - gravityAlpha)) + (sample.y * gravityAlpha);
    _gravityZ = (_gravityZ * (1.0 - gravityAlpha)) + (sample.z * gravityAlpha);

    final hpX = sample.x - _gravityX;
    final hpY = sample.y - _gravityY;
    final hpZ = sample.z - _gravityZ;
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
  static const double _baseMu = 0.08;
  static const double _maxMu = 1.0;
  static const double _epsilon = 1e-6;
  static const double _leakage = 0.00025;

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

    final smoothAlpha = motionLevel > 1.0 ? 0.22 : 0.11;
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
