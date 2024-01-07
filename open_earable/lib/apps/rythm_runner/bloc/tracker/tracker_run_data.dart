import 'package:collection/collection.dart';

/// This is a data class used to store information 
/// on a tracking process. It contains information 
/// like the step count, elapsed time, and so on.
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

  // Minimum interval between steps, so we dont double-count
  final int minStepIntervalMillis = 140;

  /// This function increments the step count by one and also calculates 
  /// the current steps per minute as well as the beats per minute, which
  /// are calculated using a running average with a window size of 5.
  TrackerRunData incrementStepCount() {
    // Check if the last recorded step is far enough in the past
    var now = DateTime.now();
    if (lastStepTime == null ||
        now.difference(lastStepTime!).inMilliseconds > minStepIntervalMillis) {
      // Increase step count and calculate exact steps per minute
      int _newStepCount = stepCount + 1;
      double _newStepsPerMinute = (((_newStepCount) /
              (elapsed.inSeconds != 0 ? elapsed.inSeconds + 1 : 1)) *
          60);

      // Round steps per minute to BPM and generate window for running average
      int _newBpmValue = _newStepsPerMinute.round();
      List<int> _newValues = [...bpmValues, _newBpmValue];
      if (_newValues.length > 5) {
        _newValues = _newValues.sublist(_newValues.length - 5);
      }
      // If the timer has run for over 10 seconds start using the 
      // average BPM value. We wait 10 seconds for the system to 
      // calibrate, there are too many fluctuations before this.
      int _newBpmAverage = bpmValue;
      if (elapsed.inSeconds > 10) {
        // calculate running average
        _newBpmAverage =
            (_newValues.reduce((value, element) => value + element) /
                    _newValues.length)
                .round();
      }
      // return a TrackerRunData instance with the new values
      return this.copyWith(
          stepCount: _newStepCount,
          stepsPerMinute: _newStepsPerMinute,
          lastStepTime: now,
          bpmValue: _newBpmValue,
          bpmAverage: _newBpmAverage,
          bpmValues: _newValues);
    }
    // If the last step wasn't far enough in the past, simply return this
    return this;
  }

  /// This function increases the elapsed time and decreases the 
  /// remaining timer duration. It is called once a second.
  TrackerRunData tick() {
    return this.copyWith(
        duration: Duration(seconds: this.duration.inSeconds - 1),
        elapsed: Duration(seconds: this.elapsed.inSeconds + 1));
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
