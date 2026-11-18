import 'dart:math' as math;
import 'activity_models.dart';

/// Counts complete down/up cycles in manually selected squat mode.
///
/// Uses the engine's filtered vertical acceleration (m/s²), sensor time (s),
/// angular speed (rad/s) and estimated gravity direction. Integrated position
/// is a bounded motion proxy, not anatomical squat depth. The starting gravity
/// direction rejects large posture changes, but cannot identify leg movement.
class SquatDetector {
  static const _minimumExcursion = 0.12;
  double _velocity = 0, _position = 0, _minimum = 0;
  double _referenceVelocity = 0, _referencePosition = 0, _referenceMinimum = 0;
  double _began = 0, _returnPeak = 0, _quiet = 0, _baseline = 0;
  int _state = 0;
  bool _held = false;
  MotionVector? _startUp;

  /// Current movement phase for the existing exercise screen.
  String phase = 'Hold the start position';

  /// Requires a new posture reference after mode changes, pauses or data gaps.
  void reset() {
    _startUp = null;
    _baseline = 0;
    discardMovement();
    phase = 'Hold the start position';
  }

  /// Drops an uncertain cycle without requiring a new set calibration.
  void discardMovement() {
    _velocity = _position = _minimum = 0;
    _referenceVelocity = _referencePosition = _referenceMinimum = 0;
    _began = _returnPeak = _quiet = 0;
    _state = 0;
    _held = false;
    phase = 'Ready · lower your body';
  }

  /// Returns one after sufficient lowering and a substantial return near rest.
  int add(
    double time,
    double acceleration,
    double dt,
    double angularSpeed,
    MotionVector up,
  ) {
    _startUp ??= up;
    // Retain the standing reference across rejected movements: push-up setup
    // or bending must not silently become the new upright squat posture.
    if (angularSpeed > 1.2 || _startUp!.dot(up) < 0.7) {
      discardMovement();
      phase = 'Return to your standing position';
      return 0;
    }
    acceleration -= _baseline;
    _quiet = acceleration.abs() < 0.02 && angularSpeed < 0.3 ? _quiet + dt : 0;
    final previousVelocity = _velocity;
    _velocity = _velocity * math.exp(-dt / 1.5) + acceleration * dt;
    // Never let damping erase a held descent and manufacture a return.
    if (_quiet < 0.25) {
      _position = _position * math.exp(-dt / 4) +
          (previousVelocity + _velocity) * 0.5 * dt;
    } else {
      _velocity = _referenceVelocity = 0;
      if (_state != 0) _held = true;
    }
    if (_velocity.abs() > 2 ||
        _position.abs() > 1 ||
        (_state != 0 && time - _began > 6)) {
      discardMovement();
      return 0;
    }
    if (_state == 0) {
      phase = 'Ready · lower your body';
      // Correct residual gravity offset only at an idle, quiet starting pose.
      if (acceleration.abs() < 0.08 &&
          angularSpeed < 0.3 &&
          _velocity.abs() < 0.025) {
        _baseline += dt / (0.5 + dt) * acceleration;
        _position = _minimum = 0;
      }
      if (_position < -_minimumExcursion * 0.4 && _velocity < -0.06) {
        _state = 1;
        _began = time;
        _minimum = _position;
        _referenceVelocity = _velocity;
        _referencePosition = _referenceMinimum = _position;
        phase = 'Lowering';
      }
      return 0;
    }
    final previousReferenceVelocity = _referenceVelocity;
    _referenceVelocity += acceleration * dt;
    _referencePosition +=
        (previousReferenceVelocity + _referenceVelocity) * 0.5 * dt;
    _referenceMinimum = math.min(_referenceMinimum, _referencePosition);
    _minimum = math.min(_minimum, _position);
    if (_state == 1) {
      if (_minimum <= -_minimumExcursion && _velocity > 0.04) {
        _state = 2;
        _returnPeak = _velocity;
        phase = 'Returning to standing';
      }
      return 0;
    }
    _returnPeak = math.max(_returnPeak, _velocity);
    final returned = _position >= _minimum * 0.3 &&
        _position - _minimum >= _minimumExcursion * 0.7 &&
        (!_held || _referencePosition >= _referenceMinimum * 0.3);
    final nearTop = _velocity.abs() <= math.min(0.07, _returnPeak * 0.3);
    if (returned && nearTop && time - _began >= 0.8) {
      // Preserve residual velocity across continuous repetitions, but rebase
      // position so a completed cycle cannot accumulate into the next one.
      _position = _minimum = _referencePosition = _referenceMinimum = 0;
      _referenceVelocity = 0;
      _returnPeak = 0;
      _held = false;
      _state = 0;
      phase = 'Repetition complete';
      return 1;
    }
    if (!returned && _velocity < -0.06) discardMovement();
    return 0;
  }
}
