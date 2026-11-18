import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:open_wearable/apps/activity_tracker/models/activity_models.dart';

/// The CSV export does not declare its gyroscope unit.
enum GyroscopeUnit {
  degreesPerSecond('deg/s', math.pi / 180),
  radiansPerSecond('rad/s', 1);

  const GyroscopeUnit(this.label, this.toRadiansFactor);
  final String label;
  final double toRadiansFactor;
}

/// One unmodified sensor timestamp and vector, before synchronization.
class SensorRow {
  const SensorRow(this.timestampMicros, this.vector);

  final int timestampMicros;
  final MotionVector vector;
}

/// Parses the numeric four-column export; malformed rows are never discarded.
List<SensorRow> parseSensorCsv(String contents, {String source = 'CSV'}) {
  final lines = const LineSplitter().convert(contents);
  if (lines.isEmpty) throw FormatException('$source: empty CSV');
  final header = lines.first.replaceFirst('\uFEFF', '').split(',');
  if (header.length != 4 ||
      header.map((cell) => cell.trim()).join(',') != 'timestamp,X,Y,Z') {
    throw FormatException('$source: expected header timestamp,X,Y,Z');
  }
  final rows = <SensorRow>[];
  for (var line = 1; line < lines.length; line++) {
    if (lines[line].trim().isEmpty) continue;
    final cells = lines[line].split(',');
    if (cells.length != 4) {
      throw FormatException('$source:${line + 1}: expected four columns');
    }
    final timestamp = int.tryParse(cells[0].trim());
    final x = double.tryParse(cells[1].trim());
    final y = double.tryParse(cells[2].trim());
    final z = double.tryParse(cells[3].trim());
    if (timestamp == null ||
        x == null ||
        y == null ||
        z == null ||
        !x.isFinite ||
        !y.isFinite ||
        !z.isFinite) {
      throw FormatException('$source:${line + 1}: invalid timestamp or vector');
    }
    if (rows.isNotEmpty && timestamp <= rows.last.timestampMicros) {
      throw FormatException('$source:${line + 1}: timestamps must increase');
    }
    rows.add(SensorRow(timestamp, MotionVector(x, y, z)));
  }
  if (rows.isEmpty) throw FormatException('$source: no sensor samples');
  return rows;
}

/// Keeps every acceleration packet, even when no usable gyroscope exists.
class JoinedSample {
  const JoinedSample(
    this.motion,
    this.gyroscopeIndex,
    this.gyroscopeOffsetSeconds,
  );

  final MotionSample motion;
  final int? gyroscopeIndex;

  /// Signed gyroscope timestamp minus acceleration timestamp.
  final double? gyroscopeOffsetSeconds;
}

class JoinedRecording {
  const JoinedRecording({
    required this.samples,
    required this.durationSeconds,
    required this.accelerometerSampleRateHz,
    required this.gyroscopeSampleRateHz,
    required this.gyroscopeSamples,
    required this.unmatchedAccelerometerSamples,
    required this.unmatchedGyroscopeSamples,
  });

  final List<JoinedSample> samples;
  final double durationSeconds;
  final double? accelerometerSampleRateHz;
  final double? gyroscopeSampleRateHz;
  final int gyroscopeSamples;
  final int unmatchedAccelerometerSamples;
  final int unmatchedGyroscopeSamples;
}

double? _sampleRate(List<SensorRow> rows) => rows.length < 2
    ? null
    : (rows.length - 1) *
        1000000 /
        (rows.last.timestampMicros - rows.first.timestampMicros);

