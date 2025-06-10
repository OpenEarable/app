import 'dart:math';

class HighPassFilter {
  final double cutoffFreq;
  final double sampleFreq;

  late final double alpha;
  double? _lastInput;
  double? _lastOutput;

  HighPassFilter({
    required this.cutoffFreq,
    required this.sampleFreq,
  }) {
    final dt = 1.0 / sampleFreq;
    final rc = 1.0 / (2 * pi * cutoffFreq);
    alpha = rc / (rc + dt);
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
