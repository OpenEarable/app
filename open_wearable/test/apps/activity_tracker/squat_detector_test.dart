import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:open_wearable/apps/activity_tracker/models/activity_engine.dart';
import 'package:open_wearable/apps/activity_tracker/models/activity_models.dart';

// Independent rest-to-rest kinematics, not a model of participant accuracy.
class _SquatReplay {
  _SquatReplay({this.dt = 0.01, this.up = const MotionVector(0, 0, 1)});
  final double dt;
  final MotionVector up;
  final engine = ActivityEngine()..select(ActivityKind.squats);
  double time = 0;
  int count = 0, steps = 0;

  void sample(double acceleration, {MotionVector gyro = MotionVector.zero}) {
    time += dt;
    final event = engine.add(
      MotionSample(
        time,
        up * (ActivityEngine.gravity + acceleration),
        gyroscope: gyro,
      ),
    );
    count += event.repetitions;
    steps += event.steps;
  }

  void hold(double seconds, {MotionVector gyro = MotionVector.zero}) {
    for (var i = 0; i < (seconds / dt).round(); i++) {
      sample(0, gyro: gyro);
    }
  }

  void move(double distance, double seconds) {
    final n = (seconds / dt).round();
    final duration = n * dt;
    for (var i = 0; i < n; i++) {
      final u = (i + 0.5) / n;
      sample(
        distance /
            (duration * duration) *
            (60 * u - 180 * u * u + 120 * u * u * u),
      );
    }
  }

  void cycle(double depth, double period) {
    move(-depth, period / 2);
    move(depth, period / 2);
  }
}

void main() {
  for (final period in [1.5, 2.4, 4.0]) {
    for (final depth in [0.3, 0.45]) {
      test('counts continuous $depth m cycles at $period s', () {
        final r = _SquatReplay()..hold(2);
        for (var i = 0; i < 6; i++) {
          r.cycle(depth, period);
        }
        r.hold(1);
        expect(r.count, 6);
        expect(r.steps, 0);
      });
    }
  }
  for (final dt in [0.02, 0.005]) {
    test('supports ${(1 / dt).round()} Hz and rotated sensor mounting', () {
      final r = _SquatReplay(dt: dt, up: const MotionVector(0, 1, 0))..hold(2);
      for (var i = 0; i < 3; i++) {
        r.cycle(0.35, 2.4);
      }
      r.hold(1);
      expect(r.count, 3);
    });
  }
  test('small repeated head bobs do not accumulate into squats', () {
    final r = _SquatReplay()..hold(2);
    for (var i = 0; i < 10; i++) {
      r.cycle(0.025, 1.5);
    }
    r.hold(2);
    expect(r.count, 0);
  });
  for (final returned in [0.0, 0.04, 0.1]) {
    test('a held descent with $returned m return is not completed', () {
      final r = _SquatReplay()..hold(2);
      r.move(-0.35, 1.2);
      r.hold(1);
      r.move(returned, 1.2);
      r.hold(4);
      expect(r.count, 0);
    });
  }
  test('a complete cycle with a short bottom hold counts once', () {
    final r = _SquatReplay()..hold(2);
    r.move(-0.35, 1.2);
    r.hold(0.5);
    r.move(0.35, 1.2);
    r.hold(1);
    expect(r.count, 1);
  });
  test('long sitting-like holds time out rather than count on standing', () {
    final r = _SquatReplay()..hold(2);
    r.move(-0.35, 1.2);
    r.hold(7);
    r.move(0.35, 1.2);
    r.hold(2);
    expect(r.count, 0);
  });
  test('walking-sized fast cycles with head rotation are rejected', () {
    final r = _SquatReplay()..hold(2);
    for (var i = 0; i < 500; i++) {
      r.sample(
        2.8 * math.sin(2 * math.pi * 2 * i / 100),
        gyro: const MotionVector(0, 0, 1.5),
      );
    }
    r.hold(2);
    expect(r.count, 0);
  });
  for (final interruption in ['rotation', 'clipping', 'gap', 'mode', 'pause']) {
    test('$interruption discards a partial squat and allows the next set', () {
      final r = _SquatReplay()..hold(2);
      r.move(-0.35, 1.2);
      switch (interruption) {
        case 'rotation':
          r.sample(0, gyro: const MotionVector(0, 0, 2));
        case 'clipping':
          r.sample(15);
        case 'gap':
          r.time += 0.3;
          r.sample(0);
        case 'mode':
          r.engine.select(ActivityKind.pushUps);
          r.engine.select(ActivityKind.squats);
        case 'pause':
          r.engine.recalibrate();
      }
      r.move(0.35, 1.2);
      r.hold(2);
      expect(r.count, 0);
      r.cycle(0.35, 2.4);
      r.hold(1);
      expect(r.count, 1);
    });
  }
  test('squat startup tolerates small yaw jitter, but not acceleration swings',
      () {
    final r = _SquatReplay();
    r.hold(1, gyro: const MotionVector(0, 0, 0.25));
    expect(r.engine.calibrated, isTrue);
    r.engine.recalibrate();
    for (var i = 0; i < 200; i++) {
      r.sample(i.isEven ? 0.4 : -0.4);
    }
    expect(r.engine.calibrated, isFalse);
    r.hold(1);
    expect(r.engine.calibrated, isTrue);
  });
}
