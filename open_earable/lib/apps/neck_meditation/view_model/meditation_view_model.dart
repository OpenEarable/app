import "package:flutter/material.dart";
import "package:open_earable/apps/posture_tracker/model/attitude.dart";
import "package:open_earable/apps/posture_tracker/model/attitude_tracker.dart";
import 'package:open_earable/apps/neck_meditation/model/meditation_state.dart';

import 'package:open_earable_flutter/src/open_earable_flutter.dart';

class MeditationViewModel extends ChangeNotifier {
  Attitude _attitude = Attitude();

  Attitude get attitude => _attitude;

  bool get isTracking => _attitudeTracker.isTracking;

  bool get isAvailable => _attitudeTracker.isAvailable;

  NeckMeditation get meditation => _meditation;

  MeditationSettings get meditationSettings => _meditation.settings;

  MeditationState get meditationState => this._meditation.settings.state;

  AttitudeTracker _attitudeTracker;
  OpenEarable _openEarable;
  late NeckMeditation _meditation;

  MeditationViewModel(this._attitudeTracker, this._openEarable) {
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

  Duration getRestDuration() {
    return _meditation.getRestDuration();
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

  /// Used to set the Duration Settings for Meditation
  void setMeditationSettings(MeditationSettings settings) {
    _meditation.setSettings(settings);
  }

  @override
  void dispose() {
    _attitudeTracker.cancle();
    super.dispose();
  }
}