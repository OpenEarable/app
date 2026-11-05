import 'dart:math';

typedef PulseRmssdEstimate = ({double? ticks, int pairCount, String method});

/// Computes RMSSD from successive accepted intervals. When explicitly allowed,
/// a separately labeled sparse proxy uses measured nonadjacent intervals if
/// too few successive pairs survive. Values use the caller's timestamp unit.
abstract final class PulseIntervalRmssd {
  // A single misplaced PPG peak can create a short/long interval pair while
  // remaining inside the broad physiological beat range. Compare each beat
  // with its nearby rhythm before it contributes to successive differences.
  static const double _maximumLocalDeviationFraction = 0.20;

  static PulseRmssdEstimate estimate(
    List<double?> intervals, {
    bool allowSparse = false,
  }) {
    final accepted = intervals.whereType<double>().toList(growable: false);
    if (accepted.length < 2) {
      return (ticks: null, pairCount: 0, method: 'insufficient_intervals');
    }
    final locallyValid = List<bool>.filled(intervals.length, false);
    for (var index = 0; index < intervals.length; index++) {
      final interval = intervals[index];
      if (interval == null || !interval.isFinite || interval <= 0) continue;
      final neighbors = <double>[];
      for (var neighborIndex = max(0, index - 2);
          neighborIndex <= min(intervals.length - 1, index + 2);
          neighborIndex++) {
        final neighbor = intervals[neighborIndex];
        if (neighbor != null && neighbor.isFinite && neighbor > 0) {
          neighbors.add(neighbor);
        }
      }
      neighbors.sort();
      if (neighbors.length < 3) {
        // Two beats cannot identify which one is the outlier.
        locallyValid[index] = true;
        continue;
      }
      final midpoint = neighbors.length ~/ 2;
      final localMedian = neighbors.length.isOdd
          ? neighbors[midpoint]
          : (neighbors[midpoint - 1] + neighbors[midpoint]) / 2;
      locallyValid[index] = (interval - localMedian).abs() <=
          localMedian * _maximumLocalDeviationFraction;
    }

    ({double? ticks, int pairCount}) adjacentPairs({
      required bool medianFiltered,
    }) {
      var sumSquared = 0.0;
      var pairCount = 0;
      for (var i = 1; i < intervals.length; i++) {
        final before = intervals[i - 1];
        final after = intervals[i];
        if (before == null || after == null) continue;
        if (medianFiltered && (!locallyValid[i - 1] || !locallyValid[i])) {
          continue;
        }
        final difference = after - before;
        sumSquared += difference * difference;
        pairCount++;
      }
      return (
        ticks: pairCount == 0 ? null : sqrt(sumSquared / pairCount),
        pairCount: pairCount,
      );
    }

    final robust = adjacentPairs(medianFiltered: true);
    if (robust.ticks != null) {
      return (
        ticks: robust.ticks,
        pairCount: robust.pairCount,
        method: 'adjacent_median_filtered',
      );
    }
    if (allowSparse) {
      // Last resort for either biosignal mode: a proxy derived from measured
      // intervals, not a synthetic/default RMSSD. Diagnostics identify this
      // lower-confidence path explicitly.
      final filtered = <double>[];
      for (var index = 0; index < intervals.length; index++) {
        if (locallyValid[index]) filtered.add(intervals[index]!);
      }
      if (filtered.length >= 2) {
        var sumSquared = 0.0;
        for (var i = 1; i < filtered.length; i++) {
          final difference = filtered[i] - filtered[i - 1];
          sumSquared += difference * difference;
        }
        return (
          ticks: sqrt(sumSquared / (filtered.length - 1)),
          pairCount: filtered.length - 1,
          method: 'sparse_measured_proxy',
        );
      }
    }
    final absolute = adjacentPairs(medianFiltered: false);
    if (absolute.ticks != null) {
      return (
        ticks: absolute.ticks,
        pairCount: absolute.pairCount,
        method: 'adjacent_absolute_range',
      );
    }
    if (allowSparse) {
      var sumSquared = 0.0;
      for (var i = 1; i < accepted.length; i++) {
        final difference = accepted[i] - accepted[i - 1];
        sumSquared += difference * difference;
      }
      return (
        ticks: sqrt(sumSquared / (accepted.length - 1)),
        pairCount: accepted.length - 1,
        method: 'sparse_unfiltered_proxy',
      );
    }
    return (ticks: null, pairCount: 0, method: 'no_adjacent_pairs');
  }
}
