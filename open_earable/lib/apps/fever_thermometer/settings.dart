/// Holds the real reference temperature and the measured reference temperature.
class Settings {
  double? _referenceMeasuredTemperature;
  double? _referenceRealTemperature;

  /// Returns the estimated real temperature, if the reference is set. Otherwise null.
  double? getTemperature(double measuredTemperature) {
    if (_referenceMeasuredTemperature == null ||
        _referenceRealTemperature == null) {
      return null;
    }
    final double _difference =
        _referenceRealTemperature! - _referenceMeasuredTemperature!;
    return measuredTemperature + _difference;
  }

  getReferenceMeasuredTemperature() {
    return _referenceMeasuredTemperature;
  }

  getReferenceRealTemperature() {
    return _referenceRealTemperature;
  }

  setReferenceMeasuredTemperature(double? referenceMeasuredTemperature) {
    _referenceMeasuredTemperature = referenceMeasuredTemperature;
  }

  setReferenceRealTemperature(double? referenceRealTemperature) {
    _referenceRealTemperature = referenceRealTemperature;
  }

  /// Deletes the reference data.
  deleteData() {
    _referenceMeasuredTemperature = null;
    _referenceRealTemperature = null;
  }
}
