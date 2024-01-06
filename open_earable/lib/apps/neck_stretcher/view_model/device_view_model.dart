import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:open_earable/apps/neck_stretcher/model/attitude.dart';
import 'package:open_earable/apps/neck_stretcher/model/attitude_tracker.dart';
import 'package:open_earable/apps/neck_stretcher/model/front_back_stretcher.dart';

/// change notifier to notify widget tree for front and back stretching
class DeviceViewModel extends ChangeNotifier {
  Attitude _attitude = Attitude();
  AttitudeTracker _attitudeTracker;
  FrontBackStretcher _frontBackStretcher;
  late FrontBackStretcherSettings _frontBackStretcherSettings;

  Attitude get attitude => _attitude;

  bool get isTracking => _attitudeTracker.isTracking;

  bool get isAvailable => _attitudeTracker.isAvailable;

  FrontBackStretcherSettings get stretcherSettings =>
      _frontBackStretcherSettings;

  bool? get timerActive => _timer?.isActive;

  /// variables for logic
  late int _maxSeconds;
  late int _seconds = _maxSeconds;
  Timer? _timer;
  bool _isRunning = false;
  String _instruction = "";
  int _counterBack = 0;
  int _counterFront = 0;
  bool _isStretching = false;

  String get instructionText => _instruction;

  bool get isStretching => _isStretching;

  int get seconds => _seconds;

  /**
   * constructor that initializes the attitude tracker (stream) and
   * front and back stretcher
   */
  DeviceViewModel(this._attitudeTracker, this._frontBackStretcher) {
    _attitudeTracker.didChangeAvailability = (_) {
      notifyListeners();
    };

    /// listen to changes in attitude
    _attitudeTracker.listen((attitude) {
      _attitude = Attitude(
          roll: attitude.roll, pitch: attitude.pitch, yaw: attitude.yaw);
      notifyListeners();
    });

    /// initializes settings and the maximum settings
    _frontBackStretcherSettings =
        _frontBackStretcher.frontBackStretcherSettings;
    _maxSeconds = _frontBackStretcherSettings.timeThreshold;
  }

  /// start tracking and stretching process
  void startTracking() {
    _attitudeTracker.start();
    _maxSeconds = _frontBackStretcherSettings.timeThreshold;
    startStretching();
    _instruction = "Tilt your head to the left or the right.";
    _counterBack = 0;
    _counterFront = 0;
    notifyListeners();
  }

  /// actions when user wants to stop tracking
  void stopTracking() {
    _attitudeTracker.stop();

    /// if both sides were stretched
    if (_counterFront > 0 && _counterBack > 0) {
      _instruction = "Finished Stretching!";
    } else {
      /// else no instruction
      _instruction = "";
    }

    _stopTimer();
    notifyListeners();
  }

  void calibrate() {
    _attitudeTracker.calibrateToCurrentAttitude();
  }

  void setStretcherSettings(FrontBackStretcherSettings settings) {
    _frontBackStretcher.setSettings(settings);
  }

  @override
  void dispose() {
    _attitudeTracker.cancel();
    super.dispose();
  }

  /// starts stretching process and reacts to changes in angles
  void startStretching() {
    _attitudeTracker.listen((attitude) {
      _isRunning = _timer == null ? false : _timer!.isActive;

      if (_backwardAngleReached(_attitude)) {
        /// if backward stretching was detected set stretching true
        _isStretching = true;

        /// if timer is not running and is not finished
        if (!_isRunning && _seconds != 0) {
          /// start timer and set backward stretching for counter when finished
          _startTimer(backwards: true);
          _instruction = "Stay in this position.";
        }
      } else if (_forwardAngleReached(_attitude)) {
        /// if forward stretching was detected
        _isStretching = true;

        /// if timer is not running and is not finished
        if (!_isRunning && _seconds != 0) {
          /// start timer and set forward stretching to true for counter
          _startTimer(forwards: true);
          _instruction = "Stay in this position.";
        }
      } else {
        if (_counterFront == 0 && _counterBack == 0) {
          /// if no side has been stretched
          _instruction = "Tilt your head to the front or the back.";
        }

        /// if one side has been stretched reset timer and set stretching to false
        _isStretching = false;
        _stopTimer(reset: true);
      }
    });
    notifyListeners();
  }

  /// computes if backward angle has been reached
  bool _backwardAngleReached(Attitude attitude) {
    return attitude.pitch * (360 / (2 * pi)) <
        _frontBackStretcherSettings.pitchAngleBackward;
  }

  /// computes if forward angle has been reached
  bool _forwardAngleReached(Attitude attitude) {
    return attitude.pitch * (360 / (2 * pi)) >
        _frontBackStretcherSettings.pitchAngleForward;
  }

  /**
   * starts timer with optional arguments: backwards and forwards
   * so that the counter can be set appropriately
   */
  void _startTimer({bool backwards = false, bool forwards = false}) {
    _timer = Timer.periodic(Duration(seconds: 1), (_) {
      if (_seconds > 0) {
        /// decrement seconds when timer is not done
        _seconds--;
      } else {
        /// if timer is done set appropriate counter
        if (backwards) {
          _counterBack++;
        }
        if (forwards) {
          _counterFront++;
        }

        /// play alarm
        _frontBackStretcher.alarm();

        _stopTimer();
        _instruction = "Tilt your head to the other side.";

        /// if both sides have been stretched stop the tracking
        if (_counterBack > 0 && _counterFront > 0) {
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

  /// reset timer to maximum allowed seconds
  void _resetTimer() => _seconds = _maxSeconds;
}
