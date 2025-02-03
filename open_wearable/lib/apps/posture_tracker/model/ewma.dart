class EWMA {
  final double _alpha;
  double _oldValue = 0;

  EWMA(this._alpha);

  double update(double newValue) {
    _oldValue = _alpha * newValue + (1 - _alpha) * _oldValue;
    return _oldValue;
  }
}
