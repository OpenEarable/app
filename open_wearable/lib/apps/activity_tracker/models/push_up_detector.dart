import 'dart:math' as math;

/// Counts manually selected push-ups from filtered vertical acceleration.
///
/// Inputs are sensor seconds, m/s², seconds and angular speed in rad/s.
/// Displacement is a short-lived motion proxy, not measured exercise depth.
/// Damped integration limits accumulating sensor-offset error during a set.
/// A separate undamped reference protects a held descent from being erased
/// by damping and then mistaken for a complete return.
class PushUpDetector {
  static const _minimumExcursion = 0.015;
  double _velocity = 0, _position = 0, _minimum = 0;
  double _began = 0, _settle = 0, _quiet = 0, _returnPeak = 0;
  double _baseline = 0, _baselineSum = 0;
  double? _settleAnchor;
  int _baselineSamples = 0;
  double _referenceVelocity = 0,
      _referencePosition = 0,
      _referenceMinimum = 0,
      _referenceSeconds = 0,
      _referenceInitialVelocity = 0;
  double _loweringPeak = 0, _returnBegan = 0;
  bool _heldDescent = false;
  int _state = 0;

  /// Current phase for live exercise feedback.
  String phase = 'Hold the start position';

  /// Discards the current movement and requires a new quiet starting window.
  void reset() {
    _velocity =
        _position = _minimum = _began = _settle = _quiet = _returnPeak = 0;
    _baseline = _baselineSum = 0;
    _baselineSamples = 0;
    _settleAnchor = null;
    _referenceVelocity = _referencePosition =
        _referenceMinimum = _referenceSeconds = _referenceInitialVelocity = 0;
    _loweringPeak = _returnBegan = 0;
    _heldDescent = false;
    _state = 0;
    phase = 'Hold the start position';
  }

  /// Drops one uncertain movement while keeping an established set calibration.
  /// Pauses, data gaps and mode changes still use [reset] for a fresh setup.
  void discardMovement() {
    if (_settle < 0.7) {
      reset();
      return;
    }
    _velocity = _position = _minimum = _began = _quiet = _returnPeak = 0;
    _referenceVelocity = _referencePosition =
        _referenceMinimum = _referenceSeconds = _referenceInitialVelocity = 0;
    _loweringPeak = _returnBegan = 0;
    _heldDescent = false;
    _state = 0;
    phase = 'Ready · lower your body';
  }

