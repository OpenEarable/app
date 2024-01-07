import 'package:collection/collection.dart';

class TrackerRunData {
  final Duration duration;
  final Duration elapsed;
  final int stepCount;
  final double stepsPerMinute;
  final int bpmValue;
  final int bpmAverage;
  final List<int> bpmValues;
  final DateTime? lastStepTime;

  TrackerRunData({
    required this.duration,
    required this.elapsed,
    required this.stepCount,
    required this.stepsPerMinute,
    required this.bpmValue,
    required this.bpmAverage,
    required this.bpmValues,
    this.lastStepTime,
  });

  final int minStepIntervalMillis = 140;

  TrackerRunData incrementStepCount() {
    var now = DateTime.now();
    if (lastStepTime == null ||
        now.difference(lastStepTime!).inMilliseconds > minStepIntervalMillis) {
      int _newStepCount = stepCount + 1;
      double _newStepsPerMinute = (((_newStepCount) /
              (elapsed.inSeconds != 0 ? elapsed.inSeconds + 1 : 1)) *
          60);

      int _newBpmValue = _newStepsPerMinute.round();
      List<int> _newValues = [...bpmValues, _newBpmValue];
      if (_newValues.length > 5) {
        _newValues = _newValues.sublist(_newValues.length - 5);
      }
      int _newBpmAverage = bpmValue;
      if (elapsed.inSeconds > 10) {
        _newBpmAverage =
            (_newValues.reduce((value, element) => value + element) /
                    _newValues.length)
                .round();
      }
      return this.copyWith(
          stepCount: _newStepCount,
          stepsPerMinute: _newStepsPerMinute,
          lastStepTime: now,
          bpmValue: _newBpmValue,
          bpmAverage: _newBpmAverage,
          bpmValues: _newValues);
    }
    return this;
  }

  TrackerRunData tick() {
    int _newBpmValue = ((((stepsPerMinute / 1).floor() * 1) +
                ((stepsPerMinute / 1).round() * 1)) /
            2)
        .round();
    List<int> _newValues = [...bpmValues, _newBpmValue];
    int _newBpmAverage = bpmValue;
    if (elapsed.inSeconds > 10) {
      _newBpmAverage = (_newValues.reduce((value, element) => value + element) /
              _newValues.length)
          .round();
    }
    return this.copyWith(
        duration: Duration(seconds: this.duration.inSeconds - 1),
        elapsed: Duration(seconds: this.elapsed.inSeconds + 1),
        bpmValue: _newBpmValue,
        bpmAverage: _newBpmAverage,
        bpmValues: _newValues);
  }

  TrackerRunData copyWith({
    Duration? duration,
    Duration? elapsed,
    List<double>? yAxisValues,
    List<double>? zAxisValues,
    double? xThreshold,
    double? zThreshold,
    double? combinedThreshold,
    int? stepCount,
    double? stepsPerMinute,
    int? bpmValue,
    int? bpmAverage,
    List<int>? bpmValues,
    DateTime? lastStepTime,
  }) {
    return TrackerRunData(
      duration: duration ?? this.duration,
      elapsed: elapsed ?? this.elapsed,
      stepCount: stepCount ?? this.stepCount,
      stepsPerMinute: stepsPerMinute ?? this.stepsPerMinute,
      bpmValue: bpmValue ?? this.bpmValue,
      bpmAverage: bpmAverage ?? this.bpmAverage,
      bpmValues: bpmValues ?? this.bpmValues,
      lastStepTime: lastStepTime ?? this.lastStepTime,
    );
  }

  @override
  String toString() {
    return 'TrackerRunData(duration: ${duration.inSeconds}, elapsed: ${elapsed.inSeconds}, stepCount: $stepCount, stepsPerMinute: $stepsPerMinute, bpmValue: $bpmValue, bpmAverage: $bpmAverage, bpmValues: $bpmValues, lastStepTime: $lastStepTime)';
  }

  @override
  bool operator ==(covariant TrackerRunData other) {
    if (identical(this, other)) return true;
    final listEquals = const DeepCollectionEquality().equals;

    return other.duration.inSeconds == duration.inSeconds &&
        other.elapsed.inSeconds == elapsed.inSeconds &&
        other.stepCount == stepCount &&
        other.stepsPerMinute == stepsPerMinute &&
        other.bpmValue == bpmValue &&
        other.bpmAverage == bpmAverage &&
        listEquals(other.bpmValues, bpmValues) &&
        other.lastStepTime == lastStepTime;
  }

  @override
  int get hashCode {
    return duration.hashCode ^
        elapsed.hashCode ^
        stepCount.hashCode ^
        stepsPerMinute.hashCode ^
        bpmValue.hashCode ^
        bpmAverage.hashCode ^
        bpmValues.hashCode ^
        lastStepTime.hashCode;
  }
}
