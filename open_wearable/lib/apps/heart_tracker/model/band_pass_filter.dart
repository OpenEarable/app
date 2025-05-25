import 'dart:math';

class BandPassFilter {
  final double sampleFreq;
  final double lowCut;
  final double highCut;

  late final double a0, a1, a2, b1, b2;
  double x1 = 0, x2 = 0;
  double y1 = 0, y2 = 0;

  BandPassFilter({
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

  double filter(double x) {
    final y = a0 * x + a1 * x1 + a2 * x2 - b1 * y1 - b2 * y2;
    x2 = x1;
    x1 = x;
    y2 = y1;
    y1 = y;
    return y;
  }
}
