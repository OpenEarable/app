import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:open_earable/apps/neck_stretcher/model/attitude.dart';
import 'package:open_earable/apps/neck_stretcher/model/attitude_tracker.dart';
import 'package:open_earable/apps/neck_stretcher/model/side_stretcher.dart';

/// change notifier for widget tree of side to side stretching
class StretcherViewModel extends ChangeNotifier {
  Attitude _attitude = Attitude();
  AttitudeTracker _attitudeTracker;
  SideStretcher _sideStretcher;
  late SideStretcherSettings _sideStretcherSettings;

  Attitude get attitude => _attitude;

  bool get isTracking => _attitudeTracker.isTracking;

  bool get isAvailable => _attitudeTracker.isAvailable;

  SideStretcherSettings get stretcherSettings => _sideStretcherSettings;

  bool? get timerActive => _timer?.isActive;

  /// class variables
  late int _maxSeconds;
  late int _seconds = _maxSeconds;
  Timer? _timer;
  bool _isRunning = false;
  String _instruction = "";
  int _counterLeft = 0;
  int _counterRight = 0;

  String get instructionText => _instruction;

  bool _isStretching = false;

  bool get isStretching => _isStretching;

  int get seconds => _seconds;

  /**
   * constructor that initializes the attitude tracker (stream) and
   * side to side stretcher
   */
  StretcherViewModel(this._attitudeTracker, this._sideStretcher) {
    _attitudeTracker.didChangeAvailability = (_) {
      notifyListeners();
    };

    /// listen to changes in the attitude
    _attitudeTracker.listen((attitude) {
      _attitude = Attitude(
          roll: attitude.roll, pitch: attitude.pitch, yaw: attitude.yaw);
      notifyListeners();
    });

    /// initialize settings and maximum seconds for the timer
    _sideStretcherSettings = _sideStretcher.sideSettings;
    _maxSeconds = _sideStretcherSettings.timeThreshold;
  }

  /// start the tracking process and stretching
  void startTracking() {
    _attitudeTracker.start();
    _maxSeconds = _sideStretcherSettings.timeThreshold;
    startStretching();
    _instruction = "Tilt your head to the left or the right.";
    _counterLeft = 0;
    _counterRight = 0;
    notifyListeners();
  }

  /// stop tracking process
  void stopTracking() {
    _attitudeTracker.stop();

    /// instruction depends on whether stretching is finished or not
    if (_counterLeft > 0 && _counterRight > 0) {
      _instruction = "Finished Stretching!";
    } else {
      _instruction = "";
    }

    _stopTimer();
    notifyListeners();
  }

  void calibrate() {
    _attitudeTracker.calibrateToCurrentAttitude();
  }

  void setStretcherSettings(SideStretcherSettings settings) {
    _sideStretcher.setSettings(settings);
  }

  @override
  void dispose() {
    _attitudeTracker.cancel();
    super.dispose();
  }

  /// start stretching by detecting changes in angles
  void startStretching() {
    _attitudeTracker.listen((attitude) {
      _isRunning = _timer == null ? false : _timer!.isActive;

      if (_rightAngleReached(_attitude)) {
        /// if right angle is detected
        _isStretching = true;
        if (!_isRunning && _seconds != 0) {
          /// if timer is not running and not finished
          _startTimer(right: true);
          _instruction = "Stay in this position.";
        }
      } else if (_leftAngleReached(_attitude)) {
        /// if left angle was detected
        _isStretching = true;
        if (!_isRunning && _seconds != 0) {
          /// if timer is not running and not finished
          _startTimer(left: true);
          _instruction = "Stay in this position.";
        }
      } else {
        if (_counterLeft == 0 && _counterRight == 0) {
          /// if no side was stretched
          _instruction = "Tilt your head to the left or the right.";
        }
        _isStretching = false;

        /// stops timer and resets
        _stopTimer(reset: true);
      }
    });
    notifyListeners();
  }

  /// computes if right angle was reached
  bool _rightAngleReached(Attitude attitude) {
    return attitude.roll * (360 / (2 * pi)) >
        _sideStretcherSettings.rollAngleRight;
  }

  /// computes if left angle was reached
  bool _leftAngleReached(Attitude attitude) {
    return attitude.roll * (360 / (2 * pi)) <
        _sideStretcherSettings.rollAngleLeft;
  }

  void _startTimer({bool right = false, bool left = false}) {
    _timer = Timer.periodic(Duration(seconds: 1), (_) {
      if (_seconds > 0) {
        /// if timer is not done decrement seconds
        _seconds--;
      } else {
        /// set appropriate counter for the sides
        if (right) {
          _counterRight++;
        }
        if (left) {
          _counterLeft++;
        }

        /// play alarm for the end of stretching
        _sideStretcher.alarm();

        _stopTimer();
        _instruction = "Tilt your head to the other side.";
        if (_counterRight > 0 && _counterLeft > 0) {
          /// if both sides were stretched end the stretching
          stopTracking();
        }
      }
    });
    notifyListeners();
  }

  /// stop timer with reset option
  void _stopTimer({bool reset = false}) {
    if (reset) {
      _resetTimer();
    }
    _timer?.cancel();
    notifyListeners();
  }

  void _resetTimer() => _seconds = _maxSeconds;
}
