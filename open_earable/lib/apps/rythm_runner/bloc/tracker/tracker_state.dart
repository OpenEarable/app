part of 'tracker_bloc.dart';

@immutable
sealed class TrackerState {
  // Tracker configuration, containing thresholds for pedometer
  final TrackerThresholdConfig config;
  // Run data, containing info on the current tracking run
  final TrackerRunData runData;

  const TrackerState({required this.config, required this.runData});

  TrackerState copyWith({TrackerThresholdConfig? config});
}

/// This is the idle state for the tracker. It resets all run data.
final class TrackerIdleState extends TrackerState {
  TrackerIdleState({required TrackerThresholdConfig config})
      // Automatically reset the run data with the idle state
      : super(
            config: config,
            runData: TrackerRunData(
                duration: Duration(seconds: 30),
                elapsed: Duration(seconds: 0),
                stepCount: 0,
                stepsPerMinute: 0,
                bpmValue: 0,
                bpmAverage: 0,
                bpmValues: []));

  @override
  TrackerIdleState copyWith({TrackerThresholdConfig? config}) {
    return TrackerIdleState(config: config ?? this.config);
  }
}

/// This is the running state for the tracker. It requires run data to be instantiated.
final class TrackerRunningState extends TrackerState {
  TrackerRunningState(
      {required TrackerThresholdConfig config, required TrackerRunData runData})
      : super(config: config, runData: runData);

  @override
  TrackerRunningState copyWith(
      {TrackerThresholdConfig? config, TrackerRunData? runData}) {
    return TrackerRunningState(
        config: config ?? this.config, runData: runData ?? this.runData);
  }
}

/// This is the tracker finished state, it represents a completed run of the tracker
final class TrackerFinishedState extends TrackerState {
  TrackerFinishedState(
      {required TrackerThresholdConfig config, required TrackerRunData runData})
      : super(config: config, runData: runData);

  @override
  TrackerFinishedState copyWith(
      {TrackerThresholdConfig? config, TrackerRunData? runData}) {
    return TrackerFinishedState(
        config: config ?? this.config, runData: runData ?? this.runData);
  }
}
