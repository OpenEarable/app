import 'package:flutter/material.dart';
import 'package:open_earable/apps/driving_assistant/controller/tiredness_monitor.dart';
import 'package:open_earable/apps/driving_assistant/view/driving_assistant_view.dart';
import "package:open_earable/apps/posture_tracker/model/attitude.dart";
import 'package:open_earable/apps/posture_tracker/model/attitude_tracker.dart';
import 'package:open_earable_flutter/src/open_earable_flutter.dart';



class DrivingAssistantNotifier extends ChangeNotifier {
  Attitude _attitude = Attitude();
  Attitude get attitude => _attitude;

  bool get isTracking => _attitudeTracker.isTracking;
  bool get isAvailable => _attitudeTracker.isAvailable;

  late AttitudeTracker _attitudeTracker;
  late TirednessMonitor _monitor;

  TirednessMonitor get monitor => _monitor;

  DrivingAssistantNotifier(this._attitudeTracker, this._monitor) {
    _attitudeTracker.didChangeAvailability = (_) {
      notifyListeners();
    };

    _attitudeTracker.listen((attitude) {
      _attitude = Attitude(
          roll: attitude.roll,
          pitch: attitude.pitch,
          yaw: attitude.yaw
      );
      notifyListeners();
    });
  }

  void startTracking(DrivingAssistantView view) {
    _attitudeTracker.start();
    _monitor.registerObserver(view);
    notifyListeners();
  }

  void stopTracking(DrivingAssistantView view) {
    _attitudeTracker.stop();
    _monitor.removeObserver(view);
    notifyListeners();
  }
}