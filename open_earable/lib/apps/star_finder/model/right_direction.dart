import 'package:open_earable/apps/star_finder/model/attitude.dart';
import 'package:open_earable/apps/star_finder/model/star_object.dart';
import 'package:open_earable/apps/star_finder/model/attitude_tracker.dart';
import 'package:open_earable_flutter/src/open_earable_flutter.dart';

/// Manages the functionality to determine if the user is facing the right direction
/// towards a specific star object
class RightDirection {
  final OpenEarable _openEarable; // Interface to the OpenEarable device
  final AttitudeTracker _attitudeTracker; // Attitude tracker to get orientation data.
  StarObject _starObject; // The star object to find
  bool rightDirection = false; // Flag to indicate if the right direction is found
  DateTime lastScanTime = DateTime.now(); // Time of the last direction scan
  DateTime lastJingleTime = DateTime.now(); // Time of the last audio feedback

  StarObject get starObject => _starObject;

  RightDirection(this._openEarable, this._attitudeTracker, this._starObject);

  /// Starts listening to the attitude tracker and processes the orientation data
  void start() {
    _attitudeTracker.listen((attitude) {
      DateTime now = DateTime.now();
      // too fast scanning caused the LED and Audio to not work properly, thats why 0.25 sec duration between scans
      int duration = now.difference(lastScanTime).inMilliseconds;
      if (duration > 250) {
        lastScanTime = now;
        scan(attitude, now);
      }
    });
  }

  /// Stops listening to the attitude tracker and turns off the earable device's LED
  void stop() {
    _openEarable.rgbLed.writeLedColor(r: 0, g: 0, b: 0);
    _attitudeTracker.stop();
  }

  /// Determines if the current attitude aligns with the target star object within a tolerance (of 20/180 ~ 11%)
  bool inThisDirection(Attitude attitude) {
    double distanceX = (attitude.roll - _starObject.eulerAngle.roll).abs();
    double distanceY = (attitude.pitch - _starObject.eulerAngle.pitch).abs();
    double distanceZ = (attitude.yaw - _starObject.eulerAngle.yaw).abs();
    return distanceX < 10 && distanceY < 10.0 && distanceZ < 10.0;
  }
  
  /// Scans the current attitude and decides whether it's the right or wrong direction
  void scan(Attitude attitude, DateTime now) {
    if (inThisDirection(attitude)) {
      success(now);
    } else {
      fail();
    }
  }

  /// Handles successful alignment by setting the flag, changing LED color to green, and playing audio
  void success(DateTime now) {
    rightDirection = true;
    _openEarable.rgbLed.writeLedColor(r: 0, g: 255, b: 0);
    // for the jingle not to play too fast too often
    int duration = now.difference(lastJingleTime).inMilliseconds;
    if (duration > 900) {
      _openEarable.audioPlayer.jingle(2);
      lastJingleTime = now;
    }
  }

  /// Handles failure to align by resetting the flag and changing LED color to red
  void fail() {
    rightDirection = false;
    _openEarable.rgbLed.writeLedColor(r: 255, g: 0, b: 0);
  }

  /// Sets the target star object
  void setStarObject(StarObject starObject) {
    _starObject = starObject;
  }
}
