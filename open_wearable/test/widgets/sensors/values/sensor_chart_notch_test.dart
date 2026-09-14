import 'dart:collection';
import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart';
import 'package:open_wearable/view_models/sensor_data_provider.dart';
import 'package:open_wearable/widgets/sensors/values/sensor_chart.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('50 Hz notch remains bounded with irregular sample intervals',
      (tester) async {
    final provider = _FakeSensorDataProvider();
    provider.addSamples(22);

    await _enableNotch(tester, provider);

    void expectStableOutput() {
      final chart = tester.widget<LineChart>(find.byType(LineChart));
      expect(
        chart.data.lineBarsData.single.spots.every(
          (spot) => spot.y.isFinite && spot.y.abs() < 5,
        ),
        isTrue,
        reason: 'A bounded input must not produce a growing notch output.',
      );
      expect(tester.takeException(), isNull);
    }

    expectStableOutput();
    for (var batch = 0; batch < 25; batch++) {
      provider.addSamples(50);
      await tester.pump();
      expectStableOutput();
    }
  });

  testWidgets('50 Hz notch still attenuates a regularly sampled 50 Hz tone',
      (tester) async {
    final provider = _FakeSensorDataProvider(intervalsMs: const [5]);
    provider.addSamples(400);

    await _pumpChart(tester, provider);
    final rawMean = _recentMeanAbsoluteValue(tester);
    await _openNotchSettings(tester);
    final filteredMean = _recentMeanAbsoluteValue(tester);

    expect(filteredMean, lessThan(rawMean * 0.5));
    expect(tester.takeException(), isNull);
  });

  testWidgets('50 Hz notch adapts when the sensor sampling rate changes',
      (tester) async {
    final provider = _FakeSensorDataProvider(intervalsMs: const [10]);
    provider.addSamples(200);
    await _enableNotch(tester, provider);

    provider.useIntervals(const [5]);
    provider.addSamples(400);
    await tester.pump();

    expect(_recentMeanAbsoluteValue(tester), lessThan(0.3));
    expect(tester.takeException(), isNull);
  });
}

Future<void> _enableNotch(
  WidgetTester tester,
  _FakeSensorDataProvider provider,
) async {
  await _pumpChart(tester, provider);
  await _openNotchSettings(tester);
}

Future<void> _pumpChart(
  WidgetTester tester,
  _FakeSensorDataProvider provider,
) async {
  await tester.pumpWidget(
    ChangeNotifierProvider<SensorDataProvider>.value(
      value: provider,
      child: const MaterialApp(
        home: Scaffold(
          body: SizedBox(height: 400, child: SensorChart()),
        ),
      ),
    ),
  );
}

Future<void> _openNotchSettings(WidgetTester tester) async {
  await tester.tap(find.text('X'));
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.text('Notch filter'));
  await tester.tap(find.byType(Switch).last);
  await tester.pumpAndSettle();
}

double _recentMeanAbsoluteValue(WidgetTester tester) {
  final chart = tester.widget<LineChart>(find.byType(LineChart));
  final spots = chart.data.lineBarsData.single.spots;
  final recent = spots.skip(spots.length - 100);
  return recent.fold<double>(0, (sum, spot) => sum + spot.y.abs()) / 100;
}

class _FakeSensor extends Sensor<SensorDoubleValue> {
  const _FakeSensor()
      : super(
          sensorName: 'Accelerometer',
          chartTitle: 'Accelerometer',
          shortChartTitle: 'Accel',
        );

  @override
  List<String> get axisNames => const ['X'];

  @override
  List<String> get axisUnits => const ['g'];

  @override
  Stream<SensorDoubleValue> get sensorStream => const Stream.empty();
}

class _FakeWearable implements Wearable {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeSensorDataProvider extends ChangeNotifier
    implements SensorDataProvider {
  List<int> _intervalsMs;

  _FakeSensorDataProvider({
    List<int> intervalsMs = const [5, 10, 15, 10],
  }) : _intervalsMs = intervalsMs;

  int _latestTimestamp = 0;
  int _sampleIndex = 0;

  @override
  final Sensor sensor = const _FakeSensor();

  @override
  final Wearable wearable = _FakeWearable();

  @override
  final Queue<SensorValue> sensorValues = Queue<SensorValue>();

  @override
  int get timeWindow => 5;

  @override
  int get displayTimestamp => sensorValues.last.timestamp;

  void useIntervals(List<int> intervalsMs) {
    _intervalsMs = intervalsMs;
    _sampleIndex = 0;
  }

  void addSamples(int count) {
    for (var i = 0; i < count; i++) {
      _latestTimestamp += _intervalsMs[_sampleIndex % _intervalsMs.length];
      _sampleIndex++;
      sensorValues.add(
        SensorDoubleValue(
          values: [
            sin(2 * pi * 50 * _latestTimestamp / 1000) +
                0.2 * sin(2 * pi * 7 * _latestTimestamp / 1000),
          ],
          timestamp: _latestTimestamp,
        ),
      );
    }
    while (sensorValues.isNotEmpty &&
        sensorValues.first.timestamp < _latestTimestamp - 5000) {
      sensorValues.removeFirst();
    }
    notifyListeners();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
