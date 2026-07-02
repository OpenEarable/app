part of '../sensor_chart.dart';

class _FilterFrequencyBounds {
  static const double defaultMinCutoffHz = 0.01;
  static const double fallbackMaxCutoffHz = 500;

  final double minCutoffHz;
  final double maxCutoffHz;
  final double? maxSamplingRateHz;

  const _FilterFrequencyBounds({
    required this.maxCutoffHz,
    this.maxSamplingRateHz,
  }) : minCutoffHz = defaultMinCutoffHz;

  const _FilterFrequencyBounds.fallback()
      : minCutoffHz = defaultMinCutoffHz,
        maxCutoffHz = fallbackMaxCutoffHz,
        maxSamplingRateHz = null;
}

class _AxisFilterConfig {
  static const int minOrder = 1;
  static const int maxOrder = 8;
  static const int minNotchOrder = 2;
  static const int maxNotchOrder = 8;

  final bool highPassEnabled;
  final bool lowPassEnabled;
  final bool notchEnabled;
  final double highPassCutoffHz;
  final double lowPassCutoffHz;
  final double notchCenterHz;
  final double notchWidthHz;
  final int highPassOrder;
  final int lowPassOrder;
  final int notchOrder;

  const _AxisFilterConfig({
    required this.highPassEnabled,
    required this.lowPassEnabled,
    required this.notchEnabled,
    required this.highPassCutoffHz,
    required this.lowPassCutoffHz,
    required this.notchCenterHz,
    required this.notchWidthHz,
    required this.highPassOrder,
    required this.lowPassOrder,
    required this.notchOrder,
  });

  const _AxisFilterConfig.raw()
      : highPassEnabled = false,
        lowPassEnabled = false,
        notchEnabled = false,
        highPassCutoffHz = 0.5,
        lowPassCutoffHz = 20,
        notchCenterHz = 50,
        notchWidthHz = 2,
        highPassOrder = 2,
        lowPassOrder = 2,
        notchOrder = 2;

  bool get hasActiveFilters {
    return highPassEnabled || lowPassEnabled || notchEnabled;
  }

  _AxisFilterConfig clampedTo(_FilterFrequencyBounds frequencyBounds) {
    var nextHighPassCutoff = _clampFrequency(highPassCutoffHz, frequencyBounds);
    var nextLowPassCutoff = _clampFrequency(lowPassCutoffHz, frequencyBounds);
    if (highPassEnabled &&
        lowPassEnabled &&
        nextHighPassCutoff >= nextLowPassCutoff &&
        frequencyBounds.minCutoffHz < frequencyBounds.maxCutoffHz) {
      nextHighPassCutoff = frequencyBounds.minCutoffHz;
      nextLowPassCutoff = frequencyBounds.maxCutoffHz;
    }

    var nextNotchWidth = _clampFrequency(notchWidthHz, frequencyBounds);
    final maxWidth =
        max(frequencyBounds.minCutoffHz, frequencyBounds.maxCutoffHz);
    nextNotchWidth = nextNotchWidth.clamp(
      frequencyBounds.minCutoffHz,
      maxWidth,
    );

    var nextNotchCenter = _clampFrequency(notchCenterHz, frequencyBounds);
    final halfWidth = nextNotchWidth / 2;
    final centerMin = frequencyBounds.minCutoffHz + halfWidth;
    final centerMax = frequencyBounds.maxCutoffHz - halfWidth;
    if (centerMin <= centerMax) {
      nextNotchCenter = nextNotchCenter.clamp(centerMin, centerMax).toDouble();
    } else {
      nextNotchCenter =
          (frequencyBounds.minCutoffHz + frequencyBounds.maxCutoffHz) / 2;
      nextNotchWidth = max(
        frequencyBounds.minCutoffHz,
        frequencyBounds.maxCutoffHz - frequencyBounds.minCutoffHz,
      );
    }

    return copyWith(
      highPassCutoffHz: nextHighPassCutoff,
      lowPassCutoffHz: nextLowPassCutoff,
      notchCenterHz: nextNotchCenter,
      notchWidthHz: nextNotchWidth,
      highPassOrder: _clampOrder(highPassOrder),
      lowPassOrder: _clampOrder(lowPassOrder),
      notchOrder: _clampNotchOrder(notchOrder),
    );
  }

  static double _clampFrequency(
    double value,
    _FilterFrequencyBounds frequencyBounds,
  ) {
    if (!value.isFinite) {
      return frequencyBounds.minCutoffHz;
    }
    return value
        .clamp(frequencyBounds.minCutoffHz, frequencyBounds.maxCutoffHz)
        .toDouble();
  }

  static int _clampOrder(int value) {
    return value.clamp(minOrder, maxOrder).toInt();
  }

  static int _clampNotchOrder(int value) {
    final clamped = value.clamp(minNotchOrder, maxNotchOrder).toInt();
    if (clamped.isEven) {
      return clamped;
    }
    return clamped == maxNotchOrder ? clamped - 1 : clamped + 1;
  }

  _AxisFilterConfig copyWith({
    bool? highPassEnabled,
    bool? lowPassEnabled,
    bool? notchEnabled,
    double? highPassCutoffHz,
    double? lowPassCutoffHz,
    double? notchCenterHz,
    double? notchWidthHz,
    int? highPassOrder,
    int? lowPassOrder,
    int? notchOrder,
  }) {
    return _AxisFilterConfig(
      highPassEnabled: highPassEnabled ?? this.highPassEnabled,
      lowPassEnabled: lowPassEnabled ?? this.lowPassEnabled,
      notchEnabled: notchEnabled ?? this.notchEnabled,
      highPassCutoffHz: highPassCutoffHz ?? this.highPassCutoffHz,
      lowPassCutoffHz: lowPassCutoffHz ?? this.lowPassCutoffHz,
      notchCenterHz: notchCenterHz ?? this.notchCenterHz,
      notchWidthHz: notchWidthHz ?? this.notchWidthHz,
      highPassOrder: highPassOrder ?? this.highPassOrder,
      lowPassOrder: lowPassOrder ?? this.lowPassOrder,
      notchOrder: notchOrder ?? this.notchOrder,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is _AxisFilterConfig &&
        other.highPassEnabled == highPassEnabled &&
        other.lowPassEnabled == lowPassEnabled &&
        other.notchEnabled == notchEnabled &&
        other.highPassCutoffHz == highPassCutoffHz &&
        other.lowPassCutoffHz == lowPassCutoffHz &&
        other.notchCenterHz == notchCenterHz &&
        other.notchWidthHz == notchWidthHz &&
        other.highPassOrder == highPassOrder &&
        other.lowPassOrder == lowPassOrder &&
        other.notchOrder == notchOrder;
  }

  @override
  int get hashCode => Object.hash(
        highPassEnabled,
        lowPassEnabled,
        notchEnabled,
        highPassCutoffHz,
        lowPassCutoffHz,
        notchCenterHz,
        notchWidthHz,
        highPassOrder,
        lowPassOrder,
        notchOrder,
      );
}

String _formatNumber(double value) {
  final fixed = value.toStringAsFixed(value < 10 ? 2 : 1);
  return fixed
      .replaceFirst(RegExp(r'0+$'), '')
      .replaceFirst(RegExp(r'\.$'), '');
}
