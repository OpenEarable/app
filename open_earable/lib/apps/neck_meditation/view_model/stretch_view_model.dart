import "package:flutter/material.dart";
import "package:open_earable/apps/posture_tracker/model/attitude.dart";
import "package:open_earable/apps/posture_tracker/model/attitude_tracker.dart";
import 'package:open_earable/apps/neck_meditation/model/stretch_state.dart';

import 'package:open_earable_flutter/src/open_earable_flutter.dart';

class StretchViewModel extends ChangeNotifier {
  Attitude _attitude = Attitude();

  Attitude get attitude => _attitude;

  bool get isTracking => _attitudeTracker.isTracking;

  bool get isAvailable => _attitudeTracker.isAvailable;

  NeckMeditation get meditation => _meditation;

  StretchSettings get meditationSettings => _meditation.settings;

  NeckStretchState get meditationState => _meditation.settings.state;

  Duration get restDuration => _meditation.restDuration;

  bool get isResting => _meditation.resting;

  set meditationSettings(StretchSettings settings) => _meditation.settings = settings;

  AttitudeTracker _attitudeTracker;
  OpenEarable _openEarable;
  late NeckMeditation _meditation;

  StretchViewModel(this._attitudeTracker, this._openEarable) {
    _attitudeTracker.didChangeAvailability = (_) {
      notifyListeners();
    };

    this._meditation = NeckMeditation(_openEarable, this);
    _attitudeTracker.listen((attitude) {
      _attitude = Attitude(
          roll: attitude.roll,
          pitch: attitude.pitch,
          yaw: attitude.yaw
      );
      notifyListeners();
    });
  }

  void startTracking() {
    _attitudeTracker.start();
    notifyListeners();
  }

  void stopTracking() {
    _attitudeTracker.stop();
    _attitude = Attitude();
    notifyListeners();
  }

  void calibrate() {
    _attitudeTracker.calibrateToCurrentAttitude();
  }

  @override
  void dispose() {
    _attitudeTracker.cancle();
    super.dispose();
  }
}