/// Nearest-time join within an inclusive 20 ms window, with earlier-time ties.
///
/// Like the live buffer, a gyro row can serve multiple acceleration packets.
/// Unmatched gyro rows are rows never selected, not a one-to-one count delta.
/// Session zero is the earliest timestamp of either sensor. Subtract integers
/// before conversion, retaining microsecond precision for epoch timestamps.
JoinedRecording joinSensorRows(
  List<SensorRow> accelerometer,
  List<SensorRow> gyroscope, {
  GyroscopeUnit gyroUnit = GyroscopeUnit.degreesPerSecond,
}) {
  if (accelerometer.isEmpty || gyroscope.isEmpty) {
    throw const FormatException('Both sensors require at least one sample');
  }
  final origin = math.min(
    accelerometer.first.timestampMicros,
    gyroscope.first.timestampMicros,
  );
  final end = math.max(
    accelerometer.last.timestampMicros,
    gyroscope.last.timestampMicros,
  );
  final samples = <JoinedSample>[];
  final usedGyros = List<bool>.filled(gyroscope.length, false);
  var gyroIndex = 0;
  var convertedGyroIndex = -1;
  MotionVector? convertedGyro;
  var unmatchedAccelerometer = 0;
  for (final acceleration in accelerometer) {
    final timestamp = acceleration.timestampMicros;
    while (gyroIndex + 1 < gyroscope.length &&
        (gyroscope[gyroIndex + 1].timestampMicros - timestamp).abs() <
            (gyroscope[gyroIndex].timestampMicros - timestamp).abs()) {
      gyroIndex++;
    }
    final offset = gyroscope[gyroIndex].timestampMicros - timestamp;
    final matched = offset.abs() <= 20000;
    if (matched) {
      usedGyros[gyroIndex] = true;
      if (convertedGyroIndex != gyroIndex) {
        final vector = gyroscope[gyroIndex].vector;
        convertedGyro = gyroUnit == GyroscopeUnit.radiansPerSecond
            ? vector
            : vector * gyroUnit.toRadiansFactor;
        convertedGyroIndex = gyroIndex;
      }
    } else {
      unmatchedAccelerometer++;
    }
    samples.add(
      JoinedSample(
        MotionSample(
          (timestamp - origin) / 1000000,
          acceleration.vector,
          gyroscope: matched ? convertedGyro : null,
        ),
        matched ? gyroIndex : null,
        matched ? offset / 1000000 : null,
      ),
    );
  }
  return JoinedRecording(
    samples: samples,
    durationSeconds: (end - origin) / 1000000,
    accelerometerSampleRateHz: _sampleRate(accelerometer),
    gyroscopeSampleRateHz: _sampleRate(gyroscope),
    gyroscopeSamples: gyroscope.length,
    unmatchedAccelerometerSamples: unmatchedAccelerometer,
    unmatchedGyroscopeSamples: usedGyros.where((used) => !used).length,
  );
}

/// Anonymous manifest entry; source folders and activities remain metadata.
class RecordingDefinition {
  const RecordingDefinition({required this.id, required this.expectedSquats});

  final String id;
  final int expectedSquats;
}

Future<List<RecordingDefinition>> loadManifest(File file) async {
  final decoded = jsonDecode(await file.readAsString());
  if (decoded is! Map<String, dynamic> ||
      decoded['schemaVersion'] != 1 ||
      decoded['recordings'] is! List) {
    throw const FormatException('Unsupported squat manifest');
  }
  final definitions = <RecordingDefinition>[];
  final ids = <String>{};
  for (final entry in decoded['recordings'] as List) {
    if (entry is! Map<String, dynamic>) {
      throw const FormatException('Invalid recording manifest entry');
    }
    final id = entry['id'];
    final expected = entry['expectedSquats'];
    if (id is! String ||
        !RegExp(r'^squat-\d{2}$').hasMatch(id) ||
        expected is! int ||
        expected < 0 ||
        !ids.add(id)) {
      throw const FormatException('Invalid recording ID or expected count');
    }
    definitions.add(RecordingDefinition(id: id, expectedSquats: expected));
  }
  if (definitions.isEmpty) throw const FormatException('Empty squat manifest');
  return definitions;
}

/// Loads only accelerometer.csv and gyroscope.csv under the anonymous ID.
Future<JoinedRecording> loadRecording(
  Directory dataRoot,
  RecordingDefinition definition, {
  GyroscopeUnit gyroUnit = GyroscopeUnit.degreesPerSecond,
}) async {
  final directory = Directory.fromUri(
    dataRoot.absolute.uri.resolve('${definition.id}/'),
  );
  final acceleration = parseSensorCsv(
    await File.fromUri(directory.uri.resolve('accelerometer.csv'))
        .readAsString(),
    source: '${definition.id}/accelerometer.csv',
  );
  final gyroscope = parseSensorCsv(
    await File.fromUri(directory.uri.resolve('gyroscope.csv')).readAsString(),
    source: '${definition.id}/gyroscope.csv',
  );
  return joinSensorRows(acceleration, gyroscope, gyroUnit: gyroUnit);
}
