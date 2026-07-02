part of '../sensor_chart.dart';

enum _ButterworthFilterType { lowPass, highPass }

abstract class _IirFilterStage {
  double apply(double input, double dt);

  void reset();
}

class _ButterworthFirstOrderStage implements _IirFilterStage {
  final _ButterworthFilterType type;
  final double cutoffHz;

  double _x1 = 0;
  double _y1 = 0;
  bool _primed = false;

  _ButterworthFirstOrderStage({
    required this.type,
    required this.cutoffHz,
  });

  @override
  double apply(double input, double dt) {
    if (!_primed || dt <= 0 || !dt.isFinite) {
      return _prime(input);
    }

    final coefficients = _firstOrderCoefficients(
      type: type,
      cutoffHz: cutoffHz,
      dt: dt,
    );
    final output =
        coefficients.b0 * input + coefficients.b1 * _x1 - coefficients.a1 * _y1;
    _x1 = input;
    _y1 = output;
    return output;
  }

  @override
  void reset() {
    _x1 = 0;
    _y1 = 0;
    _primed = false;
  }

  double _prime(double input) {
    _x1 = input;
    _y1 = type == _ButterworthFilterType.lowPass ? input : 0;
    _primed = true;
    return _y1;
  }
}

class _ButterworthBiquadStage implements _IirFilterStage {
  final _ButterworthFilterType type;
  final double cutoffHz;
  final double q;

  double _x1 = 0;
  double _x2 = 0;
  double _y1 = 0;
  double _y2 = 0;
  bool _primed = false;

  _ButterworthBiquadStage({
    required this.type,
    required this.cutoffHz,
    required this.q,
  });

  @override
  double apply(double input, double dt) {
    if (!_primed || dt <= 0 || !dt.isFinite) {
      return _prime(input);
    }

    final coefficients = _biquadCoefficients(
      type: type,
      cutoffHz: cutoffHz,
      q: q,
      dt: dt,
    );
    final output = coefficients.b0 * input +
        coefficients.b1 * _x1 +
        coefficients.b2 * _x2 -
        coefficients.a1 * _y1 -
        coefficients.a2 * _y2;
    _x2 = _x1;
    _x1 = input;
    _y2 = _y1;
    _y1 = output;
    return output;
  }

  @override
  void reset() {
    _x1 = 0;
    _x2 = 0;
    _y1 = 0;
    _y2 = 0;
    _primed = false;
  }

  double _prime(double input) {
    final output = type == _ButterworthFilterType.lowPass ? input : 0.0;
    _x1 = input;
    _x2 = input;
    _y1 = output;
    _y2 = output;
    _primed = true;
    return output;
  }
}

class _NotchBiquadStage implements _IirFilterStage {
  final double centerHz;
  final double widthHz;

  double _x1 = 0;
  double _x2 = 0;
  double _y1 = 0;
  double _y2 = 0;
  bool _primed = false;

  _NotchBiquadStage({
    required this.centerHz,
    required this.widthHz,
  });

  @override
  double apply(double input, double dt) {
    if (!_primed || dt <= 0 || !dt.isFinite) {
      return _prime(input);
    }

    final coefficients = _notchCoefficients(
      centerHz: centerHz,
      widthHz: widthHz,
      dt: dt,
    );
    final output = coefficients.b0 * input +
        coefficients.b1 * _x1 +
        coefficients.b2 * _x2 -
        coefficients.a1 * _y1 -
        coefficients.a2 * _y2;
    _x2 = _x1;
    _x1 = input;
    _y2 = _y1;
    _y1 = output;
    return output;
  }

  @override
  void reset() {
    _x1 = 0;
    _x2 = 0;
    _y1 = 0;
    _y2 = 0;
    _primed = false;
  }

  double _prime(double input) {
    _x1 = input;
    _x2 = input;
    _y1 = input;
    _y2 = input;
    _primed = true;
    return input;
  }
}

class _FirstOrderCoefficients {
  final double b0;
  final double b1;
  final double a1;

  const _FirstOrderCoefficients({
    required this.b0,
    required this.b1,
    required this.a1,
  });
}

class _BiquadCoefficients {
  final double b0;
  final double b1;
  final double b2;
  final double a1;
  final double a2;

  const _BiquadCoefficients({
    required this.b0,
    required this.b1,
    required this.b2,
    required this.a1,
    required this.a2,
  });
}

