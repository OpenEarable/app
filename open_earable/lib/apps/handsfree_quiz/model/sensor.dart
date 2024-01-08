import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:open_earable/apps/handsfree_quiz/model/position.dart';
import 'package:open_earable/apps/handsfree_quiz/view/quiz_view.dart';
import 'package:open_earable_flutter/src/open_earable_flutter.dart';

/**
 * Sensor Object that starts and stops the listening to the openEarable Sensors
 * and notifies the QuizView for updates
 */
class Sensor {
  final OpenEarable _openEarable;
  var config =
      OpenEarableSensorConfig(sensorId: 0, samplingRate: 50, latency: 0);
  var deviceListen;
  double xAcc = 0.0;
  double yAcc = 0.0;
  double zAcc = 0.0;
  late Position position;
  bool isSet = false;
  QuizState _quizView;
  StreamSubscription? _streamSubscription;

  Sensor(this._openEarable, this._quizView) {
    _setupStreams();
  }

  /**
   * Setup the streams
   */
  void _setupStreams() {
    if (_openEarable.bleManager.connected) {
      _openEarable.sensorManager.writeSensorConfig(config);
      startSubscription();
    }
  }

  void startSubscription() {
    _streamSubscription =
        _openEarable.sensorManager.subscribeToSensorData(0).listen((event) {
          /// Checking if position is set with a value from this session
      if (!isSet) {
        /// position isn't set or with a value from an old value so its set now
        position = Position(
          event["GYRO"]["X"],
          event["GYRO"]["Y"],
          event["GYRO"]["Z"],
        );
        isSet = true;
      } else {
        /// position is from this session so we use it to calculate the
        /// direction and set position to current read value
        Position tempPos = Position(
            event["GYRO"]["X"], event["GYRO"]["Y"], event["GYRO"]["Z"]);
        Direction direction = position.direction(tempPos);
        position = tempPos;
        /// check if the update has any influence on the QuizView
        _quizView.updateData(direction);
      }
    });
  }

  /**
   * Resume listening to the Earable subscription and notify the listeners
   */
  void startListen() {
    if (_openEarable.bleManager.connected) {
      startSubscription();
    }
  }

  /**
   * Cancel the subscription to the Earable, since pausing and resuming causes
   * Problems
   */
  void stopListen() {
    ///
    _streamSubscription?.cancel();
    isSet = false;
  }

  /**
   * Cancel the Earable subscription
   */
  void dispose() {
    _streamSubscription?.cancel();
  }
}
