import 'dart:async';

import 'breathing_sensor_tracker.dart';

/// A model class to manage the state and functionality of a breathing session.
///
/// The `BreathingSessionModel` handles:
/// - Managing breathing phases (Inhale, Hold, Exhale).
/// - Communicating with the `BreathingSensorTracker` to monitor posture feedback.
/// - Providing streams for UI updates (breathing phase, posture feedback).
class BreathingSessionModel {
  final StreamController<String> _breathingPhaseController =
      StreamController.broadcast();

  Stream<String> get breathingPhaseStream => _breathingPhaseController.stream;

  final StreamController<String> _postureFeedbackController =
      StreamController.broadcast();

  Stream<String> get postureFeedbackStream =>
      _postureFeedbackController.stream;

  /// Timer to manage the duration of each breathing phase.
  Timer? _breathingTimer;

  /// Tracker to monitor and provide posture feedback during the session.
  BreathingSensorTracker? sensorTracker;

  /// The index of the current phase in the breathing cycle.
  int _phaseIndex = 0;

  /// The list of breathing phases and their durations.
  final List<Map<String, dynamic>> _phases = [
    {'phase': 'Inhale', 'duration': 4},
    {'phase': 'Hold', 'duration': 7},
    {'phase': 'Exhale', 'duration': 8},
  ];

  List<Map<String, dynamic>> get phases => _phases;

  bool _isNightMode = false;

  /// The total duration of the breathing session in seconds.
  int _sessionDuration = 240; // Default 4 minutes.

  int _elapsedTime = 0;

  /// The posture mode (e.g., 'sitting' or 'lying').
  String _positionMode = 'sitting'; // Default mode is 'sitting'.

  bool get isNightMode => _isNightMode;

  set isNightMode(bool value) {
    _isNightMode = value;
  }

  int get elapsedTime => _elapsedTime;

  int get sessionDuration => _sessionDuration;

  set sessionDuration(int duration) {
    _sessionDuration = duration;
  }

  /// Gets the current posture mode (e.g., 'sitting' or 'lying').
  String get positionMode => _positionMode;

  /// Sets the posture mode and updates the sensor tracker thresholds accordingly.
  ///
  /// - [mode]: The posture mode to set (e.g., 'sitting' or 'lying').
  void setMode(String mode) {
    _positionMode = mode;
    sensorTracker?.setMode(mode);
  }

  /// Starts the breathing session by resetting state, starting posture tracking, 
  /// and initiating the breathing cycle
  void startSession() {
    stopSession(sessionEnded: false);
    _phaseIndex = 0;
    _elapsedTime = 0;

    sensorTracker?.startTracking();

    sensorTracker?.postureFeedbackStream.listen((feedback) {
      print('Feedback Received in Model: $feedback');
      _postureFeedbackController.add(feedback);
    });

    _nextBreathingPhase();
  }

  /// Moves to the next breathing phase or stops the session if complete.
  void _nextBreathingPhase() {
    if (_elapsedTime >= sessionDuration) {
      stopSession();
      return;
    }

    final currentPhase = _phases[_phaseIndex];
    _breathingPhaseController.add(currentPhase['phase']);

    _breathingTimer = Timer(
      Duration(seconds: currentPhase['duration']),
      () {
        _elapsedTime += currentPhase['duration'] as int;
        _phaseIndex = (_phaseIndex + 1) % _phases.length;

        // Check for session completion.
        if (_elapsedTime >= sessionDuration) {
          stopSession();
        } else {
          _nextBreathingPhase();
        }
      },
    );
  }

  /// Stops the breathing session and sensor tracking.
  ///
  /// - [sessionEnded]: If true, emits a 'Completed' signal to indicate the session ended.
  void stopSession({bool sessionEnded = true}) {
    _breathingTimer?.cancel();

    sensorTracker?.stopTracking();

    if (sessionEnded) {
      _breathingPhaseController.add('Completed');
    }
  }
}
