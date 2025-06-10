import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:open_wearable/apps/posture_tracker/model/attitude_tracker.dart';
import 'package:open_wearable/apps/posture_tracker/model/bad_posture_user_notifier.dart';

import 'attitude.dart';

class BadPostureSettings {
  bool isActive;

  /// The roll angle threshold in degrees
  int rollAngleThreshold;

  /// The pitch angle threshold in degrees
  int pitchAngleThreshold;

  /// The time threshold in seconds
  int timeThreshold;

  /// The time threshold in seconds for resetting the timer
  int resetTimeThreshold;

  BadPostureSettings({
    this.isActive = true,
    required this.rollAngleThreshold,
    required this.pitchAngleThreshold,
    required this.timeThreshold,
    required this.resetTimeThreshold,
  });
}

class PostureTimestamps {
  DateTime? lastBadPosture;
  DateTime? lastGoodPosture;
  DateTime lastReset = DateTime.now();
}

class BadPostureReminder {
  BadPostureSettings _settings = BadPostureSettings(
    rollAngleThreshold: 20,
    pitchAngleThreshold: 20,
    timeThreshold: 10,
    resetTimeThreshold: 1,
  );

  // final OpenEarable _openEarable;
  final AttitudeTracker _attitudeTracker;
  final BadPostureUserNotifier? _badPostureUserNotifier;
  final PostureTimestamps _timestamps = PostureTimestamps();

  BadPostureSettings get settings => _settings;

  BadPostureReminder({
    required AttitudeTracker attitudeTracker,
    BadPostureUserNotifier? badPostureUserNotifier,
  })  : _attitudeTracker = attitudeTracker,
        _badPostureUserNotifier = badPostureUserNotifier;

  bool? _lastPostureWasBad;

  void start() {
    _timestamps.lastReset = DateTime.now();
    _timestamps.lastBadPosture = null;
    _timestamps.lastGoodPosture = null;

    _attitudeTracker.listen((attitude) {
      if (!_settings.isActive) {
        _timestamps.lastBadPosture = null;
        _timestamps.lastGoodPosture = null;
        return;
      }

      DateTime now = DateTime.now();
      if (_isBadPosture(attitude)) {
        if (!(_lastPostureWasBad ?? false)) {
          _badPostureUserNotifier?.notifyUser();
        }

        // If this is the first time the program enters the bad state, store the current time
        if (_timestamps.lastBadPosture == null) {
          _timestamps.lastBadPosture = now;
        }
        // Otherwise, check how long the program has been in the bad state
        else {
          // Calculate the duration in seconds
          int duration = now.difference(_timestamps.lastBadPosture!).inSeconds;
          // If the duration exceeds the maximum allowed, call the alarm and reset the last bad state time
          if (duration > _settings.timeThreshold) {
            alarm();
            _timestamps.lastBadPosture = null;
          }
        }
        // Reset the last good state time
        _timestamps.lastGoodPosture = null;
      } else {
        if (_lastPostureWasBad ?? false) {
          _badPostureUserNotifier?.notifyUser(badPosture: false);
        }

        // If this is the first time the program enters the good state, store the current time
        if (_timestamps.lastGoodPosture == null) {
          _timestamps.lastGoodPosture = now;
        }
        // Otherwise, check how long the program has been in the good state
        else {
          // Calculate the duration in seconds
          int duration = now.difference(_timestamps.lastGoodPosture!).inSeconds;
          // If the duration exceeds the minimum required, reset the last bad state time
          if (duration >= _settings.resetTimeThreshold) {
            if (kDebugMode) {
              // Print debug information
              print(
                "duration: $duration, reset time threshold: ${_settings.resetTimeThreshold}",
              );
              print("resetting last bad posture time");
            }
            _timestamps.lastBadPosture = null;
          }
        }
      }
      _lastPostureWasBad = _isBadPosture(attitude);
    });
  }

  void stop() {
    _timestamps.lastBadPosture = null;
    _timestamps.lastGoodPosture = null;
    _badPostureUserNotifier?.stop();
    _attitudeTracker.stop();
  }

  void setSettings(BadPostureSettings settings) {
    _settings = settings;
  }

  bool _isBadPosture(Attitude attitude) {
    return attitude.roll.abs() * (360 / (2 * pi)) >
            _settings.rollAngleThreshold ||
        attitude.pitch.abs() * (360 / (2 * pi)) > _settings.pitchAngleThreshold;
  }

  void alarm() {
    _badPostureUserNotifier?.alarm();
  }
}
