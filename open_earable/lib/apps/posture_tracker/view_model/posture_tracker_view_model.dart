// ignore_for_file: unnecessary_this

import "package:flutter/material.dart";
import "package:open_earable/apps/posture_tracker/model/attitude.dart";
import 'package:open_earable/apps/posture_tracker/model/attitude_tracker.dart';

class PostureTrackerViewModel extends ChangeNotifier {
  Attitude _attitude = Attitude();
  Attitude get attitude => this._attitude;

  AttitudeTracker _attitudeTracker;

  PostureTrackerViewModel(this._attitudeTracker) {
    this._attitudeTracker.listen((attitude) {
      this._attitude = attitude;
      notifyListeners();
    });
  }

  void startTracking() {
    this._attitudeTracker.start();
  }

  void stopTracking() {
    this._attitudeTracker.stop();
  }
}