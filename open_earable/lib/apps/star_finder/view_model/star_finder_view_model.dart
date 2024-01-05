import "package:flutter/material.dart";
import "package:open_earable/apps/star_finder/model/attitude.dart";
import 'package:open_earable/apps/star_finder/model/attitude_tracker.dart';
import "package:open_earable/apps/star_finder/model/right_direction.dart";
import "package:open_earable/apps/star_finder/model/star_object.dart";

class StarFinderViewModel extends ChangeNotifier {
  Attitude _attitude = Attitude();
  Attitude get attitude => _attitude;

  bool get isTracking => _attitudeTracker.isTracking;
  bool get isAvailable => _attitudeTracker.isAvailable;

  StarObject get starObject => _rightDirection.starObject;

  AttitudeTracker _attitudeTracker;
  RightDirection _rightDirection;

  StarFinderViewModel(this._attitudeTracker, this._rightDirection) {
    _attitudeTracker.didChangeAvailability = (_) {
      notifyListeners();
    };

    _attitudeTracker.listen((attitude) {
      _attitude = Attitude(
        x: attitude.x,
        y: attitude.y,
        z: attitude.z
      );
      notifyListeners();
    });
  }

  void startTracking() {
    _attitudeTracker.start();
    _rightDirection.start();
    notifyListeners();
  }

  void stopTracking() {
    _attitudeTracker.stop();
    _rightDirection.stop();
    notifyListeners();
  }

  void calibrate() {
    _attitudeTracker.calibrateToCurrentAttitude();
  }

  void setStarObject(StarObject starObject) {
    _rightDirection.setStarObject(starObject);
  }

  @override
  void dispose() {
    stopTracking();
    _attitudeTracker.cancle();
    super.dispose();
  }
}