import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart';
import 'package:open_wearable/models/labels/label.dart';
import 'package:open_wearable/models/labels/label_sensor.dart';
import 'package:open_wearable/models/labels/label_set.dart';
import 'package:open_wearable/models/logger.dart';
import 'package:open_wearable/view_models/sensor_recorder_provider_facade.dart';

void main() {
  setUpAll(() {
    initLogger(Logger());
  });

  test('does not treat a selected label set as connected sensors', () async {
    final provider = SensorRecorderProvider();
    final labelStream = StreamController<(int, List<Label>)>.broadcast();
    addTearDown(provider.dispose);
    addTearDown(labelStream.close);

    await provider.addWearable(
      LabelWearable(
        labelSet: const LabelSet(
          name: 'Activities',
          labels: [
            Label(name: 'Walking', color: Color(0xff4caf50)),
          ],
        ),
        labelStream: labelStream.stream,
      ),
    );

    expect(provider.hasSensorsConnected, isFalse);
  });
}
