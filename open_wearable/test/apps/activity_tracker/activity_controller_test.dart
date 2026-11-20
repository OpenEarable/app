import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_wearable/apps/activity_tracker/models/activity_models.dart';
import 'package:open_wearable/apps/activity_tracker/view_models/activity_tracker_controller.dart';
import 'activity_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('session survives mode changes, disconnect, pause and restart recovery',
      () async {
    final source = ReplayActivitySource();
    final storage = MemoryActivityStorage();
    final c = ActivityTrackerController(
      source: source,
      storage: storage,
      observeLifecycle: false,
    );
    await c.prepare('ear');
    source.still();
    expect(c.engine.calibrated, isTrue);
    await c.start();
    source.walk(10);
    expect(c.current!.steps, 10);
    expect(c.todaySteps, 10);
    c.startExercise(ActivityKind.squats);
    source.walk(6);
    expect(c.current!.steps, 10);
    c.finishSet();
    c.pause();
    source.walk(10);
    expect(c.current!.steps, 10);
    c.resume();
    source.still();
    source.walk(5);
    expect(c.current!.steps, 15);
    source.status.add('Connection lost');
    expect(c.connected, isFalse);
    expect(c.current!.steps, 15);
    source.still();
    source.walk(5);
    expect(c.current!.steps, 20);
    await c.checkpoint();
    expect(storage.rawSamples, greaterThan(1000));
    c.dispose();
    await Future<void>.delayed(Duration.zero);
    final restored = ActivityTrackerController(
      source: ReplayActivitySource(),
      storage: storage,
      observeLifecycle: false,
    );
    await restored.ready;
    expect(restored.isTracking, isFalse);
    expect(restored.sessions.single.steps, 20);
    expect(restored.sessions.single.interrupted, isTrue);
    expect(restored.sessions.single.endedAt, isNotNull);
    expect(restored.todaySteps, 20);
    restored.dispose();
  });
  test('foreground resumes with calibration; background never adds counts',
      () async {
    final source = ReplayActivitySource();
    final c = ActivityTrackerController(
      source: source,
      storage: MemoryActivityStorage(),
      observeLifecycle: false,
    );
    await c.prepare('ear');
    source.still();
    await c.start();
    c.didChangeAppLifecycleState(AppLifecycleState.paused);
    source.walk(10);
    expect(c.current!.steps, 0);
    c.didChangeAppLifecycleState(AppLifecycleState.resumed);
    source.still();
    source.walk(5);
    expect(c.current!.steps, 5);
    final session = await c.finish();
    expect(session!.endedAt, isNotNull);
    expect(c.isTracking, isFalse);
    expect(source.closed, isTrue);
    c.dispose();
  });
  test('reference errors and unavailable height survive serialization', () {
    final session = ActivitySession(
      id: 'test',
      startedAt: DateTime(2026),
      deviceName: 'ear',
    );
    session.trials.add(
      const ValidationTrial(
        participant: 'P01',
        pattern: 'Slow',
        referenceSource: 'Video',
        kind: ActivityKind.squats,
        detected: 19,
        reference: 20,
      ),
    );
    session.trials.add(
      const ValidationTrial(
        participant: 'P02',
        pattern: 'Head turn',
        referenceSource: 'Video',
        kind: ActivityKind.steps,
        detected: 1,
        reference: 0,
      ),
    );
    session.jumps.add(
      const JumpAttempt(at: 2, flightSeconds: 0.3, reason: 'Impact clipped'),
    );
    final copy = ActivitySession.fromJson(session.toJson());
    expect(copy.trials.first.countError, -1);
    expect(copy.trials.first.absolutePercentageError, 5);
    expect(copy.trials.last.absolutePercentageError, isNull);
    expect(copy.jumps.single.heightCm, isNull);
  });
}
