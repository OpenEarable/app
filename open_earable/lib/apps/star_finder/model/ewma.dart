/// Represents an Exponentially Weighted Moving Average calculator.
class EWMA {
  double _alpha; // Smoothing factor for the EWMA
  double _oldValue = 0; // Initial value of the EWMA

  EWMA(this._alpha);

  /// Updates the EWMA with a new value and returns the updated EWMA
  double update(double newValue) {
    _oldValue = _alpha * newValue + (1 - _alpha) * _oldValue;
    return _oldValue;
  }
}