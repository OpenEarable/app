import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart';
import 'package:open_wearable/apps/posture_tracker/model/earable_attitude_tracker.dart';
import 'package:open_wearable/view_models/sensor_configuration_provider.dart';

class Configuration extends SensorConfiguration {
  Configuration()
      : super(
          name: 'IMU',
          values: [SensorConfigurationValue(key: '25 Hz stream')],
          offValue: SensorConfigurationValue(key: 'off'),
        );
  final requests = <String>[];
  @override
  void setConfiguration(SensorConfigurationValue value) =>
      requests.add(value.key);
}

class Accel extends Sensor<SensorDoubleValue> {
  Accel(Configuration c)
      : super(
          sensorName: 'Accelerometer',
          chartTitle: 'Acceleration',
          shortChartTitle: 'Acc',
          relatedConfigurations: [c],
        );
  final controller = StreamController<SensorDoubleValue>.broadcast();
  @override
  List<String> get axisNames => ['X', 'Y', 'Z'];
  @override
  List<String> get axisUnits => ['m/s2', 'm/s2', 'm/s2'];
  @override
  Stream<SensorDoubleValue> get sensorStream => controller.stream;
  void emit(int time) =>
      controller.add(SensorDoubleValue(values: [0, 0, 9.8], timestamp: time));
}

class Sensors implements SensorManager {
  Sensors(this.sensors);
  @override
  final List<Sensor> sensors;
}

class Configs implements SensorConfigurationManager {
  Configs(this.sensorConfigurations);
  @override
  final List<SensorConfiguration> sensorConfigurations;
  @override
  Stream<Map<SensorConfiguration, SensorConfigurationValue>>
      get sensorConfigurationStream => const Stream.empty();
}

void main() {
  test('resuming posture does not replay readings accumulated while stopped',
      () async {
    final c = Configuration();
    final sensor = Accel(c);
    final provider =
        SensorConfigurationProvider(sensorConfigurationManager: Configs([c]));
    final tracker = EarableAttitudeTracker(Sensors([sensor]), provider, true);
    var received = 0;
    tracker.listen((_) {
      received++;
    });
    tracker.start();
    sensor.emit(0);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    tracker.stop();
    final before = received;
    expect(c.requests, ['25 Hz stream', 'off']);
    expect(tracker.isTracking, isFalse);
    for (var i = 1; i <= 1000; i++) {
      sensor.emit(i);
    }
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(received, before);
    tracker.start();
    await Future<void>.delayed(const Duration(milliseconds: 100));
    final replayed = received - before;
    expect(
      replayed,
      0,
      reason:
          'Stopped samples must not be replayed as live posture after resume',
    );
    expect(c.requests, ['25 Hz stream', 'off', '25 Hz stream']);
    tracker.start();
    expect(
      c.requests.length,
      3,
      reason: 'Repeated start must not create another subscription',
    );
    sensor.emit(1001);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(received, before + 1);
    // Let the existing attitude filter settle before checking calibration.
    for (var i = 0; i < 64; i++) {
      sensor.emit(1002 + i);
    }
    await Future<void>.delayed(const Duration(milliseconds: 20));
    tracker.calibrateToCurrentAttitude();
    sensor.emit(1066);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(tracker.attitude.roll, closeTo(0, 1e-8));
    tracker.stop();
    tracker.start();
    sensor.emit(1067);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(
      tracker.attitude.roll,
      closeTo(0, 1e-8),
      reason: 'Resume preserves calibration',
    );
    tracker.cancel();
    provider.dispose();
    await sensor.controller.close();
  });
}
