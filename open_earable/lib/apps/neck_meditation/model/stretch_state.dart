import 'dart:async';

import 'package:open_earable/apps/neck_meditation/view_model/stretch_view_model.dart';
import 'package:open_earable_flutter/src/open_earable_flutter.dart';

/// Enum for the Meditation States
enum NeckStretchState {
  mainNeckStretch,
  leftNeckStretch,
  rightNeckStretch,
  noStretch,
  doneStretching
}

/// Used to get a String representation for Display of the current meditation state
extension NeckStretchStateExtension on NeckStretchState {
  String get display {
    switch (this) {
      case NeckStretchState.mainNeckStretch:
        return 'Main Neck Area';
      case NeckStretchState.leftNeckStretch:
        return 'Right Neck Area';
      case NeckStretchState.rightNeckStretch:
        return 'Left Neck Area';
      case NeckStretchState.noStretch:
        return 'Not Stretching';
      case NeckStretchState.doneStretching:
        return 'You are done stretching. Good job!';
      default:
        return 'Invalid State';
    }
  }
}

class StretchSettings {
  NeckStretchState state;

  /// Duration for the main neck relaxation
  Duration mainNeckRelaxation;

  /// Duration for the left neck relaxation
  Duration leftNeckRelaxation;

  /// Duration for the right neck relaxation
  Duration rightNeckRelaxation;

  StretchSettings(
      {this.state = NeckStretchState.noStretch,
      required this.mainNeckRelaxation,
      required this.leftNeckRelaxation,
      required this.rightNeckRelaxation});
}

class NeckMeditation {
  StretchSettings _settings = StretchSettings(
      mainNeckRelaxation: Duration(seconds: 30),
      leftNeckRelaxation: Duration(seconds: 30),
      rightNeckRelaxation: Duration(seconds: 30));

  final OpenEarable _openEarable;
  final StretchViewModel _viewModel;

  /// Holds the Timer that increments the current Duration
  var _restDurationTimer;
  /// Stores the rest duration of the current timer
  var _restDuration;

  /// Stores the current active timer for state transition
  var _currentTimer;

  StretchSettings get settings => _settings;

  NeckMeditation(this._openEarable, this._viewModel);

  /// Setter method for stretchSettings
  void setSettings(StretchSettings settings) {
    _settings = settings;
  }

  // Gets the rest duration of the current meditation timer
  Duration getRestDuration() {
    return _restDuration;
  }

  /// Starts the Meditation with the according timers
  startMeditation() {
    _settings.state = NeckStretchState.mainNeckStretch;
    _restDuration = _settings.mainNeckRelaxation;
    _currentTimer = Timer(_settings.mainNeckRelaxation, _setNextState);
    _restDurationTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      _restDuration -= Duration(seconds: 1);
    });
  }

  /// Stops the current Meditation
  stopMeditation() {
    _settings.state = NeckStretchState.noStretch;
    _currentTimer.cancel();
    _restDurationTimer.cancel();
    _restDuration = Duration(seconds: 0);
  }

  /// Used to set the next meditation state and set the correct Timer
  void _setNextState() {
    switch (_settings.state) {
      case NeckStretchState.noStretch:
      case NeckStretchState.doneStretching:
        _settings.state = NeckStretchState.mainNeckStretch;
        return;
      case NeckStretchState.mainNeckStretch:
        _settings.state = NeckStretchState.leftNeckStretch;
        _currentTimer = Timer(_settings.leftNeckRelaxation, _setNextState);
        _restDuration = _settings.leftNeckRelaxation;
        _openEarable.audioPlayer.jingle(2);
        return;
      case NeckStretchState.leftNeckStretch:
        _settings.state = NeckStretchState.rightNeckStretch;
        _currentTimer = Timer(_settings.rightNeckRelaxation, _setNextState);
        _restDuration = _settings.rightNeckRelaxation;
        _openEarable.audioPlayer.jingle(2);
        return;
      case NeckStretchState.rightNeckStretch:
        _settings.state = NeckStretchState.doneStretching;
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
