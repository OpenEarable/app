import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';

import '../../tool/squats/recordings.dart';

List<SensorRow> _rows(List<int> timestamps, {String vector = '1,2,3'}) =>
    parseSensorCsv('timestamp,X,Y,Z\n'
        '${timestamps.map((time) => '$time,$vector').join('\n')}\n');

void main() {
  test('subtracts the common microsecond origin before converting to seconds',
      () {
    const origin = 1794414169562002;
    final joined = joinSensorRows(
      _rows([origin + 1, origin + 10001]),
      _rows([origin, origin + 10000]),
    );
    expect(joined.samples[0].motion.seconds, closeTo(0.000001, 1e-12));
    expect(joined.samples[1].motion.seconds, closeTo(0.010001, 1e-12));
    expect(joined.durationSeconds, closeTo(0.010001, 1e-12));
    expect(joined.accelerometerSampleRateHz, closeTo(100, 1e-12));
    expect(joined.gyroscopeSampleRateHz, closeTo(100, 1e-12));
    expect(joined.samples[0].motion.acceleration.x, 1);
  });

  test('chooses nearest gyro, including future rows, with earlier ties', () {
    final joined = joinSensorRows(
      _rows([9000, 15000, 19000, 39000]),
      _rows([0, 10000, 20000, 40000]),
    );
    expect(joined.samples.map((sample) => sample.gyroscopeIndex), [1, 1, 2, 3]);
    expect(joined.samples[0].gyroscopeOffsetSeconds, closeTo(0.001, 1e-12));
    expect(joined.samples[1].gyroscopeOffsetSeconds, closeTo(-0.005, 1e-12));
    expect(joined.unmatchedAccelerometerSamples, 0);
    expect(joined.unmatchedGyroscopeSamples, 1);
  });

  test('converts assumed degrees per second to radians on all axes', () {
    final joined = joinSensorRows(
      _rows([0]),
      _rows([0], vector: '180,-90,360'),
    );
    final gyro = joined.samples.single.motion.gyroscope!;
    expect(gyro.x, closeTo(math.pi, 1e-12));
    expect(gyro.y, closeTo(-math.pi / 2, 1e-12));
    expect(gyro.z, closeTo(2 * math.pi, 1e-12));
    expect(joined.accelerometerSampleRateHz, isNull);
  });

  test('explicit rad/s retains the original gyroscope vector', () {
    final joined = joinSensorRows(
      _rows([0]),
      _rows([0], vector: '1,-2,3'),
      gyroUnit: GyroscopeUnit.radiansPerSecond,
    );
    final gyro = joined.samples.single.motion.gyroscope!;
    expect([gyro.x, gyro.y, gyro.z], [1, -2, 3]);
  });

  test('20 ms is inclusive and missing gyro preserves every acceleration row',
      () {
    final joined = joinSensorRows(
      _rows([0, 20000, 40000, 40001, 200000]),
      _rows([20000, 200000, 300000]),
    );
    expect(joined.samples, hasLength(5));
    expect(
      joined.samples.map((sample) => sample.motion.seconds),
      [0, 0.02, 0.04, 0.040001, 0.2],
    );
    expect(
      joined.samples.map((sample) => sample.gyroscopeIndex),
      [0, 0, 0, null, 1],
    );
    expect(joined.samples[3].motion.gyroscope, isNull);
    expect(joined.samples[3].gyroscopeOffsetSeconds, isNull);
    expect(joined.unmatchedAccelerometerSamples, 1);
    expect(joined.unmatchedGyroscopeSamples, 1);
    expect(joined.durationSeconds, 0.3);
  });

  test('completely nonoverlapping sensor times are explicit unmatched samples',
      () {
    final joined = joinSensorRows(_rows([0, 10000]), _rows([1000000]));
    expect(joined.samples, hasLength(2));
    expect(
      joined.samples.every((sample) => sample.motion.gyroscope == null),
      isTrue,
    );
    expect(joined.unmatchedAccelerometerSamples, 2);
    expect(joined.unmatchedGyroscopeSamples, 1);
  });

  test('accepts BOM, CRLF and surrounding numeric whitespace', () {
    final rows = parseSensorCsv('\uFEFFtimestamp,X,Y,Z\r\n1, 2, 3, 4\r\n');
    expect(rows.single.timestampMicros, 1);
    expect(rows.single.vector.x, 2);
  });

  for (final csv in [
    '',
    'timestamp,X,Y,Z\n',
    'time,X,Y,Z\n1,2,3,4\n',
    'timestamp,X,Y,Z\n1,2,3\n',
    'timestamp,X,Y,Z\n1.5,2,3,4\n',
    'timestamp,X,Y,Z\n1,NaN,3,4\n',
    'timestamp,X,Y,Z\n1,2,Infinity,4\n',
    'timestamp,X,Y,Z\n1,2,3,4\n1,2,3,4\n',
    'timestamp,X,Y,Z\n2,2,3,4\n1,2,3,4\n',
  ]) {
    test('rejects malformed CSV: ${csv.replaceAll('\n', r'\n')}', () {
      expect(() => parseSensorCsv(csv), throwsFormatException);
    });
  }

  test('empty gyro data cannot be replaced with synthetic samples', () {
    expect(() => joinSensorRows(_rows([0]), []), throwsFormatException);
  });

  test('missing gyro file fails rather than supplying a zero vector', () async {
    final root = await Directory.systemTemp.createTemp('squat-recording-test-');
    addTearDown(() => root.delete(recursive: true));
    final directory =
        await Directory.fromUri(root.uri.resolve('squat-01/')).create();
    await File.fromUri(directory.uri.resolve('accelerometer.csv'))
        .writeAsString('timestamp,X,Y,Z\n1,0,0,9.80665\n');
    await expectLater(
      loadRecording(
        root,
        const RecordingDefinition(id: 'squat-01', expectedSquats: 10),
      ),
      throwsA(isA<FileSystemException>()),
    );
  });
}
