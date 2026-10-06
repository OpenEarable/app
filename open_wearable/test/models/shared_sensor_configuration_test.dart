import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart';
import 'package:open_wearable/models/shared_sensor_configuration.dart';

typedef Report = Map<SensorConfiguration, SensorConfigurationValue>;

class _Manager implements SensorConfigurationManager {
  int reads = 0;
  late StreamController<Report> source;
  @override
  List<SensorConfiguration> get sensorConfigurations => [];
  @override
  Stream<Report> get sensorConfigurationStream {
    reads++;
    source = StreamController<Report>(sync: true);
    return source.stream;
  }
}

void main() {
  test('UI and connectors share reports, replay, and independent cancellation',
      () async {
    final manager = _Manager();
    final ui = <Report>[];
    final remote = <Report>[];
    final a = sharedSensorConfiguration(manager).listen(ui.add);
    manager.source.add({});
    final b = sharedSensorConfiguration(manager).listen(remote.add);
    await Future<void>.delayed(Duration.zero);
    expect(manager.reads, 1);
    expect(ui, hasLength(1));
    expect(remote, hasLength(1));
    manager.source.add({});
    expect(ui, hasLength(2));
    expect(remote, hasLength(2));
    await b.cancel();
    expect(manager.source.hasListener, isTrue);
    manager.source.add({});
    expect(ui, hasLength(3));
    await a.cancel();
    expect(manager.source.hasListener, isFalse);
    final c = sharedSensorConfiguration(manager).listen(remote.add);
    await Future<void>.delayed(Duration.zero);
    expect(manager.reads, 2);
    expect(remote, hasLength(2)); // no stale replay after all listeners left
    manager.source.add({});
    expect(remote, hasLength(3));
    await c.cancel();
    await manager.source.close();
  });
  test('hardware errors reach both consumers and completion closes both',
      () async {
    final manager = _Manager();
    final errors = <Object>[];
    var done = 0;
    sharedSensorConfiguration(manager)
        .listen((_) {}, onError: errors.add, onDone: () => done++);
    sharedSensorConfiguration(manager)
        .listen((_) {}, onError: errors.add, onDone: () => done++);
    manager.source.addError(StateError('BLE disconnected'));
    expect(errors, hasLength(2));
    await manager.source.close();
    expect(done, 2);
  });
}
