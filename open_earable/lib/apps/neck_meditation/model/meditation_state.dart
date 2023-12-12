import 'dart:async';

import 'package:open_earable/apps/neck_meditation/view_model/meditation_view_model.dart';
import 'package:open_earable_flutter/src/open_earable_flutter.dart';

/// Enum for the Meditation States
enum MeditationState {
  mainNeckStretch,
  leftNeckStretch,
  rightNeckStretch,
  noStretch,
  doneStretching
}

/// Used to get a String representation for Display of the current meditation state
extension MeditationStateExtension on MeditationState {
  String get display {
    switch (this) {
      case MeditationState.mainNeckStretch:
        return 'Main Neck Area';
      case MeditationState.leftNeckStretch:
        return 'Right Neck Area';
      case MeditationState.rightNeckStretch:
        return 'Left Neck Area';
      case MeditationState.noStretch:
        return 'Not Stretching';
      case MeditationState.doneStretching:
        return 'You are done stretching. Good job!';
      default:
        return 'Invalid State';
    }
  }
}

class MeditationSettings {
  MeditationState state;

  /// Duration for the main neck relaxation
  Duration mainNeckRelaxation;

  /// Duration for the left neck relaxation
  Duration leftNeckRelaxation;

  /// Duration for the right neck relaxation
  Duration rightNeckRelaxation;

  MeditationSettings(
      {this.state = MeditationState.noStretch,
      required this.mainNeckRelaxation,
      required this.leftNeckRelaxation,
      required this.rightNeckRelaxation});
}

class NeckMeditation {
  MeditationSettings _settings = MeditationSettings(
      mainNeckRelaxation: Duration(seconds: 30),
      leftNeckRelaxation: Duration(seconds: 30),
      rightNeckRelaxation: Duration(seconds: 30));

  final OpenEarable _openEarable;
  final MeditationViewModel _viewModel;

  /// Holds the Timer that increments the current Duration
  var _restDurationTimer;
  /// Stores the rest duration of the current timer
  var _restDuration;

  /// Stores the current active timer for state transition
  var _currentTimer;

  MeditationSettings get settings => _settings;

  NeckMeditation(this._openEarable, this._viewModel);

  void setSettings(MeditationSettings settings) {
    _settings = settings;
  }

  // Gets the rest duration of the current meditation timer
  Duration getRestDuration() {
    return _restDuration;
  }

  /// Starts the Meditation with the according timers
  startMeditation() {
    _settings.state = MeditationState.mainNeckStretch;
    _restDuration = _settings.mainNeckRelaxation;
    _currentTimer = Timer(_settings.mainNeckRelaxation, _setNextState);
    _restDurationTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      _restDuration -= Duration(seconds: 1);
    });
  }

  /// Stops the current Meditation
  stopMeditation() {
    _settings.state = MeditationState.noStretch;
    _currentTimer.cancel();
    _restDurationTimer.cancel();
    _restDuration = Duration(seconds: 0);
  }

  /// Used to set the next meditation state and set the correct Timer
  void _setNextState() {
    switch (_settings.state) {
      case MeditationState.noStretch:
      case MeditationState.doneStretching:
        _settings.state = MeditationState.mainNeckStretch;
        return;
      case MeditationState.mainNeckStretch:
        _settings.state = MeditationState.leftNeckStretch;
        _currentTimer = Timer(_settings.leftNeckRelaxation, _setNextState);
        _restDuration = _settings.leftNeckRelaxation;
        _openEarable.audioPlayer.jingle(2);
        return;
      case MeditationState.leftNeckStretch:
        _settings.state = MeditationState.rightNeckStretch;
        _currentTimer = Timer(_settings.rightNeckRelaxation, _setNextState);
        _restDuration = _settings.rightNeckRelaxation;
        _openEarable.audioPlayer.jingle(2);
        return;
      case MeditationState.rightNeckStretch:
        _settings.state = MeditationState.doneStretching;
        _viewModel.stopTracking();
        _restDurationTimer.cancel();
        _restDuration = Duration(seconds: 0);
        _openEarable.audioPlayer.jingle(2);
        return;
      default:
        return;
    }
  }
}
