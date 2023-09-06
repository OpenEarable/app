// ignore_for_file: unnecessary_this

import '../model/attitude.dart';

class PostureTrackerViewModel {
  Attitude _attitude = Attitude();

  Attitude get attitude => this._attitude;
  
  void updateAttitude(Attitude attitude) {
    this._attitude = attitude;
  }
}