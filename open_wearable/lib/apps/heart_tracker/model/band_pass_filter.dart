import 'dart:math';

class BandPassFilter {
  final double sampleFreq;
  final double lowCut;
  final double highCut;

  late final double a0, a1, a2, b1, b2;
  double x1 = 0, x2 = 0;
  double y1 = 0, y2 = 0;
  bool _isInitialized = false;

  BandPassFilter({
    required this.sampleFreq,
    required this.lowCut,
    required this.highCut,
  }) {
    final safeSampleFreq =
        sampleFreq.isFinite && sampleFreq > 0 ? sampleFreq : 50.0;
    final nyquist = safeSampleFreq / 2.0;

    var safeLow = lowCut;
    if (!safeLow.isFinite || safeLow <= 0) {
      safeLow = 0.45;
    }

    var safeHigh = highCut;
    if (!safeHigh.isFinite || safeHigh <= safeLow) {
      safeHigh = safeLow + 0.6;
    }
    safeHigh = min(safeHigh, nyquist - 0.05);
    safeLow = min(safeLow, safeHigh - 0.15);
    safeLow = max(0.05, safeLow);

    final centerFreq = sqrt(safeLow * safeHigh);
    final bandwidth = max(0.15, safeHigh - safeLow);
    final q = centerFreq / bandwidth;

    final omega = 2 * pi * centerFreq / safeSampleFreq;
    final alpha = sin(omega) / (2 * q);

    final cosOmega = cos(omega);
    final norm = 1 + alpha;

    a0 = alpha / norm;
    a1 = 0;
    a2 = -alpha / norm;
    b1 = -2 * cosOmega / norm;
    b2 = (1 - alpha) / norm;
  }

  double filter(double x) {
    if (!_isInitialized) {
      _isInitialized = true;
      x1 = x;
      x2 = x;
      y1 = 0;
      y2 = 0;
      return 0;
    }

    final y = a0 * x + a1 * x1 + a2 * x2 - b1 * y1 - b2 * y2;
    x2 = x1;
    x1 = x;
    y2 = y1;
    y1 = y;
    return y;
  }
}
