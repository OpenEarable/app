import 'dart:math';

import 'package:logger/logger.dart';
import 'package:open_wearable/apps/heart_tracker/model/band_pass_filter.dart';

Logger _logger = Logger();

class PpgFilter {
  final Stream<(int, double)> inputStream;
  final double sampleFreq;

  final double _minProminence = 0.1;
  final int _minPeakDistanceMs = 300; // e.g., 200 BPM max

  double _hrEstimate = 75.0;
  double _p = 1.0;
  final double _q = 0.01;  // process noise
  final double _r = 4.0;
  
  int timestampExponent;   // measurement noise

  Stream<(int, double)>? _filteredStream;

  PpgFilter({
    required this.inputStream,
    required this.sampleFreq,
    required this.timestampExponent,
  });

  Stream<(int, double)> get filteredStream {
    final filter = BandPassFilter(
      sampleFreq: sampleFreq,
      lowCut: 0.5,
      highCut: 4,
    );
    
    if (_filteredStream == null) {
      _logger.d("Creating filtered stream");
      _filteredStream = inputStream.map((event) {
        final (timestamp, rawValue) = event;
        final filteredValue = filter.filter(rawValue);
        return (timestamp, filteredValue);
      }).asBroadcastStream();
    } else {
      _logger.d("Using existing filtered stream");
    }

    return _filteredStream!;
  }

  double _kalmanUpdate(double measurement) {
    if (measurement.isNaN || measurement.isInfinite) return _hrEstimate;

    _p += _q;
    final k = _p / (_p + _r);
    _hrEstimate += k * (measurement - _hrEstimate);
    _p *= (1 - k);
    return _hrEstimate;
  }

  List<(int, double)> smoothBuffer(List<(int, double)> raw, {int radius = 2}) {
    final smoothed = <(int, double)>[];
    for (int i = 0; i < raw.length; i++) {
      int start = max(0, i - radius);
      int end = min(raw.length - 1, i + radius);
      final avg = raw.sublist(start, end + 1).map((e) => e.$2).reduce((a, b) => a + b) / (end - start + 1);
      smoothed.add((raw[i].$1, avg));
    }
    return smoothed;
  }

  List<int> detectPeaks(List<(int, double)> buffer) {
    buffer = smoothBuffer(buffer, radius: 4);
    final peakTimestamps = <int>[];

    for (int i = 1; i < buffer.length - 1; i++) {
      final (tPrev, vPrev) = buffer[i - 1];
      final (tCurr, vCurr) = buffer[i];
      final (tNext, vNext) = buffer[i + 1];

      // Skip too-close peaks
      final lastPeak = peakTimestamps.isNotEmpty ? peakTimestamps.last : 0;
      if (tCurr - lastPeak < _minPeakDistanceMs) continue;

      // Simple 3-point peak
      if (vCurr > vPrev && vCurr > vNext &&
          (vCurr - vPrev) > _minProminence &&
          (vCurr - vNext) > _minProminence) {
        peakTimestamps.add(tCurr);
      }
    }

    return peakTimestamps;
  }

  Stream<double> get heartRateStream async* {
    int timestampFactor = pow(10, -timestampExponent).toInt();
    int windowDurationMs = 8 * timestampFactor; // 8 seconds
    final List<(int, double)> buffer = [];

    await for (final (timestamp, value) in filteredStream) {
      buffer.add((timestamp, value));

      buffer.removeWhere((event) => event.$1 < timestamp - windowDurationMs);

      if ((buffer.last.$1 - buffer.first.$1) < windowDurationMs / 2) {
        _logger.d("waiting to fill buffer, time difference: ${buffer.last.$1 - buffer.first.$1}");
        continue;
      }

      List<int> peakTimestamps = detectPeaks(buffer);

      // Need at least 2 peaks to compute HR
      if (peakTimestamps.length < 2) {
        _logger.w("not enough peaks ${peakTimestamps.length}, in buffer of size ${buffer.length}");
        continue;
      }

      final ibiList = <double>[];
      for (int i = 1; i < peakTimestamps.length; i++) {
        final ibi = (peakTimestamps[i] - peakTimestamps[i - 1]).toDouble();
        ibiList.add(ibi);
      }

      final avgIbi = ibiList.reduce((a, b) => a + b) / ibiList.length;
      if (avgIbi <= 0 || avgIbi.isNaN || avgIbi.isInfinite) {
        _logger.w("unexpected avgIbi: $avgIbi");
        continue;
      }

      final hr = 60 * timestampFactor / avgIbi;
      final smoothedHr = _kalmanUpdate(hr);

      if (smoothedHr > 30 && smoothedHr < 220) {
        yield smoothedHr;
      }

      // Optional: clear buffer for independent windows
      buffer.clear();
    }
  }
}
