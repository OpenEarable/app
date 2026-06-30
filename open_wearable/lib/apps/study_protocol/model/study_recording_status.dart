/// Lifecycle state of a guided study recording.
enum StudyRecordingStatus {
  /// No recording in progress.
  idle,

  /// A baseline recording is currently running.
  recording,

  /// The baseline recording finished (timer elapsed or stopped early).
  completed,
}
