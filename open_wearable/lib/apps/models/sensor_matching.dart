import 'package:open_earable_flutter/open_earable_flutter.dart';

String _sensorSearchText(Sensor sensor) {
  return '${sensor.sensorName} ${sensor.chartTitle}'.toLowerCase();
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
  final normalizedAliases =
      aliases.map((alias) => alias.toLowerCase()).toList();
  for (final sensor in sensors) {
    final text = _sensorSearchText(sensor);
    if (normalizedAliases.any(text.contains)) {
      return sensor;
    }
  }

  return null;
}

/// Returns whether [sensorManager] exposes a sensor whose name or chart title
/// contains any of [aliases].
bool sensorManagerHasSensorByAliases(
  SensorManager sensorManager,
  Wearable wearable,
  Iterable<String> aliases,
) {
  return findSensorByAliases(sensorManager.sensors, aliases) != null;
}

/// Returns the first sensor that looks like an accelerometer.
Sensor? findAccelerometerSensor(Iterable<Sensor> sensors) {
  return findSensorByAliases(sensors, const ['accelerometer', 'accel', 'acc']);
}

Sensor? findPpgSensor(Iterable<Sensor> sensors) {
  return findSensorByAliases(
    sensors,
    [
      'photoplethysmography',
      'ppg',
      'pulse',
    ],
  );
}

/// Returns whether [sensorManager] exposes an accelerometer-like sensor.
bool sensorManagerHasAccelerometer(
  SensorManager sensorManager,
  Wearable wearable,
) {
  return sensorManagerHasSensorByAliases(
    sensorManager,
    wearable,
    const ['accelerometer', 'accel', 'acc'],
  );
}
