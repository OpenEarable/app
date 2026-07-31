import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart';
import 'package:open_wearable/view_models/sensor_configuration_provider.dart';

void main() {
  test('notifies when the first hardware report matches selected values', () {
    final value = SensorConfigurationValue(key: 'off');
    final configuration = _FakeSensorConfiguration(
      name: 'Example sensor',
      values: [value],
    );
    final manager = _FakeSensorConfigurationManager([configuration]);
    final provider = SensorConfigurationProvider(
      sensorConfigurationManager: manager,
    );
    addTearDown(() async {
      provider.dispose();
      await manager.dispose();
    });

    provider.addSensorConfiguration(
      configuration,
      value,
      markPending: false,
    );
    var notificationCount = 0;
    provider.addListener(() => notificationCount += 1);

    manager.emit({configuration: value});

    expect(provider.hasReceivedConfigurationReport, isTrue);
    expect(provider.isConfigurationApplied(configuration), isTrue);
    expect(notificationCount, 1);
  });
}

class _FakeSensorConfiguration extends SensorConfiguration {
  const _FakeSensorConfiguration({
    required super.name,
    required super.values,
  });

  @override
  void setConfiguration(SensorConfigurationValue configuration) {}
}

class _FakeSensorConfigurationManager implements SensorConfigurationManager {
  _FakeSensorConfigurationManager(this.sensorConfigurations);

  final StreamController<Map<SensorConfiguration, SensorConfigurationValue>>
      _controller =
      StreamController<Map<SensorConfiguration, SensorConfigurationValue>>(
    sync: true,
  );

  @override
  final List<SensorConfiguration> sensorConfigurations;

  @override
  Stream<Map<SensorConfiguration, SensorConfigurationValue>>
      get sensorConfigurationStream => _controller.stream;

  void emit(Map<SensorConfiguration, SensorConfigurationValue> report) {
    _controller.add(report);
  }

  Future<void> dispose() => _controller.close();
}
