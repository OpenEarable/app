part of 'tracker_bloc.dart';

@immutable
sealed class TrackerState {
  final TrackerThresholdConfig config;
  final TrackerRunData runData;

  const TrackerState({required this.config, required this.runData});

  TrackerState copyWith({TrackerThresholdConfig? config});
}

final class TrackerIdleState extends TrackerState {
  TrackerIdleState({required TrackerThresholdConfig config})
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
