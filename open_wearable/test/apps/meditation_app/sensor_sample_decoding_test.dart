// Covers the translation from an SDK sensor value to the pipeline's samples.
//
// Getting this wrong is silent: the signal still flows, it is simply the wrong
// channel, which then looks like a signal-quality problem much further down.

import 'package:flutter_test/flutter_test.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart';
import 'package:open_wearable/apps/meditation_app/model/sensor_sample_decoding.dart';

void main() {
  group('optical channel decoding', () {
    test('axis names decide the channels, not their position', () {
      // Firmware that reports a different order must not silently swap
      // channels; the names win when they are available.
      final sample = extractPpgOpticalSample(
        _FakeSensor(const ['Green', 'Ambient', 'Red', 'Infrared']),
        _value(1000),
        const [11, 22, 33, 44],
      );

      expect(sample, isNotNull);
      expect(sample!.green, 11);
      expect(sample.ambient, 22);
      expect(sample.red, 33);
      expect(sample.ir, 44);
      expect(sample.timestamp, 1000);
    });

    test('infrared is never mistaken for red', () {
      final sample = extractPpgOpticalSample(
        _FakeSensor(const ['IR', 'RED']),
        _value(5),
        const [7, 9],
      );

      expect(sample!.ir, 7);
      expect(sample.red, 9);
    });

    test('unnamed axes fall back to the usual red, ir, green, ambient order',
        () {
      final sample = extractPpgOpticalSample(
        _FakeSensor(const ['a', 'b', 'c', 'd']),
        _value(2),
        const [1, 2, 3, 4],
      );

      expect(sample!.red, 1);
      expect(sample.ir, 2);
      expect(sample.green, 3);
      expect(sample.ambient, 4);
    });

    test('a short reading reuses what it has rather than reading past the end',
        () {
      final sample = extractPpgOpticalSample(
        _FakeSensor(const ['a']),
        _value(3),
        const [5],
      );

      expect(sample!.red, 5);
      expect(sample.ir, 5);
      expect(sample.green, 5);
      expect(sample.ambient, 0);
    });

    test('an empty reading produces no sample', () {
      expect(
        extractPpgOpticalSample(_FakeSensor(const []), _value(1), const []),
        isNull,
      );
    });
  });

  group('motion decoding', () {
    test('axis names decide x, y and z', () {
      final sample = extractImuMotionSample(
        _FakeSensor(const ['Z', 'X', 'Y']),
        _value(9),
        const [30, 10, 20],
      );

      expect(sample.x, 10);
      expect(sample.y, 20);
      expect(sample.z, 30);
      expect(sample.timestamp, 9);
    });

    test('missing axes stay at zero instead of shifting the others', () {
      final sample = extractImuMotionSample(
        _FakeSensor(const ['q', 'r']),
        _value(0),
        const [1, 2],
      );

      expect(sample.x, 1);
      expect(sample.y, 2);
      expect(sample.z, 0);
    });
  });

  group('sensor value conversion', () {
    test('integer sensors are widened to doubles', () {
      final values = sensorValuesAsDoubles(
        SensorIntValue(values: const [1, 2, 3], timestamp: 0),
      );
      expect(values, const [1.0, 2.0, 3.0]);
    });

    test('a value type the app does not understand is skipped', () {
      expect(
        sensorValuesAsDoubles(
          const SensorValue(valueStrings: ['x'], timestamp: 0),
        ),
        isNull,
      );
    });
  });
}

SensorDoubleValue _value(int timestamp) =>
    SensorDoubleValue(values: const [0], timestamp: timestamp);

class _FakeSensor extends Sensor<SensorValue> {
  @override
  final List<String> axisNames;

  _FakeSensor(this.axisNames)
      : super(
          sensorName: 'fake',
          chartTitle: 'fake',
          shortChartTitle: 'fake',
        );

  @override
  List<String> get axisUnits => const [];

  @override
  Stream<SensorValue> get sensorStream => const Stream.empty();
}
