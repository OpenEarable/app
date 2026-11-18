import 'dart:convert';
import 'dart:io';

import 'package:open_wearable/apps/activity_tracker/models/activity_engine.dart';
import 'package:open_wearable/apps/activity_tracker/models/activity_models.dart';
import 'recordings.dart';

const _usage = 'Usage: dart run tool/squats/replay.dart '
    '[data-root] [--gyro-unit=deg/s|rad/s]';

/// Replays the entire recording in squat mode, with no calibration restoration,
/// synthetic pre-roll, activity-boundary labels, or omitted acceleration rows.
Map<String, Object?> replayRecording(
  RecordingDefinition definition,
  JoinedRecording recording, {
  GyroscopeUnit gyroUnit = GyroscopeUnit.degreesPerSecond,
}) {
  final engine = ActivityEngine()..select(ActivityKind.squats);
  final events = <double>[];
  var calibratedSamples = 0;
  var interruptionCount = 0;
  var interrupted = false;
  double? firstCalibrationSeconds;
  for (final sample in recording.samples) {
    if (sample.motion.gyroscope == null) {
      // Null gyro is not zero angular speed. Invalidate this explicit packet,
      // including short holes that the engine's timestamp-gap test would miss.
      engine.recalibrate();
      if (!interrupted) interruptionCount++;
      interrupted = true;
      continue;
    }
    interrupted = false;
    final update = engine.add(sample.motion);
    if (engine.calibrated) {
      calibratedSamples++;
      firstCalibrationSeconds ??= sample.motion.seconds;
    }
    for (var repetition = 0; repetition < update.repetitions; repetition++) {
      events.add(sample.motion.seconds);
    }
  }
  return {
    'id': definition.id,
    'expected': definition.expectedSquats,
    'detected': events.length,
    'error': events.length - definition.expectedSquats,
    'durationSeconds': recording.durationSeconds,
    'gyroInputUnit': gyroUnit.label,
    'samples': {
      'accelerometer': recording.samples.length,
      'gyroscope': recording.gyroscopeSamples,
      'matchedAccelerometer':
          recording.samples.length - recording.unmatchedAccelerometerSamples,
      'unmatchedAccelerometer': recording.unmatchedAccelerometerSamples,
      'unmatchedGyroscope': recording.unmatchedGyroscopeSamples,
      'unmatchedGyroscopeInterruptionSpans': interruptionCount,
    },
    'sampleRatesHz': {
      'accelerometer': recording.accelerometerSampleRateHz,
      'gyroscope': recording.gyroscopeSampleRateHz,
    },
    'calibration': {
      'calibratedSampleFraction': calibratedSamples / recording.samples.length,
      'firstCalibrationSeconds': firstCalibrationSeconds,
      'calibratedAtEnd': engine.calibrated,
    },
    'detectedEventSeconds': events,
  };
}

Future<void> main(List<String> arguments) async {
  String? dataPath;
  var gyroUnit = GyroscopeUnit.degreesPerSecond;
  for (final argument in arguments) {
    if (argument == '--help' || argument == '-h') {
      stdout.writeln(_usage);
      return;
    }
    if (argument.startsWith('--gyro-unit=')) {
      final label = argument.substring('--gyro-unit='.length);
      switch (label) {
        case 'deg/s':
          gyroUnit = GyroscopeUnit.degreesPerSecond;
        case 'rad/s':
          gyroUnit = GyroscopeUnit.radiansPerSecond;
        default:
          stderr.writeln('Unsupported gyroscope unit: $label\n$_usage');
          exitCode = 64;
          return;
      }
    } else if (argument.startsWith('-') || dataPath != null) {
      stderr.writeln(_usage);
      exitCode = 64;
      return;
    } else {
      dataPath = argument;
    }
  }

  final dataRoot = dataPath == null
      ? Directory.fromUri(Platform.script.resolve('data/'))
      : Directory(dataPath);
  final results = <Map<String, Object?>>[];
  try {
    final definitions = await loadManifest(
      File.fromUri(Platform.script.resolve('manifest.json')),
    );
    for (final definition in definitions) {
      try {
        final recording = await loadRecording(
          dataRoot,
          definition,
          gyroUnit: gyroUnit,
        );
        results.add(replayRecording(definition, recording, gyroUnit: gyroUnit));
      } on FileSystemException catch (error) {
        stderr.writeln('${definition.id}: missing or unreadable data: $error');
        exitCode = 1;
      } on FormatException catch (error) {
        stderr.writeln('${definition.id}: malformed data: $error');
        exitCode = 1;
      }
    }
  } on FileSystemException catch (error) {
    stderr.writeln('Missing or unreadable manifest: $error');
    exitCode = 1;
  } on FormatException catch (error) {
    stderr.writeln('Malformed manifest: $error');
    exitCode = 1;
  }
  // Count mismatches are evaluation results, not process failures. When data
  // fails, stdout contains only valid recordings and the process exits nonzero.
  stdout.writeln(const JsonEncoder.withIndent('  ').convert(results));
}
