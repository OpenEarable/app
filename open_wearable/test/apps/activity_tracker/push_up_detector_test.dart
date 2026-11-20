import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:open_wearable/apps/activity_tracker/models/activity_engine.dart';
import 'package:open_wearable/apps/activity_tracker/models/activity_models.dart';

/// Independent kinematic input: quintic rest-to-rest displacement segments.
/// These ideal signals exercise logic; they are not earable accuracy evidence.
class _PushUpReplay {
  _PushUpReplay({
    this.dt = 0.01,
    this.up = const MotionVector(0, 0, 1),
    this.noise = 0,
  });
  final double dt, noise;
  final _random = math.Random(42);
  final MotionVector up;
  final engine = ActivityEngine();
  double time = 0, bias = 0;
  int repetitions = 0, steps = 0, restartSamples = 0;

  void sample(double acceleration, {MotionVector gyro = MotionVector.zero}) {
    time += dt;
    final update = engine.add(
      MotionSample(
        time,
        up *
            (ActivityEngine.gravity +
                acceleration +
                bias +
                noise * (2 * _random.nextDouble() - 1)),
        gyroscope: gyro,
      ),
    );
    repetitions += update.repetitions;
    steps += update.steps;
    if (engine.phase == 'Hold the start position') restartSamples++;
  }

  void hold(double seconds, {MotionVector gyro = MotionVector.zero}) {
    for (var i = 0; i < (seconds / dt).round(); i++) {
      sample(0, gyro: gyro);
    }
  }

  void start() {
    hold(2);
    engine.select(ActivityKind.pushUps);
    hold(1);
    restartSamples = 0;
  }

  void move(double distance, double seconds) {
    final count = (seconds / dt).round();
    final duration = count * dt;
    for (var i = 0; i < count; i++) {
      final u = (i + 0.5) / count;
      sample(
        distance /
            (duration * duration) *
            (60 * u - 180 * u * u + 120 * u * u * u),
      );
    }
  }

  void cycle({
    double depth = 0.16,
    double period = 1.8,
    double pause = 0,
  }) {
    move(-depth, period / 2);
    hold(pause);
    move(depth, period / 2);
    hold(pause);
  }
}

