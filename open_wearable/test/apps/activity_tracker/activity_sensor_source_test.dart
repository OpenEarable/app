import 'dart:async';
import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart';
import 'package:open_wearable/apps/activity_tracker/models/activity_models.dart';
import 'package:open_wearable/apps/activity_tracker/services/activity_sensor_source.dart';
import 'package:open_wearable/view_models/sensor_configuration_provider.dart';
import 'package:open_wearable/view_models/wearables_provider.dart';

class _Config
    extends SensorFrequencyConfiguration<SensorFrequencyConfigurationValue> {
  _Config()
      : super(
          name: 'IMU',
          values: [
            for (final hz in [0, 50, 100, 200])
              SensorFrequencyConfigurationValue(frequencyHz: hz.toDouble()),
          ],
        );
  final requests = <double>[];
  @override
  void setConfiguration(SensorFrequencyConfigurationValue value) {
    requests.add(value.frequencyHz);
  }
}

class _Sensor extends Sensor<SensorDoubleValue> {
  _Sensor(_Config config, {required bool gyro})
      : isGyro = gyro,
        super(
          sensorName: gyro ? 'Gyroscope' : 'Accelerometer',
          chartTitle: 'IMU',
          shortChartTitle: 'IMU',
          timestampExponent: gyro ? -3 : -6,
          relatedConfigurations: [config],
        );
  final bool isGyro;
  final data = StreamController<SensorDoubleValue>.broadcast(sync: true);
  @override
  List<String> get axisNames => ['x', 'y', 'z'];
  @override
  List<String> get axisUnits => List.filled(3, isGyro ? 'dps' : 'm/s²');
  @override
  Stream<SensorDoubleValue> get sensorStream => data.stream;
  void emit(double seconds) => data.add(
        SensorDoubleValue(
          values: isGyro ? [0, 180, 0] : [0, 0, 9.80665],
          timestamp: (seconds * (isGyro ? 1000 : 1000000)).round(),
        ),
      );
}

class _Ear extends Wearable
    implements SensorManager, SensorConfigurationManager {
  _Ear({this.includeGyro = true})
      : super(
          name: 'OpenEarable 2.0',
          disconnectNotifier: WearableDisconnectNotifier(),
        );
  final config = _Config();
  final bool includeGyro;
  late final acc = _Sensor(config, gyro: false);
  late final gyro = _Sensor(config, gyro: true);
  @override
  String get deviceId => 'ear';
  @override
  List<Sensor> get sensors => [acc, if (includeGyro) gyro];
  @override
  List<SensorConfiguration> get sensorConfigurations => [config];
  @override
  Stream<Map<SensorConfiguration, SensorConfigurationValue>>
      get sensorConfigurationStream => const Stream.empty();
  @override
  Future<void> disconnect() async {}
}

class _Devices extends WearablesProvider {
  @override
  final wearables = <Wearable>[];
  final configs = <Wearable, SensorConfigurationProvider>{};
  void connect(_Ear ear) {
    wearables.add(ear);
    configs[ear] = SensorConfigurationProvider(sensorConfigurationManager: ear)
      ..addSensorConfiguration(
        ear.config,
        ear.config.values.first,
        markPending: false,
      );
    notifyListeners();
  }

  void drop(_Ear ear) {
    wearables.remove(ear);
    notifyListeners();
  }

  @override
  SensorConfigurationProvider getSensorConfigurationProvider(
    Wearable wearable,
  ) =>
      configs[wearable]!;
  @override
  void dispose() {
    for (final c in configs.values) {
      c.dispose();
    }
    super.dispose();
  }
}

void main() {
  test('missing IMU capability fails once without a retry loop', () async {
    final devices = _Devices();
    final ear = _Ear(includeGyro: false);
    devices.connect(ear);
    final source = OpenEarableActivitySource(devices);
    await expectLater(source.open('ear'), throwsStateError);
    await Future<void>.delayed(Duration.zero);
    expect(ear.config.requests, isEmpty);
    source.dispose();
    await Future<void>.delayed(Duration.zero);
    devices.dispose();
  });
  test(
      'shared IMU configuration, units, batched timestamps, reconnect and restore',
      () async {
    final devices = _Devices();
    final ear = _Ear();
    devices.connect(ear);
    final source = OpenEarableActivitySource(devices);
    final samples = <MotionSample>[];
    final sub = source.samples.listen(samples.add);
    await source.open('ear');
    expect(ear.config.requests, [100]);
    for (var i = 0; i < 10; i++) {
      ear.acc.emit(1 + i / 100);
    }
    for (var i = 0; i < 10; i++) {
      ear.gyro.emit(1 + i / 100);
    }
    await Future<void>.delayed(Duration.zero);
    expect(samples, hasLength(10));
    expect(samples.first.seconds, 1);
    expect(samples.first.gyroscope!.y, closeTo(math.pi, 0.00001));
    devices.drop(ear);
    await Future<void>.delayed(Duration.zero);
    final reconnected = _Ear();
    devices.connect(reconnected);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    reconnected.gyro.emit(2);
    reconnected.acc.emit(2);
    await Future<void>.delayed(Duration.zero);
    expect(samples.last.seconds, 2);
    expect(reconnected.config.requests, [100]);
    await source.close();
    expect(reconnected.config.requests, [100, 0]);
    await sub.cancel();
    source.dispose();
    await Future<void>.delayed(Duration.zero);
    devices.dispose();
  });
  test('does not overwrite IMU settings changed by another consumer', () async {
    final devices = _Devices();
    final ear = _Ear();
    devices.connect(ear);
    final source = OpenEarableActivitySource(devices);
    await source.open('ear');
    devices.configs[ear]!.addSensorConfiguration(
      ear.config,
      ear.config.values.last,
      markPending: false,
    );
    await source.close();
    expect(ear.config.requests, [100]);
    source.dispose();
    await Future<void>.delayed(Duration.zero);
    devices.dispose();
  });
}
