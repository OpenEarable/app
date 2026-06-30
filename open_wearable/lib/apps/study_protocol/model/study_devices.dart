import 'package:open_earable_flutter/open_earable_flutter.dart';

/// Helpers for discovering the device set required by the study protocol app
/// and for resolving the OpenEarable sensor configurations it records.
///
/// The study protocol requires a stereo pair of OpenEarable devices (one left,
/// one right) plus a Plux RESPIRABAN. These helpers keep that detection logic in
/// one place so the gate screen and the recording controller agree on what a
/// valid setup looks like.

/// A connected left/right OpenEarable pair.
class EarablePair {
  /// OpenEarable positioned on the left ear.
  final Wearable left;

  /// OpenEarable positioned on the right ear.
  final Wearable right;

  const EarablePair({required this.left, required this.right});
}

/// The full device set required to run a study recording.
class StudyDeviceSet {
  /// Connected OpenEarable stereo pair.
  final EarablePair earables;

  /// Connected Plux RESPIRABAN.
  final Wearable respiban;

  const StudyDeviceSet({required this.earables, required this.respiban});
}

/// Returns true if [wearable] can record audio/IMU to its own SD card.
///
/// SD-card recording requires both sensor configuration access and the edge
/// recorder file-prefix capability that OpenEarable V2 exposes.
bool _isEdgeRecordingEarable(Wearable wearable) {
  return wearable.hasCapability<SensorConfigurationManager>() &&
      wearable.hasCapability<EdgeRecorderManager>() &&
      wearable.hasCapability<StereoDevice>();
}

/// Returns true if [wearable] is a Plux RESPIRABAN.
bool isRespiban(Wearable wearable) => wearable is Respiban;

/// Resolves the connected left/right OpenEarable pair, if present.
///
/// Reads the [StereoDevice.position] of every edge-recording capable wearable
/// and returns the first left/right combination found. Returns `null` when no
/// complete pair is connected.
Future<EarablePair?> findEarablePair(Iterable<Wearable> wearables) async {
  Wearable? left;
  Wearable? right;

  for (final wearable in wearables) {
    if (!_isEdgeRecordingEarable(wearable)) {
      continue;
    }
    final position = await wearable.requireCapability<StereoDevice>().position;
    if (position == DevicePosition.left) {
      left ??= wearable;
    } else if (position == DevicePosition.right) {
      right ??= wearable;
    }
  }

  if (left == null || right == null) {
    return null;
  }
  return EarablePair(left: left, right: right);
}

/// Resolves the connected Plux RESPIRABAN, if present.
Wearable? findRespiban(Iterable<Wearable> wearables) {
  for (final wearable in wearables) {
    if (isRespiban(wearable)) {
      return wearable;
    }
  }
  return null;
}

/// Resolves the full [StudyDeviceSet] required to start a recording.
///
/// Returns `null` when either the OpenEarable pair or the RESPIRABAN is
/// missing.
Future<StudyDeviceSet?> resolveStudyDeviceSet(
  Iterable<Wearable> wearables,
) async {
  final respiban = findRespiban(wearables);
  if (respiban == null) {
    return null;
  }
  final pair = await findEarablePair(wearables);
  if (pair == null) {
    return null;
  }
  return StudyDeviceSet(earables: pair, respiban: respiban);
}

/// Finds the OpenEarable sensor configuration whose name matches [keywords].
///
/// Sensor configuration names are defined by the device firmware at runtime, so
/// matching is done by case-insensitive substring against the provided
/// [keywords] (for example `imu` or `mic`).
SensorConfiguration? findEarableConfiguration(
  Wearable wearable,
  List<String> keywords,
) {
  final configurations = wearable
      .requireCapability<SensorConfigurationManager>()
      .sensorConfigurations;
  for (final configuration in configurations) {
    final name = configuration.name.toLowerCase();
    if (keywords.any((keyword) => name.contains(keyword.toLowerCase()))) {
      return configuration;
    }
  }
  return null;
}

/// Selects the record-only configuration value closest to [targetFrequencyHz].
///
/// "Record only" means the value carries a [RecordSensorConfigOption] but no
/// [StreamSensorConfigOption], so the OpenEarable stores samples to its SD card
/// without streaming them over BLE. Among the matching values the one with the
/// frequency nearest to (and preferably at least) [targetFrequencyHz] is
/// returned. Returns `null` when the configuration exposes no record-only
/// value.
SensorConfigurationValue? recordOnlyValueNearest(
  SensorConfiguration configuration,
  int targetFrequencyHz,
) {
  SensorFrequencyConfigurationValue? nextSmaller;
  SensorFrequencyConfigurationValue? nextBigger;

  for (final value in configuration.values) {
    // The concrete OpenEarable V2 value both extends a frequency value and
    // implements a configurable value, but the two interfaces are unrelated, so
    // each facet is read through its own explicit cast.
    if (value is! SensorFrequencyConfigurationValue ||
        value is! ConfigurableSensorConfigurationValue) {
      continue;
    }
    final options = (value as ConfigurableSensorConfigurationValue).options;
    final isRecordOnly =
        options.any((option) => option is RecordSensorConfigOption) &&
            !options.any((option) => option is StreamSensorConfigOption);
    if (!isRecordOnly) {
      continue;
    }

    final frequencyValue = value;
    if (frequencyValue.frequencyHz < targetFrequencyHz) {
      if (nextSmaller == null ||
          frequencyValue.frequencyHz > nextSmaller.frequencyHz) {
        nextSmaller = frequencyValue;
      }
    } else {
      if (nextBigger == null ||
          frequencyValue.frequencyHz < nextBigger.frequencyHz) {
        nextBigger = frequencyValue;
      }
    }
  }

  return nextBigger ?? nextSmaller;
}

/// Resolves the RESPIRABAN acquisition configuration on [wearable].
RespibanSensorConfiguration? findRespibanConfiguration(Wearable wearable) {
  final configurations = wearable
      .requireCapability<SensorConfigurationManager>()
      .sensorConfigurations;
  for (final configuration in configurations) {
    if (configuration is RespibanSensorConfiguration) {
      return configuration;
    }
  }
  return null;
}
