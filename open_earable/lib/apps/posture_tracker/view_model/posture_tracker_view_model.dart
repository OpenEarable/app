import "package:flutter/material.dart";
import "package:open_earable/apps/posture_tracker/model/attitude.dart";
import 'package:open_earable/apps/posture_tracker/model/attitude_tracker.dart';
import "package:open_earable/apps/posture_tracker/model/bad_posture_reminder.dart";

class PostureTrackerViewModel extends ChangeNotifier {
  Attitude _attitude = Attitude();
  Attitude get attitude => _attitude;

  bool get isTracking => _attitudeTracker.isTracking;
  bool get isAvailable => _attitudeTracker.isAvailable;

  BadPostureSettings get badPostureSettings => _badPostureReminder.settings;

  AttitudeTracker _attitudeTracker;
  BadPostureReminder _badPostureReminder;

  PostureTrackerViewModel(this._attitudeTracker, this._badPostureReminder) {
    _attitudeTracker.didChangeAvailability = (_) {
      notifyListeners();
    };

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
    _badPostureReminder.start();
    notifyListeners();
  }

  void stopTracking() {
    _attitudeTracker.stop();
    notifyListeners();
  }

  void calibrate() {
    _attitudeTracker.calibrateToCurrentAttitude();
  }

  void setBadPostureSettings(BadPostureSettings settings) {
    _badPostureReminder.setSettings(settings);
  }

  @override
  void dispose() {
    _attitudeTracker.cancle();
    super.dispose();
  }
}