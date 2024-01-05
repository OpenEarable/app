import 'dart:async';
import 'dart:math';

import 'package:open_earable/apps/star_finder/model/attitude.dart';
import 'package:open_earable/apps/star_finder/model/star_object.dart';
import 'package:open_earable/apps/star_finder/model/attitude_tracker.dart';
import 'package:open_earable/apps/star_finder/model/ewma.dart';
import 'package:open_earable_flutter/src/open_earable_flutter.dart';



class RightDirection {
  final OpenEarable _openEarable;
  final AttitudeTracker _attitudeTracker;
  StarObject starObject;
  DateTime lastScanTime = DateTime.now();
  DateTime lastJingleTime = DateTime.now();

  RightDirection(this._openEarable, this._attitudeTracker, this.starObject);

  void start() {
   _attitudeTracker.listen((attitude) {

    print("attitudeTracker");

    //scan every 0.5 sec
    DateTime now = DateTime.now();
    
    print("${now} before difference");
    print("${lastScanTime} before difference");
    int duration = now.difference(lastScanTime).inMilliseconds;
    print(duration);
    if (duration > 250){
      print("newScan");
      lastScanTime = now;
      scan(attitude, now);
    }
    
   });
  }

  void stop() {
    _openEarable.rgbLed.writeLedColor(r: 0, g: 0, b: 0);
    _attitudeTracker.stop();
  }

  bool _isRightDirection(Attitude attitude, StarObject starObject) {
    print(starObject.calculateDistance(attitude.x, attitude.y, attitude.z)); 
    return (starObject.calculateDistance(attitude.x, attitude.y, attitude.z)) < 100.0;
  }

  void scan(Attitude attitude, DateTime now) {
    if (_isRightDirection(attitude, starObject)){
      success(now);
    }
    else {
      print("red");
      _openEarable.rgbLed.writeLedColor(r: 255, g: 0, b: 0);
    }
  }

  void success(DateTime now) {
    print("Right Direction!");
    _openEarable.rgbLed.writeLedColor(r: 0, g: 255, b: 0);
    print("${lastScanTime} new lastSucccessJingel");

    int duration = now.difference(lastJingleTime).inMilliseconds;
    if (duration > 900) {
    _openEarable.audioPlayer.jingle(2);
    lastJingleTime = now;
    }
  }
}