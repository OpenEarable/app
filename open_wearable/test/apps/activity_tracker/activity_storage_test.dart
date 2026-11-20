import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_wearable/apps/activity_tracker/models/activity_models.dart';
import 'package:open_wearable/apps/activity_tracker/services/activity_storage.dart';

class _DiskStorage extends ActivityStorage {
  _DiskStorage(this.root);
  final Directory root;
  @override
  Future<Directory> get directory async => root;
}

void main() {
  test('checkpoints in order and exports raw data and quoted reference trials',
      () async {
    final root = await Directory.systemTemp.createTemp('activity-storage-test');
    addTearDown(() => root.delete(recursive: true));
    final store = _DiskStorage(root);
    await Future.wait([
      store.save({'steps': 1}),
      store.save({'steps': 2}),
    ]);
    expect((await store.load())!['steps'], 2);
    final session = ActivitySession(
      id: 'trial',
      startedAt: DateTime(2026),
      deviceName: 'ear',
    );
    session.trials.add(
      const ValidationTrial(
        participant: 'P01',
        pattern: 'Slow, careful',
        referenceSource: 'Video "A"',
        kind: ActivityKind.steps,
        detected: 99,
        reference: 100,
      ),
    );
    await store.startTrace(session.id);
    store.append(
      const MotionSample(1, MotionVector(0, 0, 9.8)),
      ActivityKind.steps,
      false,
      true,
      0,
      0,
      null,
    );
    final files = await store.export(session);
    expect(files, hasLength(3));
    final metadata = jsonDecode(await File(files.first).readAsString());
    expect(metadata['session']['trials'].single['detected'], 99);
    final raw = await File(files[1]).readAsLines();
    expect(raw, hasLength(2));
    expect(raw.first, contains('sensor_seconds'));
    expect(await File(files.last).readAsString(), contains('"Video ""A"""'));
    await store.closeTrace();
  });
}