List<_IirFilterStage> _buildButterworthStages({
  required _ButterworthFilterType type,
  required double cutoffHz,
  required int order,
}) {
  final stageOrder = order.clamp(
    _AxisFilterConfig.minOrder,
    _AxisFilterConfig.maxOrder,
  );
  final stages = <_IirFilterStage>[];
  if (stageOrder.isOdd) {
    stages.add(
      _ButterworthFirstOrderStage(
        type: type,
        cutoffHz: cutoffHz,
      ),
    );
  }

  final biquadCount = stageOrder ~/ 2;
  for (var i = 0; i < biquadCount; i++) {
    stages.add(
      _ButterworthBiquadStage(
        type: type,
        cutoffHz: cutoffHz,
        q: _butterworthSectionQ(
          sectionIndex: i,
          order: stageOrder,
        ),
      ),
    );
  }

  return stages;
}

List<_IirFilterStage> _buildNotchFilterStages({
  required double centerHz,
  required double widthHz,
  required int order,
}) {
  final stageOrder = _AxisFilterConfig._clampNotchOrder(order);
  final stageCount = stageOrder ~/ 2;
  return List<_IirFilterStage>.generate(
    stageCount,
    (_) => _NotchBiquadStage(
      centerHz: centerHz,
      widthHz: widthHz,
    ),
    growable: false,
  );
}

double _butterworthSectionQ({
  required int sectionIndex,
  required int order,
}) {
  return 1 / (2 * sin((2 * sectionIndex + 1) * pi / (2 * order)));
}

_FirstOrderCoefficients _firstOrderCoefficients({
  required _ButterworthFilterType type,
  required double cutoffHz,
  required double dt,
}) {
  final normalizedCutoff = _frequencyBelowNyquist(
    frequencyHz: cutoffHz,
    dt: dt,
  );
  final k = tan(pi * normalizedCutoff * dt);
  final norm = 1 / (1 + k);

  if (type == _ButterworthFilterType.lowPass) {
    return _FirstOrderCoefficients(
      b0: k * norm,
      b1: k * norm,
      a1: (k - 1) * norm,
    );
  }

  return _FirstOrderCoefficients(
    b0: norm,
    b1: -norm,
    a1: (k - 1) * norm,
  );
}

_BiquadCoefficients _biquadCoefficients({
  required _ButterworthFilterType type,
  required double cutoffHz,
  required double q,
  required double dt,
}) {
  final normalizedCutoff = _frequencyBelowNyquist(
    frequencyHz: cutoffHz,
    dt: dt,
  );
  final w0 = 2 * pi * normalizedCutoff * dt;
  final cosW0 = cos(w0);
  final sinW0 = sin(w0);
  final alpha = sinW0 / (2 * q);
  final a0 = 1 + alpha;
  final a1 = -2 * cosW0;
  final a2 = 1 - alpha;

  late final double b0;
  late final double b1;
  late final double b2;
  if (type == _ButterworthFilterType.lowPass) {
    b0 = (1 - cosW0) / 2;
    b1 = 1 - cosW0;
    b2 = (1 - cosW0) / 2;
  } else {
    b0 = (1 + cosW0) / 2;
    b1 = -(1 + cosW0);
    b2 = (1 + cosW0) / 2;
  }

  return _BiquadCoefficients(
    b0: b0 / a0,
    b1: b1 / a0,
    b2: b2 / a0,
    a1: a1 / a0,
    a2: a2 / a0,
  );
}

_BiquadCoefficients _notchCoefficients({
  required double centerHz,
  required double widthHz,
  required double dt,
}) {
  final normalizedCenter = _frequencyBelowNyquist(
    frequencyHz: centerHz,
    dt: dt,
  );
  final bandwidthHz = max(widthHz.abs(), 1e-9);
  final q = max(normalizedCenter / bandwidthHz, 1e-6);
  final w0 = 2 * pi * normalizedCenter * dt;
  final cosW0 = cos(w0);
  final sinW0 = sin(w0);
  final alpha = sinW0 / (2 * q);
  final a0 = 1 + alpha;

  return _BiquadCoefficients(
    b0: 1 / a0,
    b1: (-2 * cosW0) / a0,
    b2: 1 / a0,
    a1: (-2 * cosW0) / a0,
    a2: (1 - alpha) / a0,
  );
}

double _frequencyBelowNyquist({
  required double frequencyHz,
  required double dt,
}) {
  if (dt <= 0 || !dt.isFinite || frequencyHz <= 0 || !frequencyHz.isFinite) {
    return 1e-9;
  }

  final sampleRateHz = 1 / dt;
  final maxFrequencyHz = max(1e-9, sampleRateHz * 0.49);
  return frequencyHz.clamp(1e-9, maxFrequencyHz).toDouble();
}
