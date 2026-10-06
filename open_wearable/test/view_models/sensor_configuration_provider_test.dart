import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart';
import 'package:open_wearable/view_models/sensor_configuration_provider.dart';

void main() {
  test('accepts unchanged device state after a submitted request is rejected',
      () {
    final off = SensorConfigurationValue(key: 'off');
    final record = SensorConfigurationValue(key: '8 Hz record');
    final configuration = _FakeSensorConfiguration(
      name: 'Temperature',
      values: [off, record],
    );
    final manager = _FakeSensorConfigurationManager([configuration]);
    final provider = SensorConfigurationProvider(
      sensorConfigurationManager: manager,
    );
    addTearDown(() async {
      provider.dispose();
      await manager.dispose();
    });

    manager.emit({configuration: off});
    provider.addSensorConfiguration(configuration, record);
    provider.applyConfiguration(configuration, record);
    expect(configuration.requests, [record]);

    manager.emit({configuration: off});
    expect(provider.getSelectedConfigurationValue(configuration), off);
    expect(provider.isConfigurationPending(configuration), isFalse);
    expect(provider.isConfigurationApplied(configuration), isTrue);
  });

  test('reports for submitted settings preserve newer and unsubmitted edits',
      () {
    final off = SensorConfigurationValue(key: 'off');
    final stream = SensorConfigurationValue(key: '8 Hz stream');
    final record = SensorConfigurationValue(key: '8 Hz record');
    final first = _FakeSensorConfiguration(
      name: 'Temperature',
      values: [off, stream, record],
    );
    final second = _FakeSensorConfiguration(
      name: 'Pressure',
      values: [off, stream, record],
    );
    final manager = _FakeSensorConfigurationManager([first, second]);
    final provider = SensorConfigurationProvider(
      sensorConfigurationManager: manager,
    );
    addTearDown(() async {
      provider.dispose();
      await manager.dispose();
    });

    manager.emit({first: stream, second: off});
    provider.addSensorConfiguration(first, record);
    provider.addSensorConfiguration(second, stream);
    manager.emit({first: stream, second: off});
    expect(provider.getSelectedConfigurationValue(first), record);

    provider.applyConfiguration(first, record);
    manager.emit({first: stream, second: off});
    expect(provider.getSelectedConfigurationValue(first), stream);
    expect(provider.getSelectedConfigurationValue(second), stream);
    expect(provider.isConfigurationPending(second), isTrue);

    provider.applyConfiguration(first, record);
    provider.addSensorConfiguration(first, off);
    manager.emit({first: record, second: off});
    expect(provider.getSelectedConfigurationValue(first), off);
    expect(provider.isConfigurationPending(first), isTrue);
  });

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
  _FakeSensorConfiguration({
    required super.name,
    required super.values,
  });

  final List<SensorConfigurationValue> requests = [];

  @override
  void setConfiguration(SensorConfigurationValue configuration) {
    requests.add(configuration);
  }
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
