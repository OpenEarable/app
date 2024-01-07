part of 'tracker_bloc.dart';

@immutable
sealed class TrackerEvent {}

/// Event to start the tracking
class StartTracking extends TrackerEvent {}

/// Event that is called every second in the tracking
class TrackingTick extends TrackerEvent {}

/// Event that is called every time a step is counted
class TrackStep extends TrackerEvent {}

/// Event to cancel the tracking
class CancelTracking extends TrackerEvent {}

/// Event to complete the tracking
class CompleteTracking extends TrackerEvent {}

/// Event to update the tracker settings
class UpdateTrackerSettings extends TrackerEvent {
  final TrackerThresholdConfig config;

  UpdateTrackerSettings({ required this.config });
}
