import 'dart:async';
import 'dart:math';
import 'package:open_earable_flutter/open_earable_flutter.dart';

/// A tracker for monitoring and providing feedback on position during breathing sessions.
///
/// The `BreathingSensorTracker`:
/// - Configures sensors for position tracking.
/// - Monitors sensor data for position feedback.
/// - Provides feedback streams to inform the user of their position status.
class BreathingSensorTracker {
  final OpenEarable openEarable;

  late StreamController<String> postureFeedbackStreamController =
      StreamController.broadcast();

  StreamSubscription? _sensorSubscription;

  Stream<String> get postureFeedbackStream =>
      postureFeedbackStreamController.stream;

  final EWMA rollEWMA = EWMA(0.5);
  final EWMA pitchEWMA = EWMA(0.5);

  final PostureStateTracker postureStateTracker = PostureStateTracker();

  double rollThreshold = 30.0;
  double pitchThreshold = 55.0;

  /// Determines whether pitch feedback is relevant (e.g., for sitting mode).
  bool isPitchRelevant = true;

  /// Constructor for the `BreathingSensorTracker`.
  ///
  /// - [openEarable]: An instance of the OpenEarable framework.
  BreathingSensorTracker(this.openEarable);

  /// Sets position thresholds and relevancy based on the specified mode.
  ///
  /// - [mode]: The mode of the session (e.g., 'sitting', 'lying').
  void setMode(String mode) {
    if (mode == 'sitting') {
      rollThreshold = 30.0;
      pitchThreshold = 55.0;
      isPitchRelevant = true;
    } else if (mode == 'lying') {
      rollThreshold = 30.0;
      pitchThreshold = 55.0;
      isPitchRelevant = false; // Potential pillow makes pitch irrelevant
    }
  }

  /// Configures the sensors for position tracking.
  void configureSensors() {
    openEarable.sensorManager.writeSensorConfig(
      OpenEarableSensorConfig(sensorId: 0, samplingRate: 30, latency: 0),
    );
  }

  /// Starts tracking position by subscribing to sensor data and providing feedback.
  void startTracking() {
    if (postureFeedbackStreamController.isClosed) {
      postureFeedbackStreamController = StreamController.broadcast();
    }

    // Configure sensors before starting tracking.
    configureSensors();

    _sensorSubscription?.cancel();
    _sensorSubscription =
        openEarable.sensorManager.subscribeToSensorData(0).listen((sensorData) {
      if (sensorData['EULER'] == null) {
        postureFeedbackStreamController.add('Error: No position data available.');
        return;
      }

      final roll = rollEWMA.update(sensorData['EULER']?['ROLL'] ?? 0.0);
      final pitch = pitchEWMA.update(sensorData['EULER']?['PITCH'] ?? 0.0);

      final feedback = _getPostureFeedback(roll, pitch);
      if (feedback != null) {
        postureFeedbackStreamController.add(feedback);
      } else {
        postureFeedbackStreamController.add('Correct Position');
      }
    });
  }

  /// Stops tracking position and optionally closes the feedback stream.
  ///
  /// - [closeStream]: If true, closes the position feedback stream.
  void stopTracking({bool closeStream = false}) {
    _sensorSubscription?.cancel();
    if (closeStream) {
      postureFeedbackStreamController.close();
    }
  }

  /// Converts radians to degrees.
  double radToDeg(double rad) => rad * (180 / pi);

  /// Evaluates position and provides feedback based on roll and pitch thresholds.
  ///
  /// - [roll]: The roll value in radians.
  /// - [pitch]: The pitch value in radians.
  /// - Returns: A string message with position feedback, or null if position is correct.
  String? _getPostureFeedback(double roll, double pitch) {
    if (radToDeg(roll).abs() > rollThreshold) {
      if (!isPitchRelevant) {
        return roll > 0
            ? "You're tilting to the right. Lay down on your back."
            : "You're tilting to the left. Lay down on your back.";
      } else {
        return roll > 0
            ? "You're tilting to the right. Keep your shoulders level."
            : "You're tilting to the left. Keep your shoulders level.";
      }
    }
    if (isPitchRelevant && radToDeg(pitch).abs() > pitchThreshold) {
      return pitch > 0
          ? "You're leaning forward. Straighten your back."
          : "You're leaning backward. Sit upright with a neutral back posture.";
    }
    return null; // Position is correct.
  }
}

/// A tracker for managing position states and their transitions.
class PostureStateTracker {
  DateTime? _lastBadPostureTime;
  DateTime? _lastGoodPostureTime;

  final int badPostureDurationThreshold = 3;
  final int resetThreshold = 2;

  /// Evaluates whether the user is in bad posture based on timing thresholds.
  ///
  /// - [isBadPosture]: Whether the current posture is bad.
  /// - Returns: True if the user holds bad posture for the defined threshold.
  bool evaluatePosture(bool isBadPosture) {
    final now = DateTime.now();

    if (isBadPosture) {
      if (_lastBadPostureTime == null) {
        _lastBadPostureTime = now;
      }

      final durationInBadPosture =
          now.difference(_lastBadPostureTime!).inSeconds;
      if (durationInBadPosture >= badPostureDurationThreshold) {
        _lastGoodPostureTime = null;
        return true;
      }
    } else {
      if (_lastGoodPostureTime == null) {
        _lastGoodPostureTime = now;
      }

      final durationInGoodPosture =
          now.difference(_lastGoodPostureTime!).inSeconds;
      if (durationInGoodPosture >= resetThreshold) {
        _lastBadPostureTime = null;
      }
    }

    return false;
  }
}

/// A utility class for calculating Exponential Weighted Moving Averages (EWMA).
class EWMA {
  final double _alpha;
  double _oldValue = 0;
  EWMA(this._alpha);

  double update(double newValue) {
    _oldValue = _alpha * newValue + (1 - _alpha) * _oldValue;
    return _oldValue;
  }
}
