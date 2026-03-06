import 'dart:async';
import 'dart:collection';
import 'dart:math';

import 'package:open_wearable/apps/heart_tracker/model/ppg_filter.dart';

class OpenRingClassicHeartProcessor {
  final Stream<PpgOpticalSample> inputStream;
  final double sampleFreq;

  Stream<_OpenRingSampleOutput>? _outputStream;
  Stream<(int, double)>? _displaySignalStream;
  Stream<double?>? _heartRateStream;
  Stream<double?>? _hrvStream;
  Stream<PpgSignalQuality>? _signalQualityStream;

  OpenRingClassicHeartProcessor({
    required this.inputStream,
    required this.sampleFreq,
  });

  Stream<(int, double)> get displaySignalStream {
    if (_displaySignalStream != null) {
      return _displaySignalStream!;
    }
    _displaySignalStream = _sampleStream
        .map((sample) => (sample.timestamp, sample.filteredSignal))
        .asBroadcastStream();
    return _displaySignalStream!;
  }

  Stream<double?> get heartRateStream {
    if (_heartRateStream != null) {
      return _heartRateStream!;
    }
    _heartRateStream =
        _sampleStream.map((sample) => sample.heartRateBpm).distinct();
    return _heartRateStream!;
  }

  Stream<double?> get hrvStream {
    if (_hrvStream != null) {
      return _hrvStream!;
    }
    _hrvStream = _sampleStream.map((sample) => sample.hrvRmssdMs).distinct();
    return _hrvStream!;
  }

  Stream<PpgSignalQuality> get signalQualityStream {
    if (_signalQualityStream != null) {
      return _signalQualityStream!;
    }
    _signalQualityStream =
        _sampleStream.map((sample) => sample.signalQuality).distinct();
    return _signalQualityStream!;
  }

  void dispose() {}

  Stream<_OpenRingSampleOutput> get _sampleStream {
    if (_outputStream != null) {
      return _outputStream!;
    }
    _outputStream = _createOutputStream().asBroadcastStream();
    return _outputStream!;
  }

  Stream<_OpenRingSampleOutput> _createOutputStream() async* {
    final safeSampleFreq =
        sampleFreq.isFinite && sampleFreq > 0 ? sampleFreq : 50.0;
    final hrWindowSize = max(12, (safeSampleFreq * 5).round());
    final hrUpdateIntervalSamples = max(1, safeSampleFreq.round());
    final historyLength = 5;

    final selectedSignalBuffer = ListQueue<double>();
    final qualitySignalBuffer = ListQueue<double>();
    final hrHistory = ListQueue<double>();

    var samplesSinceLastHrUpdate = 0;
    double? currentHeartRate;
    double? currentHrv;
    var currentQuality = PpgSignalQuality.unavailable;

    await for (final sample in inputStream) {
      final selectedSignal = _selectHeartSignal(sample);
      final qualitySignal = _selectQualitySignal(sample);

      _pushLimited(selectedSignalBuffer, selectedSignal, hrWindowSize);
      _pushLimited(qualitySignalBuffer, qualitySignal, hrWindowSize);

      final selectedList = selectedSignalBuffer.toList(growable: false);
      final filteredSignal = _applyPhysiologicalFilter(
        selectedList,
        sampleFreqHz: safeSampleFreq,
      );
      final filteredValue =
          filteredSignal.isNotEmpty ? filteredSignal.last : selectedSignal;

      currentQuality = _estimateSignalQuality(qualitySignalBuffer);
      samplesSinceLastHrUpdate += 1;
      if (samplesSinceLastHrUpdate >= hrUpdateIntervalSamples) {
        samplesSinceLastHrUpdate = 0;

        if (currentQuality == PpgSignalQuality.bad ||
            currentQuality == PpgSignalQuality.unavailable) {
          currentHeartRate = null;
          currentHrv = null;
        } else {
          final estimate = _estimateHeartRateAndHrv(
            filteredSignal,
            sampleRateHz: safeSampleFreq,
          );
          final estimatedHeartRate = estimate.heartRateBpm;
          if (estimatedHeartRate != null) {
            _pushLimited(hrHistory, estimatedHeartRate, historyLength);
            currentHeartRate = _weightedAverage(hrHistory);
          } else {
            currentHeartRate = null;
          }
          currentHrv = estimate.hrvRmssdMs;
        }
      }

      yield _OpenRingSampleOutput(
        timestamp: sample.timestamp,
        filteredSignal: filteredValue,
        heartRateBpm: currentHeartRate,
        hrvRmssdMs: currentHrv,
        signalQuality: currentQuality,
      );
    }
  }

