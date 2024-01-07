part of 'tracker_bloc.dart';

@immutable
sealed class TrackerEvent {}

class StartTracking extends TrackerEvent {}

class TrackingTick extends TrackerEvent {}

class TrackStep extends TrackerEvent {}

class CancelTracking extends TrackerEvent {}

class CompleteTracking extends TrackerEvent {}

class UpdateTrackerSettings extends TrackerEvent {
  final TrackerThresholdConfig config;

  UpdateTrackerSettings({ required this.config });
}
