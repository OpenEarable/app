import "dart:core";
import "dart:async";
import "package:flutter/material.dart";
import 'package:open_earable/apps_tab/posture_tracker/model/attitude.dart';
import 'package:open_earable/apps_tab/posture_tracker/model/attitude_tracker.dart';
import 'package:open_earable/apps_tab/neck_stretch/model/stretch_state.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart';

class StretchViewModel extends ChangeNotifier {
  Attitude _attitude = Attitude();

  /// Getters for the attitude-Tracker
  Attitude get attitude => _attitude;

  bool get isTracking => _attitudeTracker.isTracking;

  bool get isAvailable => _attitudeTracker.isAvailable;

  /// Getters for the neck stretch settings, state and stats
  NeckStretch get neckStretch => _neckStretch;

  StretchSettings get stretchSettings => _neckStretch.settings;

  NeckStretchState get stretchState => _neckStretch.settings.state;

  Duration get restDuration => _neckStretch.restDuration;

  bool get isResting => _neckStretch.resting;

  StretchStats get stretchStats => _stretchStats;

  /// Setter for the neck stretching settings
  set stretchSettings(StretchSettings settings) =>
      _neckStretch.settings = settings;

  final AttitudeTracker _attitudeTracker;
  final OpenEarable _openEarable;

  /// The model class containing all information and logics needed to start and handle a guided neck stretch
  late NeckStretch _neckStretch;
  late StretchStats _stretchStats;

  /// Timer that is used to track the current stretching stats, called every 0.01s
  late Timer _settingsTracker;

  StretchViewModel(this._attitudeTracker, this._openEarable) {
    _attitudeTracker.didChangeAvailability = (_) {
      notifyListeners();
    };

    _neckStretch = NeckStretch(_openEarable, this);
    _stretchStats = StretchStats();

    _attitudeTracker.listen((attitude) {
      _attitude = Attitude(
          roll: attitude.roll, pitch: attitude.pitch, yaw: attitude.yaw,);
      notifyListeners();
    });
  }

  /// Starts tracking of using OpenEarable
  void startTracking() {
    _attitudeTracker.start();
    _stretchStats.clear();
    _settingsTracker = Timer.periodic(Duration(milliseconds: 10), (timer) {
      _trackStretchStats();
    });
    notifyListeners();
  }

  /// Stops tracking of the OpenEarable and resets the attitude for the headViews
  void stopTracking() {
    _attitudeTracker.stop();
    _attitude = Attitude();
    _settingsTracker.cancel();
    notifyListeners();
  }

  /// Used to calibrate the starting point for the head tracking
  void calibrate() {
    _attitudeTracker.calibrateToCurrentAttitude();
  }

  @override
  void dispose() {
    _attitudeTracker.cancel();
    super.dispose();
  }

  /// Track the stretch stats according to current stretch state
  void _trackStretchStats() {
    /// If you are resting, don't track, only last refresh
    if (isResting) {
      return;
    }
    const toAngle = 180 / 3.14;
    switch (_neckStretch.settings.state) {
      case NeckStretchState.mainNeckStretch:
        _stretchStats.maxMainAngle =
            _attitude.pitch > _stretchStats.maxMainAngle
                ? _attitude.pitch
                : _stretchStats.maxMainAngle;

        /// Sets the stretch duration
        if ((_attitude.pitch * toAngle) >=
            _neckStretch.settings.forwardStretchAngle) {
          _stretchStats.mainStretchDuration += 0.01;
        }
        return;
      case NeckStretchState.rightNeckStretch:
        _stretchStats.maxRightAngle =
            -_attitude.roll > _stretchStats.maxRightAngle
                ? -_attitude.roll
                : _stretchStats.maxRightAngle;

        /// Sets the stretch duration
        if ((-_attitude.roll * toAngle) >=
            _neckStretch.settings.sideStretchAngle) {
          _stretchStats.rightStretchDuration += 0.01;
        }
        return;
      case NeckStretchState.leftNeckStretch:
        _stretchStats.maxLeftAngle = _attitude.roll > _stretchStats.maxLeftAngle
            ? _attitude.roll
            : _stretchStats.maxLeftAngle;

        /// Sets the stretch duration
        if (_attitude.roll * toAngle >=
            _neckStretch.settings.sideStretchAngle) {
          _stretchStats.leftStretchDuration += 0.01;
        }
        return;
      default:
        return;
    }
  }
}
