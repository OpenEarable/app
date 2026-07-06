import 'package:open_earable_flutter/open_earable_flutter.dart';

typedef SensorMatcher = bool Function(Sensor sensor);

const accelerometerSensorAliases = ['accelerometer', 'accel', 'acc'];
const ppgSensorAliases = ['photoplethysmography', 'ppg', 'pulse'];

String _sensorSearchText(Sensor sensor) {
  return '${sensor.sensorName} ${sensor.chartTitle}'.toLowerCase();
}

bool sensorMatchesAliases(Sensor sensor, Iterable<String> aliases) {
  final searchText = _sensorSearchText(sensor);
  return aliases.map((alias) => alias.toLowerCase()).any(searchText.contains);
}

Sensor? findSensor(
  Iterable<Sensor> sensors,
  SensorMatcher matcher,
) {
  for (final sensor in sensors) {
    if (matcher(sensor)) {
      return sensor;
    }
  }

  return null;
}

/// Returns the first sensor whose name or chart title contains any of
/// [aliases].
///
/// Matching is intentionally fuzzy so apps can work across different device
/// naming schemes.
Sensor? findSensorByAliases(
  Iterable<Sensor> sensors,
  Iterable<String> aliases,
) {
  return findSensor(sensors, (sensor) => sensorMatchesAliases(sensor, aliases));
}

/// Returns the first sensor that looks like an accelerometer.
Sensor? findAccelerometerSensor(Iterable<Sensor> sensors) {
  return findSensorByAliases(sensors, accelerometerSensorAliases);
}

Sensor? findPpgSensor(Iterable<Sensor> sensors) {
  return findSensorByAliases(sensors, ppgSensorAliases);
}
