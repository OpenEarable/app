import 'package:open_earable/apps/gym_spotter/model/model_states.dart';
import 'package:open_earable/apps/gym_spotter/model/repetition_data.dart';
import 'dart:math';

// Hanldes the data input from the app and distributes accordingly to model.
// Also gives model feedback to app
class DataHandler {
  // data of calibration and the ongoing repetition
  RepetitionData _calibration = RepetitionData();
  RepetitionData _currentRepetition = RepetitionData();

  // accelerometer activity used to determine if person is still
  double _currentActivity = 0;

  bool _inMotion = false;
  bool calibrated = false;

  // Dynamic time threshold to determine if the next rep starts
  int _nextRepepitionTimeStamp = 0;
  static const double _nextRepetitionActivityThreshold = 0.5;
  // Minimum wait time to start next repetition.
  /// Should at least be as much as [_repetitionFeedbackFreezer] in gym_spotter_app.dart
  static const int _nextRepetitionWaitTimer = 3000;

  // Dynamic time threhold to determine if the analysis starts
  int _beginTimeStamp = 0;
  static const double _beginActivationThreshold = 0.4;
  static const int _beginWaitTimer = 2500;

  /// Model state of last repetition for at least [_nextRepetitionWaitTimer] miliseconds after it. [ModelState.Analysing] otherwhise
  ModelState _lastRepetition = ModelState.Analysing;

  static const double g = 9.81;

  // gets called to communicate with front end
  // returns state after newDataPoint was analysed
  ModelState pipeLineData(dataPoint newDataPoint) {
    calculateActivity(newDataPoint);
    if (!calibrated) {
      // calibrate model first
      return calibrate(newDataPoint);
    }

    if (!_inMotion) {
      detectBegin(newDataPoint);
      return ModelState.WaitForStart;
    }

    // analyses the new Data
    _currentRepetition.updateData(newDataPoint);

    // checks if repetition is done and checks it against calibration data.
    // This only gets entered once per repetition right after it is done,
    // to trigger feedback events
    if (_currentRepetition.phase == "DONE" &&
        _lastRepetition == ModelState.Analysing) {
      _lastRepetition = analyseRepetition();
      return _lastRepetition;
    }

    // resets repetition data if a new repetition starts
    if (detectRepetition(newDataPoint)) {
      _currentRepetition = RepetitionData();
      _lastRepetition = ModelState.Analysing;
    }
    return _lastRepetition;
  }

  ModelState calibrate(dataPoint newDataPoint) {
    if (!_inMotion) {
      detectBegin(newDataPoint);
      return ModelState.WaitForStart;
    }
    _currentRepetition.updateData(newDataPoint);
    if (detectRepetition(newDataPoint)) {
      // only if calibration is successful changes calibration data
      _calibration = _currentRepetition;
      _currentRepetition = RepetitionData();
      calibrated = true;
      return ModelState.Calibrated;
    }
    return ModelState.Analysing;
  }

  // detects if person was waiting in deadlift position
  void detectBegin(dataPoint newDataPoint) {
    if (_beginTimeStamp == 0) {
      // this is set to 0 after each stop of recording
      _beginTimeStamp = newDataPoint.timeStamp + _beginWaitTimer;
    }

    if ((_currentActivity - g).abs() > _beginActivationThreshold) {
      _beginTimeStamp = newDataPoint.timeStamp + _beginWaitTimer;
    }
    if (newDataPoint.timeStamp >= _beginTimeStamp) {
      // starts motion if enough time passed standing still
      _inMotion = true;
    }
  }

  bool detectRepetition(dataPoint newDataPoint) {
    // repetition cant be done if its not in this phase
    if (_currentRepetition.phase != "DONE") {
      return false;
    }

    if (_nextRepepitionTimeStamp == 0) {
      // this is set to 0 at the beginning of each repetition (see below)
      _nextRepepitionTimeStamp =
          newDataPoint.timeStamp + _nextRepetitionWaitTimer;
      return false;
    }
    if ((_currentActivity - g).abs() > _nextRepetitionActivityThreshold) {
      _nextRepepitionTimeStamp =
          newDataPoint.timeStamp + _nextRepetitionWaitTimer;
      return false;
    }
    if (newDataPoint.timeStamp > _nextRepepitionTimeStamp) {
      // if enough time passed standing still the next repetition starts
      _nextRepepitionTimeStamp = 0;
      return true;
    }
    return false;
  }

  ModelState analyseRepetition() {
    // 0.2 is about 11.5° leeway in each pitch direction
    if ((_calibration.liftPitch - _currentRepetition.liftPitch).abs() > 0.2) {
      return ModelState.BadRepetition;
    } else if ((_calibration.holdPitch - _currentRepetition.holdPitch).abs() >
        0.2) {
      return ModelState.BadRepetition;
    } else if ((_calibration.lowerPitch - _currentRepetition.lowerPitch).abs() >
        0.2) {
      return ModelState.BadRepetition;
    } else {
      return ModelState.GoodRepetition;
    }
  }

  // calculates length of acceleration vector
  void calculateActivity(dataPoint newDataPoint) {
    _currentActivity = sqrt(pow(newDataPoint.accX, 2) +
        pow(newDataPoint.accY, 2) +
        pow(newDataPoint.accZ, 2));
  }

  // resets all data to start a new data flow again
  void stop() {
    _inMotion = false;
    _currentRepetition = RepetitionData();
    _lastRepetition = ModelState.Analysing;
    _beginTimeStamp = 0;
  }

  // returns whether model is calibrated or not
  ModelState getCurrentRestState() {
    if (calibrated) {
      return ModelState.Calibrated;
    }
    return ModelState.NotCalibrated;
  }
}

// simple class for a datapoint of a lift
class dataPoint {
  int timeStamp;
  double accX;
  double accY;
  double accZ;
  double pitch;

  dataPoint(
    this.timeStamp,
    this.accX,
    this.accY,
    this.accZ,
    this.pitch,
  );
}
