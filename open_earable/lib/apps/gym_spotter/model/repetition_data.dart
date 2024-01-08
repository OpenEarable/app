import 'dart:math';

import 'data_handler.dart';

// This class models a deadlift repition and extracts the key data values
// from it to analyse the repetition.
class RepetitionData {
  // Data from the beginning, the lifting of the bar, of the repetition
  double liftPitch = 3;
  int _liftMaxPitchTimeStamp = 0;
  int _liftPitchIndex = 0;
  // Waiting threshold to be sure that the hold phase is over
  static const int _liftTimeThreshold = 1000;

  // Data from the middle part, while standing upright and holding, of the repetition
  double holdPitch = -3;
  int _holdPitchTimeStamp = 0;
  int _holdPitchIndex = 0;
  // Waiting threshold to be sure that the hold phase is over
  static const int _holdTimeThreshold = 1000;
  // Model only considers hold pitches lower than this threshold
  // The optimal threshold is heavily depending on the body proportions of the user
  // and how the earable is worn!
  static const double _holdPitchThreshold = 0.1;

  // Data from the end, the lowering of the bar, of the repetition
  double lowerPitch = 3;
  int _lowerTimeStamp = 0;
  int _lowerIndex = 0;
  // Waiting threshold to be sure that the hold phase is over
  static const int _lowerTimeThreshold = 1500;
  // Model only considers lower pitches higher than this threshold
  // The optimal threshold is heavily depending on the body proportions of the user
  // and how the earable is worn!
  static const double _lowerPitchThreshold = -0.3;

  // current phase of the repetition
  String phase = "LIFT";

  // Data of the whole repetition
  List<dataPoint> fullRepetition = [];

  // Takes the new data point and calls analysis function according to phase
  void updateData(dataPoint newDataPoint) {
    fullRepetition.add(newDataPoint);
    switch (phase) {
      case ("LIFT"):
        {
          scanLift(newDataPoint);
        }
      case ("HOLD"):
        {
          scanHold(newDataPoint);
        }
      case ("LOWER"):
        {
          scanLower(newDataPoint);
        }
      default:
        {
          return;
        }
    }
  }

  // analyses the lift phase
  void scanLift(dataPoint newDataPoint) {
    if (_liftMaxPitchTimeStamp == 0) {
      _liftMaxPitchTimeStamp = newDataPoint.timeStamp;
      return;
    }
    // we save and analyse the biggest forward pitch while lifting
    if (liftPitch < newDataPoint.pitch) {
      liftPitch = newDataPoint.pitch;
      _liftPitchIndex = fullRepetition.length - 1;
      _liftMaxPitchTimeStamp = newDataPoint.timeStamp;
      return;
    }
    // we wait a little in order to be sure that the lift is over
    if (newDataPoint.timeStamp > _liftMaxPitchTimeStamp + _liftTimeThreshold) {
      liftPitch = calculatePitchMean(_liftPitchIndex);
      phase = "HOLD";
    }
  }

  // analyses the hold phase
  void scanHold(dataPoint newDataPoint) {
    if (_holdPitchTimeStamp == 0) {
      _holdPitchTimeStamp = newDataPoint.timeStamp;
      return;
    }
    // we save and analyse the biggest backwards pitch while holding
    if (holdPitch > newDataPoint.pitch ||
        newDataPoint.pitch > _holdPitchThreshold) {
      holdPitch = newDataPoint.pitch;
      _holdPitchIndex = fullRepetition.length - 1;
      _holdPitchTimeStamp = newDataPoint.timeStamp;
      return;
    }
    // We wait a little in order to be sure that the hold is over
    if (newDataPoint.timeStamp > _holdPitchTimeStamp + _holdTimeThreshold) {
      holdPitch = calculatePitchMean(_holdPitchIndex);
      phase = "LOWER";
    }
  }

  // analyses the lower phase
  void scanLower(dataPoint newDataPoint) {
    if (_lowerTimeStamp == 0) {
      _lowerTimeStamp = newDataPoint.timeStamp;
      return;
    }
    // we save and analyse the biggest forwards pitch again
    if (lowerPitch < newDataPoint.pitch ||
        newDataPoint.pitch < _lowerPitchThreshold) {
      lowerPitch = newDataPoint.pitch;
      _lowerIndex = fullRepetition.length - 1;
      _lowerTimeStamp = newDataPoint.timeStamp;
      return;
    }
    // we wait so we can sure that the lift is done
    if (newDataPoint.timeStamp > _lowerTimeStamp + _lowerTimeThreshold) {
      lowerPitch = calculatePitchMean(_lowerIndex);
      phase = "DONE";
    }
  }

  // calculates the pitch mean over 5 data entries, if possible.
  // From index it takes 2 entries in front and 2 entries behind.
  double calculatePitchMean(int index) {
    double sum = 0;
    int lowerBound = max(index - 2, 0);
    int upperBound = min(index + 3, fullRepetition.length);
    for (int i = lowerBound; i < upperBound; i++) {
      sum += fullRepetition[i].pitch;
    }
    return sum / (upperBound - lowerBound);
  }
}
