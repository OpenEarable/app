import 'dart:collection';

import 'package:open_earable/apps/driving_assistant/controller/data_point.dart';
import 'package:open_earable/apps/driving_assistant/controller/search_pattern.dart';
import 'package:open_earable/apps/driving_assistant/controller/subject.dart';
import 'package:open_earable/apps/driving_assistant/view/driving_assistant_view.dart';
import 'package:open_earable/apps/driving_assistant/view/observer.dart';
import 'package:open_earable_flutter/src/open_earable_flutter.dart';

import '../model/base_attitude_tracker.dart';


class TrackingSettings {
  int timeBetweenDataPoints;
  int numberOfDataPoints;
  int gyroYThreshold;

  TrackingSettings({
    required this.timeBetweenDataPoints,
    required this.numberOfDataPoints,
    required this.gyroYThreshold,
  });
}

class TirednessMonitor implements Subject {
  //final DrivingAssistantView _view;
  final OpenEarable _openEarable;
  final BaseAttitudeTracker _attitudeTracker;
  final LinkedList<DataPoint> _allDataPoints = new LinkedList<DataPoint>();
  List<Observer> _observerList = new List<Observer>.empty(growable: true);
  late TrackingSettings _settings;

  TrackingSettings get settings => _settings;

  TirednessMonitor(this._openEarable, this._attitudeTracker);

  void start() {
    _settings = TrackingSettings(
      timeBetweenDataPoints: 2,
      numberOfDataPoints: 30,
      gyroYThreshold: 9,
    );

    print("test");

    int _tirednessCounter = 0;
    DateTime lastReading = DateTime.now();
    notifyObservers(_tirednessCounter);
    _attitudeTracker.listen((attitude) {
      if (DateTime.now().difference(lastReading).inSeconds >=
          _settings.timeBetweenDataPoints) {
        //Update linked list with DataPoints
        notifyObservers(_tirednessCounter);
        //print("gyroY: " + attitude.gyroY.toString());
        if(SearchPattern.tirednessCheck(attitude.gyroY, _settings)){
          lastReading = DateTime.now();
          print("SUCCESS: " + attitude.gyroY.toString());
          alarm();
          _tirednessCounter++;
          print(_tirednessCounter.toString());
          notifyObservers(_tirednessCounter);
        }
      }
    });
  }

  DataPoint _createDataPoint(attitude){
    return DataPoint(
        false,
        attitude.yaw.abs(),
        attitude.pitch.abs(),
        attitude.roll.abs()
    );
  }

  void alarm() {
    print("playing jingle to alert of tiredness");
    _openEarable.audioPlayer.jingle(1);
  }

  @override
  void notifyObservers(int tirednessCounter) {
    for(Observer observer in _observerList){
      observer.update(tirednessCounter);
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
