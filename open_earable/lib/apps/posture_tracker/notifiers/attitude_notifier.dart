// ignore_for_file: unnecessary_this

import "package:flutter/material.dart";
import "package:open_earable/apps/posture_tracker/model/attitude.dart";
import "package:open_earable/apps/posture_tracker/model/attitude_tracker.dart";

class AttitudeNotifier extends ChangeNotifier {
  Attitude _attitude = Attitude();
  Attitude get attitude => this._attitude;

  AttitudeTracker _attitudeTracker;

  AttitudeNotifier(this._attitudeTracker) {
    this._attitudeTracker.listen((attitude) {
      this._attitude = attitude;
      notifyListeners();
    });
  }
}