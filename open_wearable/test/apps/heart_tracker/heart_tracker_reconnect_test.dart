import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart';
import 'package:open_wearable/apps/heart_tracker/widgets/heart_tracker_page.dart';
import 'package:open_wearable/apps/heart_tracker/widgets/rowling_chart.dart';
import 'package:open_wearable/view_models/sensor_configuration_provider.dart';
import 'package:open_wearable/view_models/wearables_provider.dart';
import 'package:provider/provider.dart';

class _Configuration extends SensorConfiguration {
  _Configuration()
      : super(
          name: 'PPG',
          values: [SensorConfigurationValue(key: '50 Hz')],
          offValue: SensorConfigurationValue(key: 'off'),
        );
  final requests = <String>[];
  @override
  void setConfiguration(SensorConfigurationValue value) =>
      requests.add(value.key);
}

class _Ppg extends Sensor<SensorDoubleValue> {
  _Ppg(_Configuration config)
      : super(
          sensorName: 'PPG',
          chartTitle: 'PPG',
          shortChartTitle: 'PPG',
          relatedConfigurations: [config],
        );
  final controller = StreamController<SensorDoubleValue>.broadcast();
  @override
  List<String> get axisNames => ['red', 'ir', 'green', 'ambient'];
  @override
  List<String> get axisUnits => ['raw', 'raw', 'raw', 'raw'];
  @override
  Stream<SensorDoubleValue> get sensorStream => controller.stream;
  void emit(int time) => controller.add(
        SensorDoubleValue(values: [100, 100, 100, 0], timestamp: time),
      );
}

class _Ear extends Wearable
    implements SensorManager, SensorConfigurationManager {
  _Ear(this.deviceId)
      : super(
          name: 'OpenEarable',
          disconnectNotifier: WearableDisconnectNotifier(),
        );
  @override
  final String deviceId;
  final config = _Configuration();
  late final ppg = _Ppg(config);
  @override
  List<Sensor> get sensors => [ppg];
  @override
  List<SensorConfiguration> get sensorConfigurations => [config];
  @override
  Stream<Map<SensorConfiguration, SensorConfigurationValue>>
      get sensorConfigurationStream => const Stream.empty();
  @override
  Future<void> disconnect() async {}
}

class _Wearables extends WearablesProvider {
  @override
  final List<Wearable> wearables = [];
  final configs = <Wearable, SensorConfigurationProvider>{};
  void connect(_Ear ear) {
    wearables.add(ear);
    configs[ear] = SensorConfigurationProvider(sensorConfigurationManager: ear);
    notifyListeners();
  }

  void disconnect(_Ear ear) {
    wearables.remove(ear);
    configs.remove(ear)!.dispose();
    notifyListeners();
  }

  @override
  SensorConfigurationProvider getSensorConfigurationProvider(
    Wearable wearable,
  ) =>
      configs[wearable]!;
}

void main() {
  testWidgets(
      'heart tracker rebinds only the selected ear and stops its current sensors',
      (tester) async {
    final oldEar = _Ear('selected');
    final otherEar = _Ear('other');
    final newEar = _Ear('selected');
    final wearables = _Wearables()
      ..connect(oldEar)
      ..connect(otherEar);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<WearablesProvider>.value(value: wearables),
          ChangeNotifierProvider<SensorConfigurationProvider>.value(
            value: wearables.getSensorConfigurationProvider(oldEar),
          ),
        ],
        child: MaterialApp(
          home: HeartTrackerPage(wearable: oldEar, ppgSensor: oldEar.ppg),
        ),
      ),
    );
    await tester.pump();
    expect(oldEar.config.requests, ['50 Hz']);
    expect(find.byType(RollingChart), findsOneWidget);

    wearables.disconnect(otherEar);
    wearables.connect(otherEar);
    await tester.pump();
    expect(oldEar.config.requests, ['50 Hz']);

    wearables.disconnect(oldEar);
    await tester.pump();
    expect(find.text('The selected wearable is disconnected.'), findsOneWidget);
    expect(find.byType(RollingChart), findsNothing);
    expect(otherEar.config.requests, isEmpty);

    wearables.connect(newEar);
    await tester.pump();
    expect(find.text('The selected wearable is disconnected.'), findsNothing);
    expect(newEar.config.requests, ['50 Hz']);
    final chart = tester.widget<RollingChart>(find.byType(RollingChart));
    final received = <int>[];
    final subscription =
        chart.dataSteam.listen((sample) => received.add(sample.$1));
    oldEar.ppg.emit(1);
    newEar.ppg.emit(2);
    await tester.pump();
    expect(received, [2]);
    unawaited(subscription.cancel());

    await tester.pumpWidget(const SizedBox.shrink());
    expect(oldEar.config.requests, ['50 Hz']);
    expect(newEar.config.requests, ['50 Hz', 'off']);
    expect(otherEar.config.requests, isEmpty);
    wearables.disconnect(newEar);
    wearables.disconnect(otherEar);
    wearables.dispose();
    for (final ear in [oldEar, newEar, otherEar]) {
      unawaited(ear.ppg.controller.close());
    }
    expect(tester.takeException(), isNull);
  });
}
