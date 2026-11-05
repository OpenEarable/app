enum OpticalSensorChannel { red, infrared, green, ambient }

/// Resolves a named optical channel without confusing `infrared` with `red`.
int? findOpticalSensorAxisIndex(
  List<String> axisNames,
  OpticalSensorChannel channel,
) {
  for (var index = 0; index < axisNames.length; index++) {
    final normalized = _normalize(axisNames[index]);
    final tokens = _tokens(axisNames[index]);
    final isInfrared = normalized.contains('infrared') ||
        (tokens.contains('infra') && tokens.contains('red')) ||
        tokens.contains('ir');

    final matches = switch (channel) {
      OpticalSensorChannel.red =>
        !isInfrared && (normalized.contains('red') || tokens.contains('red')),
      OpticalSensorChannel.infrared => isInfrared,
      OpticalSensorChannel.green =>
        normalized.contains('green') || tokens.contains('green'),
      OpticalSensorChannel.ambient =>
        normalized.contains('ambient') || tokens.contains('ambient'),
    };
    if (matches) return index;
  }
  return null;
}

/// Resolves x/y/z from common names such as `X`, `Acceleration X`, or
/// `gyro_z`, while avoiding arbitrary substring matches.
int? findCartesianSensorAxisIndex(List<String> axisNames, String axis) {
  assert(axis == 'x' || axis == 'y' || axis == 'z');
  const prefixes = ['acc', 'accel', 'acceleration', 'gyro', 'gyroscope'];

  for (var index = 0; index < axisNames.length; index++) {
    final normalized = _normalize(axisNames[index]);
    final tokens = _tokens(axisNames[index]);
    if (tokens.contains(axis) || normalized == axis) return index;
    if (prefixes.any((prefix) => normalized == '$prefix$axis')) return index;
  }
  return null;
}

String _normalize(String value) =>
    value.toLowerCase().replaceAll(RegExp('[^a-z0-9]'), '');

Set<String> _tokens(String value) => value
    .toLowerCase()
    .split(RegExp('[^a-z0-9]+'))
    .where((token) => token.isNotEmpty)
    .toSet();
