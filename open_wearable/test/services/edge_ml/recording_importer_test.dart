import 'package:flutter_test/flutter_test.dart';
import 'package:open_wearable/services/edge_ml/recording_importer.dart';
import 'package:open_wearable/widgets/sensors/local_recorder/local_recorder_models.dart';

const base = 1793989737000;

Future<EdgeMlRecordingImport> convert(Map<String, String> files) {
  final folder = LocalRecorderRecordingFolder(
    path: 'session',
    name: 'session',
    updatedAt: DateTime(2026),
    files: [
      for (final name in files.keys)
        LocalRecorderRecordingFile(
          path: name,
          name: name,
          sizeBytes: files[name]!.length,
          updatedAt: DateTime(2026),
        ),
    ],
  );
  return const EdgeMlRecordingImporter().read(
    folder,
    readText: (file) async => files[file.name]!,
  );
}

void main() {
  test(
    'keeps left/right channels and independent timestamps without resampling',
    () async {
      final result = await convert({
        'OpenEarable-L-ACCELEROMETER.csv':
            'timestamp,X,Y\n${base * 1000},1,2\n${(base + 20) * 1000},3,4\n',
        'OpenEarable-R-ACCELEROMETER.csv':
            'timestamp,X,Y\n${(base + 7) * 1000},5,6\n',
        'Phone_Pressure.csv': 'timestamp,Pressure\n${base + 12},1000\n',
        'Empty.csv': 'timestamp,X\n',
        'audio.wav': 'not CSV',
      });
      expect(result.recording.length, 7);
      expect(result.channelNames.length, 5);
      expect(result.recording.timeSeries['OpenEarable-L-ACCELEROMETER_X'], [
        (base, 1.0),
        (base + 20, 3.0),
      ]);
      expect(result.recording.timeSeries['OpenEarable-R-ACCELEROMETER_X'], [
        (base + 7, 5.0),
      ]);
      expect(result.recording.timeSeries['Phone_Pressure_Pressure'], [
        (base + 12, 1000.0),
      ]);
      expect(result.firstTimestampMs, base);
      expect(result.lastTimestampMs, base + 20);
      expect(result.recording.units, isEmpty);
      expect(
        result.warnings.any((w) => w.contains('no sensor samples')),
        isTrue,
      );
      expect(result.warnings.any((w) => w.contains('audio.wav')), isTrue);
    },
  );

  test(
    'converts label changes to inclusive ranges with unlabeled gaps',
    () async {
      final result = await convert({
        'Sensor.csv': 'timestamp,X\n$base,1\n${base + 100},2\n',
        'Label_MyLabel.csv':
            'timestamp,Label1,Label2\n'
            '${base + 10},true,false\n'
            '${base + 30},false,true\n'
            '${base + 40},false,false\n'
            '${base + 60},true,false\n',
      });
      final labels = result.recording.labels;
      expect(labels.length, 3);
      expect(labels.map((l) => (l.labeling, l.label, l.start, l.end)), [
        ('MyLabel', 'Label1', base + 10, base + 29),
        ('MyLabel', 'Label2', base + 30, base + 39),
        ('MyLabel', 'Label1', base + 60, base + 100),
      ]);
    },
  );

  test(
    'clips labels to samples and uses last event at an identical timestamp',
    () async {
      final result = await convert({
        'Sensor.csv': 'timestamp,X\n$base,1\n${base + 100},2\n',
        'Label_Group.csv':
            'timestamp,A,B\n'
            '${base - 5},true,false\n'
            '${base + 30},false,false\n'
            '${base + 30},false,true\n'
            '${base + 200},false,false\n',
      });
      expect(result.recording.labels.map((l) => (l.label, l.start, l.end)), [
        ('A', base, base + 29),
        ('B', base + 30, base + 100),
      ]);
    },
  );

  test('does not fabricate labels from a header-only label file', () async {
    final result = await convert({
      'Sensor.csv': 'timestamp,X\n$base,1\n',
      'Label_MyLabel.csv': 'timestamp,Label1,Label2\n',
    });
    expect(result.recording.labels, isEmpty);
    expect(
      result.warnings.any((w) => w.contains('no recorded label states')),
      isTrue,
    );
  });

  test(
    'preserves fast and repeated samples at shared millisecond timestamps',
    () async {
      final result = await convert({
        'Sensor.csv':
            'timestamp,X\n${base * 1000},1\n${base * 1000 + 39},2\n${base * 1000 + 39},3\n${(base + 20) * 1000},4\n',
      });
      expect(result.recording.timeSeries['Sensor_X'], [
        (base, 1.0),
        (base, 2.0),
        (base, 3.0),
        (base + 20, 4.0),
      ]);
      expect(result.recording.length, 4);
      expect(
        result.warnings.any((w) => w.contains('2 additional sample rows')),
        isTrue,
      );
    },
  );

  test(
    'still rejects raw timestamps that move backwards within a millisecond',
    () async {
      await expectLater(
        convert({
          'Sensor.csv':
              'timestamp,X\n${base * 1000 + 500},1\n${base * 1000 + 39},2\n',
        }),
        throwsFormatException,
      );
    },
  );

  test('rejects corrupt values and simultaneous labels', () async {
    await expectLater(
      convert({'Sensor.csv': 'timestamp,X\n$base,NaN\n'}),
      throwsFormatException,
    );
    await expectLater(
      convert({
        'Sensor.csv': 'timestamp,X\n$base,1\n',
        'Label_Group.csv': 'timestamp,A,B\n$base,true,true\n',
      }),
      throwsFormatException,
    );
    await expectLater(
      convert({'Sensor.csv': 'timestamp,X\n'}),
      throwsFormatException,
    );
  });
}
