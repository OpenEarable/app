import 'package:open_earable_flutter/open_earable_flutter.dart';

import 'activity_tracker.dart' show PpgMotionSample;
import 'sensor_axis_mapping.dart';

/// Translates what the OpenEarable SDK hands over into the sample types the
/// meditation pipeline works with.
///
/// Split out of `biometric_source.dart` because none of it depends on a live
/// session: these are pure functions over one SDK value, which makes the
/// channel and axis handling directly testable. Getting that mapping wrong is
/// silent - the signal still flows, it is simply the wrong channel - so it is
/// worth exercising on its own.

class PpgOpticalSample {
  final int timestamp;
  final double red;
  final double ir;
  final double green;
  final double ambient;

  const PpgOpticalSample({
    required this.timestamp,
    required this.red,
    required this.ir,
    required this.green,
    required this.ambient,
  });
}

SensorConfigurationValue selectBestConfigurationValue(
  List<SensorConfigurationValue> values, {
  required int targetFrequencyHz,
}) {
  final frequencyValues =
      values.whereType<SensorFrequencyConfigurationValue>().toList();
  if (frequencyValues.isEmpty) {
    return values.first;
  }

  SensorFrequencyConfigurationValue? nextBigger;
  SensorFrequencyConfigurationValue? maxValue;
  for (final value in frequencyValues) {
    if (maxValue == null || value.frequencyHz > maxValue.frequencyHz) {
      maxValue = value;
    }
    if (value.frequencyHz >= targetFrequencyHz &&
        (nextBigger == null || value.frequencyHz < nextBigger.frequencyHz)) {
      nextBigger = value;
    }
  }

  return nextBigger ?? maxValue ?? values.first;
}

List<double>? sensorValuesAsDoubles(SensorValue data) {
  if (data is SensorDoubleValue) {
    return data.values;
  }
  if (data is SensorIntValue) {
    return data.values.map((value) => value.toDouble()).toList(growable: false);
  }
  return null;
}

PpgOpticalSample? extractPpgOpticalSample(
  Sensor sensor,
  SensorValue data,
  List<double> values,
) {
  if (values.isEmpty) {
    return null;
  }

  double valueAt(int? index, double fallback) {
    if (index != null && index >= 0 && index < values.length) {
      return values[index];
    }
    return fallback;
  }

  final fallbackRed = values[0];
  final fallbackIr = values.length > 1 ? values[1] : fallbackRed;
  final fallbackGreen = values.length > 2 ? values[2] : fallbackRed;
  final fallbackAmbient = values.length > 3 ? values[3] : 0.0;

  // Usually channels are [red, ir, green, ambient], but we prefer axis-name
  // matching when available to avoid firmware-order mismatches.
  final red = valueAt(
    findOpticalSensorAxisIndex(
      sensor.axisNames,
      OpticalSensorChannel.red,
    ),
    fallbackRed,
  );
  final ir = valueAt(
    findOpticalSensorAxisIndex(
      sensor.axisNames,
      OpticalSensorChannel.infrared,
    ),
    fallbackIr,
  );
  final green = valueAt(
    findOpticalSensorAxisIndex(
      sensor.axisNames,
      OpticalSensorChannel.green,
    ),
    fallbackGreen,
  );
  final ambient = valueAt(
    findOpticalSensorAxisIndex(
      sensor.axisNames,
      OpticalSensorChannel.ambient,
    ),
    fallbackAmbient,
  );

  return PpgOpticalSample(
    timestamp: data.timestamp,
    red: red,
    ir: ir,
    green: green,
    ambient: ambient,
  );
}

PpgMotionSample extractImuMotionSample(
  Sensor sensor,
  SensorValue data,
  List<double> values,
) {
  double valueAt(int? index, double fallback) {
    if (index != null && index >= 0 && index < values.length) {
      return values[index];
    }
    return fallback;
  }

  final fallbackX = values.isNotEmpty ? values[0] : 0.0;
  final fallbackY = values.length > 1 ? values[1] : 0.0;
  final fallbackZ = values.length > 2 ? values[2] : 0.0;

  final x = valueAt(
    findCartesianSensorAxisIndex(sensor.axisNames, 'x'),
    fallbackX,
  );
  final y = valueAt(
    findCartesianSensorAxisIndex(sensor.axisNames, 'y'),
    fallbackY,
  );
  final z = valueAt(
    findCartesianSensorAxisIndex(sensor.axisNames, 'z'),
    fallbackZ,
  );

  return PpgMotionSample(
    timestamp: data.timestamp,
    x: x,
    y: y,
    z: z,
  );
}