  /// Returns one only after a descent and a substantial return to its origin.
  int add(double time, double acceleration, double dt, double angularSpeed) {
    // The engine handles data gaps and clipping. Reject large head rotations
    // locally as well; the settling window must include a quiet gyroscope.
    if (angularSpeed > 1.6) {
      discardMovement();
      return 0;
    }
    if (_settle < 0.7) {
      final quiet = acceleration.abs() < 0.5 && angularSpeed < 0.18;
      if (!quiet ||
          (_settleAnchor != null &&
              (acceleration - _settleAnchor!).abs() > 0.05)) {
        _settle = _baselineSum = 0;
        _baselineSamples = 0;
        _settleAnchor = null;
      }
      if (quiet) {
        _settleAnchor ??= acceleration;
        _settle += dt;
        // Let the causal low-pass filter settle before measuring its offset.
        if (_settle >= 0.45) {
          _baselineSum += acceleration;
          _baselineSamples++;
        }
        if (_settle >= 0.7) _baseline = _baselineSum / _baselineSamples;
      }
      return 0;
    }
    // Estimate a local residual offset in the starting pose. A small gravity
    // calibration error must not integrate into velocity throughout the set.
    acceleration -= _baseline;
    _referenceSeconds += dt;
    final previousReferenceVelocity = _referenceVelocity;
    // The reference is never position-damped. Once a bottom hold is observed,
    // its descent must still be physically retraced in this motion proxy.
    _referenceVelocity += acceleration * dt;
    _referencePosition +=
        (previousReferenceVelocity + _referenceVelocity) * 0.5 * dt;
    _referenceMinimum = math.min(_referenceMinimum, _referencePosition);
    final previousVelocity = _velocity;
    _velocity = _velocity * math.exp(-dt / 1.5) + acceleration * dt;
    if (_quiet < 0.25) {
      _position = _position * math.exp(-dt / 4) +
          (previousVelocity + _velocity) * 0.5 * dt;
    }
    // Freeze the motion proxy on a sustained near-zero signal. Keep the
    // undamped excursion as a separate return requirement across this hold.
    // This is a heuristic: constant-speed motion is indistinguishable from
    // rest using acceleration alone, so it still needs hardware validation.
    _quiet = acceleration.abs() < 0.008 ? _quiet + dt : 0;
    if (_quiet >= 0.25) {
      _velocity = _referenceVelocity = 0;
      if (_state != 0) _heldDescent = true;
    }
    if (_velocity.abs() > 2 || _position.abs() > 0.75) {
      discardMovement();
      return 0;
    }
    if (_state != 0 && time - _began > 8) {
      discardMovement();
      return 0;
    }
    if (_state == 0) {
      phase = 'Ready · lower your body';
      _minimum = math.min(_minimum, _position);
      if (_position < -_minimumExcursion * 0.4 && _velocity < -0.019) {
        _state = 1;
        _began = time;
        _loweringPeak = -_velocity;
        phase = 'Lowering';
      } else if (_quiet >= 0.25) {
        _position = _minimum = _referenceVelocity =
            _referencePosition = _referenceMinimum = _referenceSeconds = 0;
      }
    } else if (_state == 1) {
      _loweringPeak = math.max(_loweringPeak, -_velocity);
      _minimum = math.min(_minimum, _position);
      if (_minimum <= -_minimumExcursion && _velocity > 0.013) {
        _state = 2;
        _returnPeak = _velocity;
        _returnBegan = time;
        phase = 'Returning to start';
      }
    } else {
      _returnPeak = math.max(_returnPeak, _velocity);
      // Approximate negative endpoint-velocity drift over this short cycle;
      // keep the uncorrected reference when the correction would reduce it.
      final correctedReturn = math.max(
        _referencePosition,
        _referencePosition -
            0.5 *
                (_referenceInitialVelocity + _referenceVelocity) *
                _referenceSeconds,
      );
      final referenceReturned = correctedReturn >= _referenceMinimum * 0.3 &&
          correctedReturn - _referenceMinimum >= _minimumExcursion * 0.75;
      // Duration-normalised peak speeds provide an alternate consistency
      // check for continuous cycles. Disable it after a hold so waiting
      // cannot grow a small partial return into a completed repetition.
      final downEnvelope = _loweringPeak * (_returnBegan - _began);
      final upEnvelope = _returnPeak * (time - _returnBegan);
      final comparableReturn =
          !_heldDescent && downEnvelope > 0 && upEnvelope >= downEnvelope * 0.9;
      final proxyReturned = _position >= _minimum * 0.25 &&
          _position - _minimum >= _minimumExcursion * 0.75;
      final returned = referenceReturned || (proxyReturned && comparableReturn);
      // Slow, small movements need a relative top-speed check. A fixed
      // tolerance could otherwise confirm them while still moving upwards.
      final nearTop = _referenceVelocity.abs() <= 0.025 ||
          _velocity.abs() <= math.min(0.04, _returnPeak * 0.3) ||
          _velocity <= 0;
      if (returned && nearTop && time - _began >= 0.5) {
        _state = 0;
        // Keep residual velocity for the start of the next continuous cycle;
        // resetting it mid-transition would inject integration drift.
        _position = _minimum = _returnPeak =
            _referencePosition = _referenceMinimum = _referenceSeconds = 0;
        _referenceInitialVelocity = _referenceVelocity;
        _loweringPeak = _returnBegan = 0;
        _heldDescent = false;
        if (_quiet >= 0.25) _velocity = _referenceVelocity = 0;
        phase = 'Repetition complete';
        return 1;
      }
      if (!returned && _velocity < -0.019) discardMovement();
    }
    return 0;
  }
}
