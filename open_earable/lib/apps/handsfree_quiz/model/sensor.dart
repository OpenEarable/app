import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:open_earable/apps/handsfree_quiz/model/position.dart';
import 'package:open_earable/apps/handsfree_quiz/view/quiz_view.dart';
import 'package:open_earable_flutter/src/open_earable_flutter.dart';

/**
 * Sensor Object that starts and stops the listening to the openEarable Sensors
 * and notifies the QuizView for updates
 */
class Sensor extends ChangeNotifier{

  final OpenEarable _openEarable;
  var config = OpenEarableSensorConfig(sensorId: 0, samplingRate: 30, latency: 0);
  var deviceListen;
  double xAcc = 0.0;
  double yAcc = 0.0;
  double zAcc = 0.0;
  QuizState _quizView;
  List<Position> _data = <Position>[];
  StreamSubscription? _streamSubscription;
  Sensor(this._openEarable, this._quizView) {
    _setupStreams();
  }

  /**
   * Setup the streams
   */
  void _setupStreams() {
    if(_openEarable.bleManager.connected) {
      _streamSubscription =
          _openEarable.sensorManager.subscribeToSensorData(0).listen((event) {
        Position position = Position(
            event["GYRO"]["X"],
            event["GYRO"]["Y"],
            event["GYRO"]["Z"]
        );
        print(position.toString());
        _quizView.updateData(position);
        notifyListeners();
      });
    }

  }

  void startListen() {
    if(_streamSubscription?.isPaused ?? false) {
      _streamSubscription?.resume();
      notifyListeners();
    }
  }

  void stopListen() {
    _streamSubscription?.pause();
  }


  void dispose() {
    _streamSubscription?.cancel();
  }


}