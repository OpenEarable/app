import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:open_wearable/apps/activity_tracker/models/activity_engine.dart';
import 'package:open_wearable/apps/activity_tracker/models/activity_models.dart';

class _Replay {
  final engine = ActivityEngine();
  double time = 0;
  int steps = 0, reps = 0;
  final jumps = <JumpAttempt>[];
  void sample(
    double z, {
    double dt = 0.01,
    MotionVector? acceleration,
    MotionVector gyro = MotionVector.zero,
  }) {
    time += dt;
    final e = engine.add(
      MotionSample(
        time,
        acceleration ?? MotionVector(0, 0, z),
        gyroscope: gyro,
      ),
    );
    steps += e.steps;
    reps += e.repetitions;
    if (e.jump != null) jumps.add(e.jump!);
  }

  void still([double seconds = 2]) {
    for (var i = 0; i < seconds * 100; i++) {
      sample(ActivityEngine.gravity);
    }
  }

  void walk(int count, double hz) {
    for (var i = 0; i < count / hz * 100; i++) {
      sample(
        ActivityEngine.gravity + 2.8 * math.sin(2 * math.pi * hz * i / 100),
      );
    }
    still(0.4);
  }

  void repeat(ActivityKind kind, int count) {
    engine.select(kind);
    still(1);
    final depth = kind == ActivityKind.squats ? 0.35 : 0.16;
    final period = kind == ActivityKind.squats ? 2.4 : 1.8;
    final omega = 2 * math.pi / period;
    for (var i = 0; i < count * period * 100; i++) {
      sample(
        ActivityEngine.gravity -
            depth / 2 * omega * omega * math.cos(omega * i / 100),
      );
    }
    still(0.8);
  }

  void jump({double flight = 0.4, double landing = 17, double dt = 0.01}) {
    still(1);
    for (var i = 0; i < 10; i++) {
      sample(15);
    }
    for (var i = 0; i < flight / dt; i++) {
      sample(0.2, dt: dt);
    }
    for (var i = 0; i < 6; i++) {
      sample(landing, dt: dt);
    }
    still(1);
  }
}

void main() {
  test('requires a still window and rejects invalid/duplicate timestamps', () {
    final r = _Replay()..still(1);
    expect(r.engine.calibrated, isFalse);
    r.still();
    expect(r.engine.calibrated, isTrue);
    expect(
      r.engine.add(MotionSample(r.time, const MotionVector(0, 0, 100))).steps,
      0,
    );
    r.sample(double.nan);
    expect(r.engine.calibrated, isFalse);
  });
  for (final frequency in [0.8, 1.5, 2.2, 3.0]) {
    test('counts periodic steps at $frequency Hz including the initial bout',
        () {
      final r = _Replay()
        ..still()
        ..walk(20, frequency);
      expect(r.steps, 20);
      expect(r.jumps, isEmpty);
    });
  }
  test('isolated peaks and slow unrelated head movements are not steps', () {
    final r = _Replay()..still();
    for (var i = 0; i < 1000; i++) {
      r.sample(
        ActivityEngine.gravity + 2 * math.sin(2 * math.pi * 0.25 * i / 100),
      );
    }
    expect(r.steps, 0);
  });
  test('gyro propagation rejects pure changes in head orientation', () {
    final r = _Replay()..still();
    for (var i = 0; i < 1000; i++) {
      final t = i / 100;
      final angle = 0.35 * math.sin(2 * math.pi * t);
      final omega = 0.35 * 2 * math.pi * math.cos(2 * math.pi * t);
      r.sample(
        0,
        acceleration: MotionVector(
          ActivityEngine.gravity * math.sin(angle),
          0,
          ActivityEngine.gravity * math.cos(angle),
        ),
        gyro: MotionVector(0, -omega, 0),
      );
    }
    expect(r.steps, 0);
  });
  for (final kind in [ActivityKind.squats, ActivityKind.pushUps]) {
    test('${kind.label} counts full cycles without counting steps', () {
      final r = _Replay()
        ..still()
        ..repeat(kind, 6);
      expect(r.reps, 6);
      expect(r.steps, 0);
    });
  }
  test('incomplete lowering does not count a repetition', () {
    final r = _Replay()..still();
    r.engine.select(ActivityKind.squats);
    r.still(1);
    for (var i = 0; i < 40; i++) {
      r.sample(8.8);
    }
    expect(r.reps, 0);
    r.engine.recalibrate();
    r.still(2);
    expect(r.reps, 0);
  });
  test('estimates jump height from flight time and excludes steps', () {
    final r = _Replay()..still();
    r.engine.select(ActivityKind.jumps);
    r.jump();
    expect(r.jumps, hasLength(1));
    expect(r.jumps.single.heightCm, closeTo(19.6, 1.1));
    expect(r.steps, 0);
  });
  test('clipping and slow samples make height unavailable', () {
    final clipped = _Replay()..still();
    clipped.engine.select(ActivityKind.jumps);
    clipped.jump(landing: 19.6);
    expect(clipped.jumps.single.heightCm, isNull);
    final slow = _Replay()..still();
    slow.engine.select(ActivityKind.jumps);
    slow.jump(dt: 0.04);
    expect(slow.jumps.single.heightCm, isNull);
  });
  test('data gaps discard partial flight and do not invent counts', () {
    final r = _Replay()
      ..still()
      ..walk(10, 2);
    final previous = r.steps;
    r.sample(9.8, dt: 3);
    expect(r.engine.calibrated, isFalse);
    expect(r.steps, previous);
    r.still();
    r.walk(5, 2);
    expect(r.steps, previous + 5);
  });
  test('clock restarts recover and initial calibration can be replayed', () {
    final r = _Replay()..still();
    final saved = r.engine.calibration;
    r.time = 0;
    r.sample(ActivityEngine.gravity);
    expect(r.engine.calibrated, isFalse);
    r.still();
    expect(r.engine.calibrated, isTrue);
    r.engine.restoreCalibration(saved);
    r.walk(5, 2);
    expect(r.steps, 5);
    expect(
      () => r.engine.restoreCalibration({'x': double.nan}),
      throwsArgumentError,
    );
  });
}
