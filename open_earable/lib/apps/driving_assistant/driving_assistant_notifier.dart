import 'package:flutter/material.dart';
import 'package:open_earable/apps/driving_assistant/controller/tiredness_monitor.dart';
import 'package:open_earable/apps/driving_assistant/view/driving_assistant_view.dart';
import 'package:open_earable_flutter/src/open_earable_flutter.dart';

import 'model/base_attitude_tracker.dart';
import 'model/driving_attitude.dart';

class DrivingAssistantNotifier extends ChangeNotifier {
  DrivingAttitude _attitude = DrivingAttitude();
  DrivingAttitude get attitude => _attitude;

  bool get isTracking => _attitudeTracker.isTracking;
  bool get isAvailable => _attitudeTracker.isAvailable;

  late BaseAttitudeTracker _attitudeTracker;
  late TirednessMonitor _monitor;

  TirednessMonitor get monitor => _monitor;

  DrivingAssistantNotifier(this._attitudeTracker, this._monitor) {
    _attitudeTracker.didChangeAvailability = (_) {
      notifyListeners();
    };
    _attitudeTracker.listen((DrivingAttitude attitude) {
      _attitude = DrivingAttitude(
          roll: attitude.roll,
          pitch: attitude.pitch,
          yaw: attitude.yaw,
          gyroY: attitude.gyroY
      );
      notifyListeners();
    });
  }

  void startTracking(DrivingAssistantView view) {
    _attitudeTracker.start();
    _monitor.registerObserver(view);
    _monitor.start();
    notifyListeners();
  }

  void stopTracking(DrivingAssistantView view) {
    _attitudeTracker.stop();
    _monitor.removeObserver(view);
    notifyListeners();
  }

  void setTrackingSettings(TrackingSettings settings) {
    _monitor.setSettings(settings);
  }

  void calibrate() {
    _attitudeTracker.calibrateToCurrentDrivingAttitude();
  }
}