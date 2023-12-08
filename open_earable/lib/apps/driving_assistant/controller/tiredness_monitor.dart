import 'dart:collection';

import 'package:open_earable/apps/driving_assistant/controller/data_point.dart';
import 'package:open_earable/apps/driving_assistant/controller/search_pattern.dart';
import 'package:open_earable/apps/driving_assistant/controller/subject.dart';
import 'package:open_earable/apps/driving_assistant/view/driving_assistant_view.dart';
import 'package:open_earable/apps/driving_assistant/view/observer.dart';
import 'package:open_earable/apps/posture_tracker/model/attitude.dart';
import 'package:open_earable/apps/posture_tracker/model/attitude_tracker.dart';
import 'package:open_earable_flutter/src/open_earable_flutter.dart';


class TrackingSettings {
  int timeBetweenDataPoints;
  int numberOfDataPoints;
  int pitchAngleThreshold;

  TrackingSettings({
    required this.timeBetweenDataPoints,
    required this.numberOfDataPoints,
    required this.pitchAngleThreshold,
  });
}

class TirednessMonitor implements Subject {
  final OpenEarable _openEarable;
  final AttitudeTracker _attitudeTracker;
  final LinkedList<DataPoint> _allDataPoints = new LinkedList<DataPoint>();
  List<Observer> _observerList = new List<Observer>.empty(growable: true);

  TirednessMonitor(this._openEarable, this._attitudeTracker);

  void start() {
    TrackingSettings _settings = TrackingSettings(
      timeBetweenDataPoints: 100,
      numberOfDataPoints: 30,
      pitchAngleThreshold: 15,
    );

    int _tirednessCounter = 0;
    DateTime lastReading = DateTime.now();

    _attitudeTracker.listen((attitude) {
      if (DateTime.now().difference(lastReading).inMilliseconds >=
          _settings.timeBetweenDataPoints) {
        //Update linked list with DataPoints
        lastReading = DateTime.now();
        if(_allDataPoints.length >= _settings.numberOfDataPoints){
          _allDataPoints.remove(_allDataPoints.first);
        }
        _allDataPoints.add(_createDataPoint(attitude, _allDataPoints.last));

        //Check for pattern in current list of DataPoints
        for(DataPoint point in _allDataPoints){
          if(point.alerted == false && SearchPattern.tirednessCheck(point)){
            point.alerted = true;
            alarm();
            _tirednessCounter++;
            notifyObservers(_tirednessCounter);
          }
        }

      }
    });
  }

  DataPoint _createDataPoint(attitude, DataPoint previous){
    return DataPoint(
        false,
        attitude.yaw.abs(),
        attitude.pitch.abs(),
        attitude.roll.abs(),
        previous
    );
  }

  void alarm() {
    print("playing jingle to alert of tiredness");
    _openEarable.audioPlayer.jingle(4);
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
}