void main() {
  for (final depth in [0.08, 0.16, 0.25]) {
    for (final period in [1.0, 1.8, 3.0, 5.0, 7.0]) {
      test('six full push-ups: depth=$depth, period=$period', () {
        final r = _PushUpReplay()..start();
        for (var i = 0; i < 6; i++) {
          r.cycle(depth: depth, period: period);
        }
        r.hold(1);
        expect(r.repetitions, 6);
        expect(r.steps, 0);
      });
    }
  }
  for (final dt in [0.02, 0.01, 0.005]) {
    test('counts continuous repetitions at dt=$dt', () {
      final r = _PushUpReplay(dt: dt)..start();
      for (var i = 0; i < 6; i++) {
        r.cycle();
      }
      r.hold(1);
      expect(r.repetitions, 6);
    });
  }
  for (final pause in [1.0, 3.0]) {
    test('holds of $pause seconds preserve complete repetitions', () {
      final r = _PushUpReplay()..start();
      for (var i = 0; i < 6; i++) {
        r.cycle(pause: pause);
      }
      expect(r.repetitions, 6);
    });
  }
  for (final returned in [0.0, 0.02, 0.04, 0.08]) {
    test('a bottom hold followed by $returned m return is not a full rep', () {
      final r = _PushUpReplay()..start();
      r.move(-0.16, 0.9);
      r.hold(3);
      r.move(returned, 0.9);
      r.hold(5);
      expect(r.repetitions, 0);
    });
  }
  for (final noise in [0.02, 0.05, 0.1]) {
    test('counts six repetitions with bounded synthetic noise $noise', () {
      final r = _PushUpReplay(noise: noise)..start();
      for (var i = 0; i < 6; i++) {
        r.cycle();
      }
      r.hold(1);
      expect(r.repetitions, 6);
    });
  }
  test('repeated shallow movements do not accumulate into a repetition', () {
    final r = _PushUpReplay()..start();
    for (var i = 0; i < 6; i++) {
      r.cycle(depth: 0.01);
    }
    r.hold(1);
    expect(r.repetitions, 0);
  });
  for (final period in [2.0, 3.0, 5.0]) {
    test('counts smaller head excursions without repeated setup: $period s',
        () {
      final r = _PushUpReplay()..start();
      for (var i = 0; i < 8; i++) {
        r.cycle(depth: 0.04, period: period);
      }
      r.hold(1);
      expect(r.repetitions, 8);
      expect(r.restartSamples, 0);
    });
  }
  test('a rejected rotation does not require holding the starting pose again',
      () {
    final r = _PushUpReplay()..start();
    for (var i = 0; i < 6; i++) {
      r.sample(0, gyro: const MotionVector(0, 0, 2));
      r.cycle();
    }
    r.hold(1);
    expect(r.repetitions, 6);
    expect(r.restartSamples, 0);
  });
  test('a clipped sample does not require a new starting-pose hold', () {
    final r = _PushUpReplay()..start();
    r.sample(20);
    r.cycle();
    r.hold(1);
    expect(r.repetitions, 1);
    expect(r.restartSamples, 0);
  });
  test('a partial return and reversal skips the cycle without rearming', () {
    final r = _PushUpReplay()..start();
    r.move(-0.16, 0.9);
    r.move(0.04, 0.6);
    r.move(-0.04, 0.6);
    r.hold(1);
    expect(r.repetitions, 0);
    expect(r.restartSamples, 0);
  });
  for (final lowering in [0.6, 2.0]) {
    test('uneven down/up tempo $lowering seconds needs no extra hold', () {
      final r = _PushUpReplay()..start();
      for (var i = 0; i < 6; i++) {
        r.move(-0.06, lowering);
        r.move(0.06, 2.6 - lowering);
      }
      r.hold(1);
      expect(r.repetitions, 6);
      expect(r.restartSamples, 0);
    });
  }
  test('returning only after the movement timeout does not count', () {
    final r = _PushUpReplay()..start();
    r.move(-0.16, 0.9);
    r.hold(9);
    expect(r.restartSamples, 0);
    r.move(0.16, 0.9);
    r.hold(1);
    expect(r.repetitions, 0);
    r.cycle();
    r.hold(1);
    expect(r.repetitions, 1);
  });
  test('settling also requires a quiet gyroscope', () {
    final r = _PushUpReplay()..hold(2);
    r.engine.select(ActivityKind.pushUps);
    r.hold(1, gyro: const MotionVector(0, 0, 0.5));
    expect(r.engine.phase, 'Hold the start position');
    r.hold(1);
    r.cycle();
    r.hold(1);
    expect(r.repetitions, 1);
  });
  test('a strong head rotation discards a partial repetition', () {
    final r = _PushUpReplay()..start();
    r.move(-0.16, 0.9);
    r.sample(0, gyro: const MotionVector(0, 0, 2));
    r.move(0.16, 0.9);
    r.hold(1);
    expect(r.repetitions, 0);
    r.cycle();
    r.hold(1);
    expect(r.repetitions, 1);
  });
  test('a clipped impact discards the current repetition', () {
    final r = _PushUpReplay()..start();
    r.move(-0.16, 0.9);
    r.sample(20);
    r.move(0.16, 0.9);
    r.hold(2);
    expect(r.repetitions, 0);
    r.cycle();
    r.hold(1);
    expect(r.repetitions, 1);
  });
  test('a data gap discards a partial cycle and requires calibration', () {
    final r = _PushUpReplay()..start();
    r.move(-0.16, 0.9);
    r.time += 1;
    r.sample(0);
    expect(r.engine.calibrated, isFalse);
    r.move(0.16, 0.9);
    r.hold(3);
    expect(r.repetitions, 0);
    r.cycle();
    r.hold(1);
    expect(r.repetitions, 1);
  });
  test('switching modes discards a partial push-up', () {
    final r = _PushUpReplay()..start();
    r.move(-0.16, 0.9);
    r.engine.select(ActivityKind.squats);
    r.engine.select(ActivityKind.pushUps);
    r.move(0.16, 0.9);
    r.hold(1);
    expect(r.repetitions, 0);
    r.cycle();
    r.hold(1);
    expect(r.repetitions, 1);
  });
  test('calibration supports a different fixed earable orientation', () {
    final r = _PushUpReplay(up: const MotionVector(0, 1, 0))..start();
    for (var i = 0; i < 6; i++) {
      r.cycle();
    }
    r.hold(1);
    expect(r.repetitions, 6);
  });
  for (final bias in [-0.05, 0.05]) {
    test('starting-pose calibration removes residual offset $bias', () {
      final r = _PushUpReplay()..start();
      r.bias = bias;
      r.engine.select(ActivityKind.pushUps);
      r.hold(1);
      for (var i = 0; i < 6; i++) {
        r.cycle();
      }
      r.hold(1);
      expect(r.repetitions, 6);
    });
  }
  for (final changedBias in [-0.005, -0.01, 0.01]) {
    test(
        'a small offset change during the set does not stall Lowering: $changedBias',
        () {
      final r = _PushUpReplay()..start();
      r.bias = changedBias;
      for (var i = 0; i < 6; i++) {
        r.cycle();
      }
      r.hold(1);
      expect(r.repetitions, 6);
      expect(r.restartSamples, 0);
    });
  }
  test('small stationary acceleration residuals do not invent repetitions', () {
    for (final bias in [-0.1, -0.05, 0.05, 0.1]) {
      final r = _PushUpReplay()..start();
      for (var i = 0; i < 12000; i++) {
        r.sample(bias);
      }
      expect(r.repetitions, 0, reason: 'bias=$bias');
    }
  });
}
