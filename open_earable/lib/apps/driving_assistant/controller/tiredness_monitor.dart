import 'dart:ui';

import 'package:flutter/src/material/colors.dart';
import 'package:open_earable/apps/driving_assistant/controller/search_pattern.dart';
import 'package:open_earable/apps/driving_assistant/controller/subject.dart';
import 'package:open_earable/apps/driving_assistant/view/observer.dart';
import 'package:open_earable_flutter/src/open_earable_flutter.dart';

import '../model/base_attitude_tracker.dart';

class TrackingSettings {
  int timeOffset;
  int gyroYThreshold;
  int timesToYellow;
  int timesToRed;

  TrackingSettings(
      {required this.timeOffset,
      required this.gyroYThreshold,
      required this.timesToYellow,
      required this.timesToRed});
}

class TirednessMonitor implements Subject {
  //final DrivingAssistantView _view;
  final OpenEarable _openEarable;
  final BaseAttitudeTracker _attitudeTracker;
  List<Observer> _observerList = new List<Observer>.empty(growable: true);
  late TrackingSettings _settings;

  TrackingSettings get settings => _settings;

  TirednessMonitor(this._openEarable, this._attitudeTracker) {
    _settings = TrackingSettings(
        timeOffset: 2, gyroYThreshold: 9, timesToYellow: 2, timesToRed: 4);
  }

  void start() {
    int _tirednessCounter = 0;
    DateTime lastReading = DateTime.now();
    notifyObservers(_tirednessCounter);
    _attitudeTracker.listen((attitude) {
      if (DateTime.now().difference(lastReading).inSeconds >=
          _settings.timeOffset) {
        notifyObservers(_tirednessCounter);
        if (SearchPattern.tirednessCheck(attitude.gyroY, _settings)) {
          lastReading = DateTime.now();
          alarm();
          _tirednessCounter++;
          notifyObservers(_tirednessCounter);
        }
      }
    });
  }

  void alarm() {
    print("playing jingle to alert of tiredness");
    _openEarable.audioPlayer.jingle(1);
  }

  @override
  void notifyObservers(int tirednessCounter) {
    Color mugColor = Colors.green;
    if (tirednessCounter < settings.timesToYellow) {
      mugColor = Colors.green;
    } else if (tirednessCounter < settings.timesToRed) {
      mugColor = Colors.yellow;
    } else {
      mugColor = Colors.red;
    }
    for (Observer observer in _observerList) {
      observer.update(mugColor);
    }
  }

  @override
  void registerObserver(Observer observer) {
    _observerList.add(observer);
  }

  @override
  void removeObserver(Observer observer) {
    _observerList.remove(observer);
  }

  void setSettings(TrackingSettings settings) {
    _settings = settings;
  }
}
