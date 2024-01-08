import 'dart:async';

import 'package:open_earable/apps/head_trainer/logic/orientation_value_updater.dart';
import 'package:open_earable/apps/head_trainer/model/orientation_value.dart';
import 'package:open_earable/apps/head_trainer/model/sequence.dart';

class SequenceCalculator {

  final Sequence sequence;
  final OrientationValue oriValueOffset;
  final OrientationValueUpdater oriValueUpdater;
  final Function() onUpdate;

  SequenceCalculator({
    required this.sequence,
    required this.oriValueOffset,
    required this.oriValueUpdater,
    required this.onUpdate(),
  });

  StreamSubscription? _streamSubscription;

  // Move probabilities. 0 - start position; 1 - 90° this move
  double _rotateRight = 0;
  double _rotateLeft = 0;
  double _tiltRight = 0;
  double _tiltLeft = 0;
  double _tiltForward = 0;
  double _tiltBackwards = 0;

  int currentPosition = 0;
  // Timestamp when the correct position for the current move was started
  DateTime? _positionTimestamp;
  double? currentMoveProbability;
  // If current move position is hold progress will go from 0 to 1 over time
  double? currentMoveProgress;

  // subscribe to OrientationValueUpdater
  startCalculator() {
    _streamSubscription = oriValueUpdater.subscribe().listen((value) {
      oriValueOffset.roll = value.roll;
      oriValueOffset.pitch = value.pitch;
      oriValueOffset.yaw = value.yaw;
      _onValuesUpdated();
      onUpdate();
    });
  }

  // cancel stream subscription
  stopCalculator() {
    _streamSubscription?.cancel();
  }

  _onValuesUpdated() {
    if (currentPosition >= sequence.moves.length) {
      return;
    }

    Move currentMove = sequence.moves[currentPosition];

    _calculateMoveProbability();

    // set the current probability to the probability of the current move
    currentMoveProbability = switch(currentMove.type) {
      MoveType.rotateRight => _rotateRight,
      MoveType.rotateLeft => _rotateLeft,
      MoveType.tiltRight => _tiltRight,
      MoveType.tiltLeft => _tiltLeft,
      MoveType.tiltForward => _tiltForward,
      MoveType.tiltBackwards => _tiltBackwards,
    };

    // check if correct position for current move (in range)
    double plusMinusPerc = currentMove.plusMinusDegree.toDouble() / 90.0;
    double amountPerc = currentMove.amountInDegree.toDouble() / 90.0;
    if (currentMoveProbability! + plusMinusPerc >= amountPerc
      && currentMoveProbability! - plusMinusPerc <= amountPerc) {
      if (_positionTimestamp == null) {
        // Position started
        _positionTimestamp = DateTime.now();
      } else {
        double elapsedSeconds = (DateTime.now().millisecondsSinceEpoch / 1000)
            - (_positionTimestamp!.millisecondsSinceEpoch / 1000);

        currentMoveProgress = elapsedSeconds / currentMove.timeInSeconds;

        if (currentMoveProgress! >= 1) {
          currentPosition += 1;
          _resetProgress();
        }
      }
    } else {
      _resetProgress();
    }
  }

  // Reset if holding of move is canceled
  _resetProgress() {
    currentMoveProgress = 0;
    _positionTimestamp = null;
  }

  // Calculate the probability of the move currently performed
  _calculateMoveProbability() {
    OrientationValue value = oriValueOffset.getWithOffset();

    // values manually gathered
    const ROTATE_CONST = 0.58;
    const TILT_SIDE_CONST = 1.7;
    const TILT_FORWARD_BACKWARDS_CONST = 1.4;

    if (value.yaw > 0) {
      _rotateRight = value.yaw / ROTATE_CONST;
      _rotateLeft = 0;
    } else {
      _rotateLeft = (value.yaw * -1) / ROTATE_CONST;
      _rotateRight = 0;
    }

    if (value.roll > 0) {
      _tiltRight = value.roll / TILT_SIDE_CONST;
      _tiltLeft = 0;
    } else {
      _tiltLeft = (value.roll * -1) / TILT_SIDE_CONST;
      _tiltRight = 0;
    }

    if (value.pitch > 0) {
      _tiltForward = value.pitch / TILT_FORWARD_BACKWARDS_CONST;
      _tiltBackwards = 0;
    } else {
      _tiltBackwards = (value.pitch * -1) / TILT_FORWARD_BACKWARDS_CONST;
      _tiltForward = 0;
    }
  }

}