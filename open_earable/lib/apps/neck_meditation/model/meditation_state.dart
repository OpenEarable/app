import 'dart:async';

import 'package:open_earable_flutter/src/open_earable_flutter.dart';

/// Enum for the Meditation States
enum MeditationState {
  mainNeckStretch,
  leftNeckStretch,
  rightNeckStretch,
  noStretch
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

  /// Stores the current active timer for state transition
  var currentTimer;

  MeditationSettings get settings => _settings;

  NeckMeditation(this._openEarable);

  void setSettings(MeditationSettings settings) {
    _settings = settings;
  }

  startMeditation() {
    _settings.state = MeditationState.mainNeckStretch;
    currentTimer = Timer(_settings.mainNeckRelaxation, _setNextState);
  }

  stopMeditation() {
    _settings.state = MeditationState.noStretch;
    currentTimer?.cancel();
  }

  /// Used to set the next meditation state;
  void _setNextState() {
    switch (_settings.state) {
      case MeditationState.noStretch:
        _settings.state = MeditationState.mainNeckStretch;
        return;
      case MeditationState.mainNeckStretch:
        _settings.state = MeditationState.leftNeckStretch;
        currentTimer = Timer(_settings.rightNeckRelaxation, _setNextState);
        _openEarable.audioPlayer.jingle(2);
        return;
      case MeditationState.leftNeckStretch:
        _settings.state = MeditationState.rightNeckStretch;
        currentTimer = Timer(_settings.rightNeckRelaxation, _setNextState);
        _openEarable.audioPlayer.jingle(2);
        return;
      case MeditationState.rightNeckStretch:
        _settings.state = MeditationState.noStretch;
        _openEarable.audioPlayer.jingle(2);
        return;
      default:
        return;
    }
  }
}
