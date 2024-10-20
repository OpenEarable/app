import "package:flutter/material.dart";
import 'package:open_earable/apps_tab/posture_tracker/model/attitude.dart';
import 'package:open_earable/apps_tab/posture_tracker/model/attitude_tracker.dart';
import 'package:open_earable/apps_tab/posture_tracker/model/bad_posture_reminder.dart';

class PostureTrackerViewModel extends ChangeNotifier {
  Attitude _attitude = Attitude();
  Attitude get attitude => _attitude;

  bool get isTracking => _attitudeTracker.isTracking;
  bool get isAvailable => _attitudeTracker.isAvailable;

  BadPostureSettings get badPostureSettings => _badPostureReminder.settings;

  final AttitudeTracker _attitudeTracker;
  final BadPostureReminder _badPostureReminder;
  bool _isDisposed = false;
  PostureTrackerViewModel(this._attitudeTracker, this._badPostureReminder) {
    _attitudeTracker.didChangeAvailability = (_) {
      if (!_isDisposed) {
        notifyListeners();
      }
    };

    _attitudeTracker.listen((attitude) {
      _attitude = Attitude(
          roll: attitude.roll, pitch: attitude.pitch, yaw: attitude.yaw,);
      if (!_isDisposed) {
        notifyListeners();
      }
    });
  }

  void startTracking() {
    _attitudeTracker.start();
    _badPostureReminder.start();
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  void stopTracking() {
    _attitudeTracker.stop();
    _badPostureReminder.stop();
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  void calibrate() {
    _attitudeTracker.calibrateToCurrentAttitude();
  }

  void setBadPostureSettings(BadPostureSettings settings) {
    _badPostureReminder.setSettings(settings);
  }

  @override
  void dispose() {
    stopTracking();
    _attitudeTracker.cancel();
    _isDisposed = true;
    super.dispose();
  }
}
