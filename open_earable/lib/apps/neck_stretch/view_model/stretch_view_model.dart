import "package:flutter/material.dart";
import "package:open_earable/apps/posture_tracker/model/attitude.dart";
import "package:open_earable/apps/posture_tracker/model/attitude_tracker.dart";
import 'package:open_earable/apps/neck_stretch/model/stretch_state.dart';

import 'package:open_earable_flutter/src/open_earable_flutter.dart';

class StretchViewModel extends ChangeNotifier {
  Attitude _attitude = Attitude();

  /// Getters for the attitude-Tracker
  Attitude get attitude => _attitude;
  bool get isTracking => _attitudeTracker.isTracking;
  bool get isAvailable => _attitudeTracker.isAvailable;

  /// Getters for the neck stretch settings and state
  NeckStretch get neckStretch => _neckStretch;
  StretchSettings get stretchSettings => _neckStretch.settings;
  NeckStretchState get stretchState => _neckStretch.settings.state;
  Duration get restDuration => _neckStretch.restDuration;
  bool get isResting => _neckStretch.resting;

  /// Setter for the neck stretching settings
  set stretchSettings(StretchSettings settings) =>
      _neckStretch.settings = settings;

  AttitudeTracker _attitudeTracker;
  OpenEarable _openEarable;

  /// The model class containing all information and logics needed to start and handle a guided neck stretch
  late NeckStretch _neckStretch;

  StretchViewModel(this._attitudeTracker, this._openEarable) {
    _attitudeTracker.didChangeAvailability = (_) {
      notifyListeners();
    };

    this._neckStretch = NeckStretch(_openEarable, this);
    _attitudeTracker.listen((attitude) {
      _attitude = Attitude(
          roll: attitude.roll, pitch: attitude.pitch, yaw: attitude.yaw);
      notifyListeners();
    });
  }

  /// Starts tracking of the openEarable
  void startTracking() {
    _attitudeTracker.start();
    notifyListeners();
  }

  /// Stops tracking of the openEarable and resets the attitude for the headViews
  void stopTracking() {
    _attitudeTracker.stop();
    _attitude = Attitude();
    notifyListeners();
  }

  /// Used to calibrate the starting point for the head tracking
  void calibrate() {
    _attitudeTracker.calibrateToCurrentAttitude();
  }

  @override
  void dispose() {
    _attitudeTracker.cancle();
    super.dispose();
  }
}
