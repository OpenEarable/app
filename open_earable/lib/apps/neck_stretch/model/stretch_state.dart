import 'dart:async';

import 'package:open_earable/apps/neck_stretch/view_model/stretch_view_model.dart';
import 'package:open_earable_flutter/src/open_earable_flutter.dart';

/// Enum for the neck stretch states
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
        return 'Left Neck Area';
      case NeckStretchState.rightNeckStretch:
        return 'Right Neck Area';
      case NeckStretchState.noStretch:
        return 'Not Stretching';
      default:
        return 'Done Stretching';
    }
  }

  /// Gets the corresponding asset path for the front neck image
  String get assetPathNeckFront {
    switch (this) {
      case NeckStretchState.rightNeckStretch:
        return 'assets/neck_stretch/Neck_Right_Stretch.png';
      case NeckStretchState.leftNeckStretch:
        return 'assets/neck_stretch/Neck_Left_Stretch.png';
      default:
        return 'assets/posture_tracker/Neck_Front.png';
    }
  }

  /// Gets the corresponding asset path for the side eck image
  String get assetPathNeckSide {
    switch (this) {
      case NeckStretchState.mainNeckStretch:
        return 'assets/neck_stretch/Neck_Main_Stretch.png';
      default:
        return 'assets/posture_tracker/Neck_Side.png';
    }
  }

  /// Gets the corresponding asset path for the Head Front Image
  String get assetPathHeadFront {
    return 'assets/posture_tracker/Head_Front.png';
  }

  /// Gets the corresponding asset path for the Head Side Image
  String get assetPathHeadSide {
    return 'assets/posture_tracker/Head_Side.png';
  }
}

/// Stores all settings needed to manage a stretching session
class StretchSettings {
  NeckStretchState state;

  /// Duration for the main neck relaxation
  Duration mainNeckRelaxation;

  /// Duration for the left neck relaxation
  Duration leftNeckRelaxation;

  /// Duration for the right neck relaxation
  Duration rightNeckRelaxation;

  /// Time used for resting between each set
  Duration restingTime;

  /// Angle used for stretching forward
  double forwardStretchAngle;

  /// Angle used for stretching sideways
  double sideStretchAngle;

  /// The stretch settings containing duration timers and state
  StretchSettings({
    this.state = NeckStretchState.noStretch,
    required this.mainNeckRelaxation,
    required this.leftNeckRelaxation,
    required this.rightNeckRelaxation,
    required this.restingTime,
    required this.forwardStretchAngle,
    required this.sideStretchAngle,
  });
}

/// Stores all data and functions to manage the guided neck meditation
class NeckStretch {
  StretchSettings _settings = StretchSettings(
      mainNeckRelaxation: Duration(seconds: 30),
      leftNeckRelaxation: Duration(seconds: 30),
      rightNeckRelaxation: Duration(seconds: 30),
      restingTime: Duration(seconds: 5),
      forwardStretchAngle: 45,
      sideStretchAngle: 30);

  final OpenEarable _openEarable;
  final StretchViewModel _viewModel;

  /// Defines whether you are currently resting between two stretch exercises
  late bool _resting;

  /// Holds the Timer that increments the current Duration
  var _restDurationTimer;

  /// Stores the rest duration of the current timer
  late Duration _restDuration;

  /// Stores the current active timer for state transition
  var _currentTimer;

  StretchSettings get settings => _settings;

  Duration get restDuration => _restDuration;

  bool get resting => _resting;

  set settings(StretchSettings settings) => _settings = settings;

  NeckStretch(this._openEarable, this._viewModel) {
    this._restDuration = Duration(seconds: 0);
    this._resting = false;
  }

  /// Starts the Meditation with the according timers
  void startStretching() {
    _resting = false;
    _viewModel.startTracking();
    _settings.state = NeckStretchState.noStretch;
    _setNextState();
  }

  /// Stops the current Meditation
  void stopStretching() {
    _resting = false;
    _settings.state = NeckStretchState.noStretch;
    _currentTimer.cancel();
    _restDurationTimer.cancel();
    _restDuration = Duration(seconds: 0);
    _viewModel.stopTracking();
  }

  /// Starts the countdown for restDuration
  void _startCountdown() {
    _restDurationTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      _restDuration -= Duration(seconds: 1);
    });
  }

  /// Sets the state and timers for the state.
  void _setState(NeckStretchState state, Duration stateDuration) {
    _settings.state = state;
    // If you just swapped to this state, first rest for restingTime, then set new state
    if (_resting) {
      /// If we don't restart the timer it results in a weird UI inconsistency
      /// for displaying the _restDuration as then the restDuration is already
      /// counted down when the next Timer hasn't started yet.
      _restDurationTimer.cancel();
      _startCountdown();
      _restDuration = _settings.restingTime;
      _currentTimer = Timer(_settings.restingTime, () {
        _resting = false;
        _setState(state, stateDuration);
        _openEarable.audioPlayer.jingle(8);
      });
    } else {
      _restDuration = stateDuration;
      _currentTimer = Timer(stateDuration, _setNextState);
    }
  }

  /// Used to set the next stretch state and set the correct Timers
  void _setNextState() {
    switch (_settings.state) {
      case NeckStretchState.noStretch:
      case NeckStretchState.doneStretching:
        _startCountdown();
        _setState(
            NeckStretchState.mainNeckStretch, _settings.mainNeckRelaxation);
        return;
      case NeckStretchState.mainNeckStretch:
        _resting = true;
        _setState(
            NeckStretchState.rightNeckStretch, _settings.rightNeckRelaxation);
        _openEarable.audioPlayer.jingle(2);
        return;
      case NeckStretchState.rightNeckStretch:
        _resting = true;
        _setState(
            NeckStretchState.leftNeckStretch, _settings.leftNeckRelaxation);
        _openEarable.audioPlayer.jingle(2);
        return;
      case NeckStretchState.leftNeckStretch:
        _settings.state = NeckStretchState.doneStretching;
        _currentTimer.cancel();
        _restDurationTimer.cancel();
        _restDuration = Duration(seconds: 0);
        _viewModel.stopTracking();
        _openEarable.audioPlayer.jingle(2);
        return;
      default:
        return;
    }
  }
}
