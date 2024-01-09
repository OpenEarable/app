import "package:flutter/material.dart";
import "package:open_earable/apps/star_finder/model/attitude.dart";
import 'package:open_earable/apps/star_finder/model/attitude_tracker.dart';
import "package:open_earable/apps/star_finder/model/right_direction.dart";
import "package:open_earable/apps/star_finder/model/star_object.dart";

/// ViewModel for the Star Finder app.
class StarFinderViewModel extends ChangeNotifier {
  Attitude _attitude = Attitude(); // The current attitude (orientation) of the device
  Attitude get attitude => _attitude; // Getter for the current attitude

  bool get isTracking => _attitudeTracker.isTracking; // Delegate to the attitude tracker to check if tracking is active
  bool get isAvailable => _attitudeTracker.isAvailable; // Delegate to the attitude tracker to check if tracking is available

  StarObject get starObject => _rightDirection.starObject; // Getter for the current star object being tracked
  RightDirection get rightDirection => _rightDirection; // Getter for the RightDirection instance

  AttitudeTracker _attitudeTracker; // Instance of AttitudeTracker to track the device's attitude
  RightDirection _rightDirection; // Instance of RightDirection to manage direction tracking towards a star object

  StarFinderViewModel(this._attitudeTracker, this._rightDirection) {
    _attitudeTracker.didChangeAvailability = (_) {
      notifyListeners(); // Notify listeners when availability changes
    };

    _attitudeTracker.listen((attitude) {
      _attitude = Attitude(
          roll: attitude.roll, pitch: attitude.pitch, yaw: attitude.yaw);
      notifyListeners(); // Notify listeners when a new attitude is received
    });
  }

  /// Starts the tracking of attitude and direction
  void startTracking() {
    _attitudeTracker.start();
    _rightDirection.start();
    notifyListeners(); // Notify listeners when tracking starts
  }

  /// Stops the tracking of attitude and direction
  void stopTracking() {
    _attitudeTracker.stop();
    _rightDirection.stop();
    notifyListeners(); // Notify listeners when tracking stops
  }

  /// Calibrates the attitude tracker to the current attitude
  void calibrate() {
    _attitudeTracker.calibrateToCurrentAttitude();
  }

  /// Sets a new star object for direction tracking
  void setStarObject(StarObject starObject) {
    _rightDirection.setStarObject(starObject);
    notifyListeners();
  }

  @override
  /// Disposes the ViewModel, stopping the tracking and releasing resources
  void dispose() {
    stopTracking();
    _attitudeTracker.cancle(); // Cancels the attitude tracker stream
    super.dispose();
  }
}