  void _pushLimited(ListQueue<double> queue, double value, int maxSize) {
    queue.addLast(value);
    while (queue.length > maxSize) {
      queue.removeFirst();
    }
  }

  double _weightedAverage(ListQueue<double> values) {
    if (values.isEmpty) {
      return 0;
    }
    var weightedSum = 0.0;
    var totalWeight = 0;
    for (var i = 0; i < values.length; i++) {
      final weight = i + 1;
      weightedSum += values.elementAt(i) * weight;
      totalWeight += weight;
    }
    return weightedSum / max(1, totalWeight);
  }

  double _selectHeartSignal(PpgOpticalSample sample) {
    // Match OpenRing classical inference path: HR is derived from IR.
    if (sample.ir.isFinite && sample.ir.abs() > 1e-6) {
      return sample.ir;
    }
    // Defensive fallback only when IR is missing.
    if (sample.red.isFinite) {
      return sample.red;
    }
    if (sample.green.isFinite) {
      return sample.green;
    }
    return 0;
  }

  double _selectQualitySignal(PpgOpticalSample sample) {
    if (sample.green.isFinite) {
      return sample.green;
    }
    return 0;
  }

  List<double> _applyPhysiologicalFilter(
    List<double> signal, {
    required double sampleFreqHz,
  }) {
    if (signal.isEmpty) {
      return const [];
    }

    final lowPassWindow = max(3, (sampleFreqHz * 0.5).round());
    final trendWindow = max(lowPassWindow + 2, (sampleFreqHz * 2.0).round());
    final lowPassed = _centeredMovingAverage(signal, lowPassWindow);
    final trend = _centeredMovingAverage(lowPassed, trendWindow);

    return List<double>.generate(
      signal.length,
      (index) => lowPassed[index] - trend[index],
      growable: false,
    );
  }

  List<double> _centeredMovingAverage(
    List<double> signal,
    int windowSize,
  ) {
    if (signal.isEmpty || windowSize <= 1) {
      return List<double>.from(signal);
    }
    final output = List<double>.filled(signal.length, 0, growable: false);
    final half = windowSize ~/ 2;
    for (var i = 0; i < signal.length; i++) {
      final start = max(0, i - half);
      final end = min(signal.length, i + half + 1);
      var sum = 0.0;
      for (var j = start; j < end; j++) {
        sum += signal[j];
      }
      output[i] = sum / max(1, end - start);
    }
    return output;
  }

  ({
    double? heartRateBpm,
    double? hrvRmssdMs,
  }) _estimateHeartRateAndHrv(
    List<double> filteredSignal, {
    required double sampleRateHz,
  }) {
    if (filteredSignal.length < 8 ||
        sampleRateHz <= 0 ||
        !sampleRateHz.isFinite) {
      return (heartRateBpm: null, hrvRmssdMs: null);
    }

    final peaks = _detectPeaks(
      filteredSignal,
      thresholdRatio: 0.0,
      sampleRateHz: sampleRateHz,
      minIntervalSec: 0.4,
    );
    if (peaks.length < 2) {
      return (heartRateBpm: null, hrvRmssdMs: null);
    }

    final intervalsSec = <double>[];
    for (var i = 1; i < peaks.length; i++) {
      final intervalSec = (peaks[i] - peaks[i - 1]) / sampleRateHz;
      if (intervalSec >= 0.3 && intervalSec <= 1.5) {
        intervalsSec.add(intervalSec);
      }
    }
    if (intervalsSec.isEmpty) {
      return (heartRateBpm: null, hrvRmssdMs: null);
    }

    intervalsSec.sort();
    final medianInterval = intervalsSec[intervalsSec.length ~/ 2];
    final heartRate = 60.0 / medianInterval;
    if (!heartRate.isFinite || heartRate < 40 || heartRate > 200) {
      return (heartRateBpm: null, hrvRmssdMs: null);
    }

    double? rmssdMs;
    if (intervalsSec.length >= 2) {
      var sumSquared = 0.0;
      var count = 0;
      for (var i = 1; i < intervalsSec.length; i++) {
        final delta = intervalsSec[i] - intervalsSec[i - 1];
        sumSquared += delta * delta;
        count += 1;
      }
      if (count > 0) {
        final rmssdSec = sqrt(sumSquared / count);
        final value = rmssdSec * 1000.0;
        if (value.isFinite && value >= 5 && value <= 300) {
          rmssdMs = value;
        }
      }
    }

    return (
      heartRateBpm: heartRate,
      hrvRmssdMs: rmssdMs,
    );
  }

