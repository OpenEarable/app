import 'dart:math';
import 'dart:typed_data';

/// Adapted from `msptdfastv2_beat_detector.m` in:
/// https://github.com/peterhcharlton/ppg-beats (MIT-licensed file).
///
/// The original implementation is MATLAB; this is a Dart adaptation for
/// real-time windowed use in the app.
class MsptdFastV2Detector {
  const MsptdFastV2Detector();

  static const double _minPlausibleHeartRateBpm = 30.0;
  static const double _targetDownsampleHz = 20.0;

  List<int> detectPeakIndices(
    List<double> samples, {
    required double sampleFreqHz,
  }) {
    if (samples.length < 8 || !sampleFreqHz.isFinite || sampleFreqHz <= 0) {
      return const [];
    }

    final prepared = _prepareSignal(
      samples,
      sampleFreqHz: sampleFreqHz,
    );
    final detrended = _detrend(prepared.samples);
    final candidatePeaks = _detectPeakCandidates(
      detrended,
      sampleFreqHz: prepared.sampleFreqHz,
    );
    if (candidatePeaks.isEmpty) {
      return const [];
    }

    final refinedPeaks = _refineInOriginalSignal(
      candidates: candidatePeaks,
      originalSignal: samples,
      originalSampleFreqHz: sampleFreqHz,
      workingSampleFreqHz: prepared.sampleFreqHz,
      downsampleFactor: prepared.downsampleFactor,
    );

    final minDistanceSamples = max(1, (0.28 * sampleFreqHz).round());
    return _enforceMinimumDistance(
      refinedPeaks,
      minDistanceSamples: minDistanceSamples,
    );
  }

  _PreparedSignal _prepareSignal(
    List<double> samples, {
    required double sampleFreqHz,
  }) {
    var downsampleFactor = 1;
    if (sampleFreqHz > _targetDownsampleHz) {
      downsampleFactor = max(1, (sampleFreqHz / _targetDownsampleHz).floor());
    }

    if (downsampleFactor <= 1) {
      return _PreparedSignal(
        samples: samples,
        sampleFreqHz: sampleFreqHz,
        downsampleFactor: 1,
      );
    }

    final downsampled = <double>[];
    for (var i = 0; i < samples.length; i += downsampleFactor) {
      downsampled.add(samples[i]);
    }

    return _PreparedSignal(
      samples: downsampled,
      sampleFreqHz: sampleFreqHz / downsampleFactor,
      downsampleFactor: downsampleFactor,
    );
  }

  List<double> _detrend(List<double> signal) {
    final n = signal.length;
    if (n < 2) {
      return signal;
    }

    final sumX = (n - 1) * n / 2.0;
    final sumX2 = (n - 1) * n * ((2 * n) - 1) / 6.0;
    var sumY = 0.0;
    var sumXY = 0.0;
    for (var i = 0; i < n; i++) {
      final y = signal[i];
      sumY += y;
      sumXY += i * y;
    }

    final denominator = (n * sumX2) - (sumX * sumX);
    final slope = denominator.abs() < 1e-9
        ? 0.0
        : ((n * sumXY) - (sumX * sumY)) / denominator;
    final intercept = (sumY - (slope * sumX)) / n;

    return List<double>.generate(
      n,
      (i) => signal[i] - (intercept + (slope * i)),
      growable: false,
    );
  }

  List<int> _detectPeakCandidates(
    List<double> signal, {
    required double sampleFreqHz,
  }) {
    final n = signal.length;
    if (n < 5 || !sampleFreqHz.isFinite || sampleFreqHz <= 0) {
      return const [];
    }

    final halfLength = (n / 2).ceil() - 1;
    if (halfLength < 1) {
      return const [];
    }

    final maxScale = _reduceScalesForPlausibleHeartRates(
      halfLength: halfLength,
      signalLength: n,
      sampleFreqHz: sampleFreqHz,
    );

    final mMax = List<Uint8List>.generate(
      maxScale,
      (_) => Uint8List(n),
      growable: false,
    );

    for (var k = 1; k <= maxScale; k++) {
      final row = mMax[k - 1];
      for (var i = k; i < n - k; i++) {
        if (signal[i] > signal[i - k] && signal[i] > signal[i + k]) {
          row[i] = 1;
        }
      }
    }

    var lambdaRow = 0;
    var bestRowSum = -1;
    for (var rowIndex = 0; rowIndex < mMax.length; rowIndex++) {
      var rowSum = 0;
      final row = mMax[rowIndex];
      for (var i = 0; i < row.length; i++) {
        rowSum += row[i];
      }
      if (rowSum > bestRowSum) {
        bestRowSum = rowSum;
        lambdaRow = rowIndex;
      }
    }

    final peaks = <int>[];
    for (var col = 0; col < n; col++) {
      var isPeak = true;
      for (var row = 0; row <= lambdaRow; row++) {
        if (mMax[row][col] == 0) {
          isPeak = false;
          break;
        }
      }
      if (isPeak) {
        peaks.add(col);
      }
    }
    return peaks;
  }

  int _reduceScalesForPlausibleHeartRates({
    required int halfLength,
    required int signalLength,
    required double sampleFreqHz,
  }) {
    final durationSeconds = signalLength / sampleFreqHz;
    if (!durationSeconds.isFinite || durationSeconds <= 0) {
      return halfLength;
    }
    final minPlausibleHz = _minPlausibleHeartRateBpm / 60.0;

    var reducedMaxScale = 1;
    for (var k = 1; k <= halfLength; k++) {
      final scaleFrequencyHz = (halfLength / k) / durationSeconds;
      if (scaleFrequencyHz >= minPlausibleHz) {
        reducedMaxScale = k;
      }
    }

    return reducedMaxScale.clamp(1, halfLength);
  }

  List<int> _refineInOriginalSignal({
    required List<int> candidates,
    required List<double> originalSignal,
    required double originalSampleFreqHz,
    required double workingSampleFreqHz,
    required int downsampleFactor,
  }) {
    if (candidates.isEmpty || originalSignal.isEmpty) {
      return const [];
    }

    final toleranceSeconds = workingSampleFreqHz < 10
        ? 0.2
        : (workingSampleFreqHz < 20 ? 0.1 : 0.05);
    final toleranceSamples = max(1, (originalSampleFreqHz * toleranceSeconds).round());
    final refined = <int>[];

    for (final candidate in candidates) {
      final approxIndex = candidate * downsampleFactor;
      if (approxIndex < 0 || approxIndex >= originalSignal.length) {
        continue;
      }

      final start = max(0, approxIndex - toleranceSamples);
      final end = min(originalSignal.length - 1, approxIndex + toleranceSamples);
      var maxIndex = start;
      var maxValue = originalSignal[start];
      for (var i = start + 1; i <= end; i++) {
        final value = originalSignal[i];
        if (value > maxValue) {
          maxValue = value;
          maxIndex = i;
        }
      }
      refined.add(maxIndex);
    }

    refined.sort();
    return refined;
  }

  List<int> _enforceMinimumDistance(
    List<int> peaks, {
    required int minDistanceSamples,
  }) {
    if (peaks.isEmpty) {
      return const [];
    }

    final deduped = <int>[peaks.first];
    for (var i = 1; i < peaks.length; i++) {
      if (peaks[i] - deduped.last >= minDistanceSamples) {
        deduped.add(peaks[i]);
      }
    }
    return deduped;
  }
}

class _PreparedSignal {
  final List<double> samples;
  final double sampleFreqHz;
  final int downsampleFactor;

  const _PreparedSignal({
    required this.samples,
    required this.sampleFreqHz,
    required this.downsampleFactor,
  });
}
