part of '../sensor_chart.dart';

class _AxisDisplayFilterCache {
  final _AxisFilterConfig config;
  final double timestampScale;
  final _AxisDisplayFilter _filter;
  final Map<int, double> _valuesByTimestamp = <int, double>{};
  int? _lastTimestamp;

  _AxisDisplayFilterCache({
    required this.config,
    required this.timestampScale,
  }) : _filter = _AxisDisplayFilter(
          config: config,
          timestampScale: timestampScale,
        );

  double apply(double input, int timestamp) {
    final cachedValue = _valuesByTimestamp[timestamp];
    if (cachedValue != null) {
      return cachedValue;
    }

    final lastTimestamp = _lastTimestamp;
    if (lastTimestamp != null && timestamp < lastTimestamp) {
      _valuesByTimestamp.clear();
      _filter.reset();
    }

    final filteredValue = _filter.apply(input, timestamp);
    _valuesByTimestamp[timestamp] = filteredValue;
    _lastTimestamp = timestamp;
    return filteredValue;
  }

  void retainTimestamps(Set<int> timestamps) {
    _valuesByTimestamp.removeWhere((timestamp, _) {
      return !timestamps.contains(timestamp);
    });
  }
}

class _AxisDisplayFilter {
  static const int _initialIntervalCount = 8;
  static const int _rateCheckIntervalCount = 16;

  final _AxisFilterConfig config;
  final double timestampScale;
  final List<_IirFilterStage> _highPassStages;
  final List<_IirFilterStage> _lowPassStages;
  final List<_IirFilterStage> _notchStages;
  final List<double> _measuredIntervals = <double>[];

  int? _previousTimestamp;
  double? _designDt;

  _AxisDisplayFilter({
    required this.config,
    required this.timestampScale,
  })  : _highPassStages = _buildHighPassStages(config),
        _lowPassStages = _buildLowPassStages(config),
        _notchStages = _buildNotchStages(config);

  double apply(double input, int timestamp) {
    if (!config.hasActiveFilters) {
      return input;
    }

    final dt = _stableTimeDelta(_timeDeltaSeconds(timestamp));
    if (dt == null) {
      return input;
    }
    var output = input;
    for (final stage in _highPassStages) {
      output = stage.apply(output, dt);
    }
    for (final stage in _lowPassStages) {
      output = stage.apply(output, dt);
    }
    for (final stage in _notchStages) {
      output = stage.apply(output, dt);
    }

    return output;
  }

  void reset() {
    _previousTimestamp = null;
    _designDt = null;
    _measuredIntervals.clear();
    _resetStages();
  }

  void _resetStages() {
    for (final stage in _highPassStages) {
      stage.reset();
    }
    for (final stage in _lowPassStages) {
      stage.reset();
    }
    for (final stage in _notchStages) {
      stage.reset();
    }
  }

  double? _stableTimeDelta(double measuredDt) {
    if (measuredDt <= 0 || !measuredDt.isFinite) {
      return _designDt;
    }

    _measuredIntervals.add(measuredDt);
    final designDt = _designDt;
    if (designDt == null) {
      if (_measuredIntervals.length < _initialIntervalCount) {
        return null;
      }
      _designDt = _medianInterval(_measuredIntervals);
      _measuredIntervals.clear();
      return _designDt;
    }

    if (_measuredIntervals.length >= _rateCheckIntervalCount) {
      final recentDt = _medianInterval(_measuredIntervals);
      _measuredIntervals.clear();
      // Keep IIR coefficients fixed through timestamp jitter. A sustained rate
      // change needs new coefficients and a reset of the filter state.
      if (recentDt < designDt * 0.8 || recentDt > designDt * 1.25) {
        _designDt = recentDt;
        _resetStages();
      }
    }
    return _designDt;
  }

  static double _medianInterval(List<double> intervals) {
    final sorted = intervals.toList()..sort();
    final middle = sorted.length ~/ 2;
    if (sorted.length.isOdd) {
      return sorted[middle];
    }
    return (sorted[middle - 1] + sorted[middle]) / 2;
  }

  double _timeDeltaSeconds(int timestamp) {
    final previousTimestamp = _previousTimestamp;
    _previousTimestamp = timestamp;
    if (previousTimestamp == null ||
        timestampScale <= 0 ||
        !timestampScale.isFinite) {
      return 0;
    }
    return (timestamp - previousTimestamp).abs().toDouble() / timestampScale;
  }

  static List<_IirFilterStage> _buildHighPassStages(
    _AxisFilterConfig config,
  ) {
    if (!config.highPassEnabled) {
      return const [];
    }
    return _buildButterworthStages(
      type: _ButterworthFilterType.highPass,
      cutoffHz: config.highPassCutoffHz,
      order: config.highPassOrder,
    );
  }

  static List<_IirFilterStage> _buildLowPassStages(
    _AxisFilterConfig config,
  ) {
    if (!config.lowPassEnabled) {
      return const [];
    }
    return _buildButterworthStages(
      type: _ButterworthFilterType.lowPass,
      cutoffHz: config.lowPassCutoffHz,
      order: config.lowPassOrder,
    );
  }

  static List<_IirFilterStage> _buildNotchStages(
    _AxisFilterConfig config,
  ) {
    if (!config.notchEnabled) {
      return const [];
    }
    return _buildNotchFilterStages(
      centerHz: config.notchCenterHz,
      widthHz: config.notchWidthHz,
      order: config.notchOrder,
    );
  }
}