  List<int> _detectPeaks(
    List<double> signal, {
    required double thresholdRatio,
    required double sampleRateHz,
    required double minIntervalSec,
  }) {
    final peaks = <int>[];
    if (signal.length < 3) {
      return peaks;
    }

    var minValue = double.infinity;
    var maxValue = double.negativeInfinity;
    var mean = 0.0;
    for (final value in signal) {
      if (value < minValue) minValue = value;
      if (value > maxValue) maxValue = value;
      mean += value;
    }
    mean /= signal.length;

    final dynamicThreshold = mean + ((maxValue - mean) * thresholdRatio);
    final minDistanceSamples = minIntervalSec > 0
        ? max(1, (minIntervalSec * sampleRateHz).round())
        : 0;

    var lastPeakIndex = -minDistanceSamples;
    var i = 0;
    while (i < signal.length) {
      if (signal[i] >= dynamicThreshold) {
        var regionMaxIndex = i;
        var regionMaxValue = signal[i];
        var j = i + 1;
        while (j < signal.length && signal[j] >= dynamicThreshold) {
          if (signal[j] > regionMaxValue) {
            regionMaxValue = signal[j];
            regionMaxIndex = j;
          }
          j += 1;
        }

        if (minDistanceSamples <= 0 ||
            peaks.isEmpty ||
            (regionMaxIndex - lastPeakIndex) >= minDistanceSamples) {
          peaks.add(regionMaxIndex);
          lastPeakIndex = regionMaxIndex;
        }
        i = j;
        continue;
      }
      i += 1;
    }

    return peaks;
  }

  PpgSignalQuality _estimateSignalQuality(ListQueue<double> samples) {
    if (samples.isEmpty) {
      return PpgSignalQuality.unavailable;
    }

    var minValue = double.infinity;
    var maxValue = double.negativeInfinity;
    var sum = 0.0;
    for (final value in samples) {
      if (value < minValue) minValue = value;
      if (value > maxValue) maxValue = value;
      sum += value;
    }
    final mean = sum / samples.length;
    final range = maxValue - minValue;

    if (!mean.isFinite || !range.isFinite || range <= 1e-6) {
      return PpgSignalQuality.unavailable;
    }

    // Mirrors OpenRing's threshold-style quality gating:
    // quality from signal mean + dynamic range.
    if (mean > 1000 && range > 500) {
      if (range > 2000) {
        return PpgSignalQuality.good;
      }
      if (range > 1500) {
        return PpgSignalQuality.good;
      }
      if (range > 1000) {
        return PpgSignalQuality.fair;
      }
      return PpgSignalQuality.bad;
    }

    return PpgSignalQuality.bad;
  }
}

class _OpenRingSampleOutput {
  final int timestamp;
  final double filteredSignal;
  final double? heartRateBpm;
  final double? hrvRmssdMs;
  final PpgSignalQuality signalQuality;

  const _OpenRingSampleOutput({
    required this.timestamp,
    required this.filteredSignal,
    required this.heartRateBpm,
    required this.hrvRmssdMs,
    required this.signalQuality,
  });
}
