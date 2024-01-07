import 'dart:async';

import 'package:open_earable/apps/head_trainer/model/orientation_value.dart';
import 'package:open_earable_flutter/src/open_earable_flutter.dart';
import 'package:simple_kalman/simple_kalman.dart';

class OrientationValueUpdater {

  final OpenEarable openEarable;
  late OrientationValue valueOffset;
  late double yawDrift;

  OrientationValueUpdater({
    required this.openEarable,
    required this.valueOffset,
    required this.yawDrift,
  });

  late SimpleKalman kalmanX, kalmanY, kalmanZ;
  StreamSubscription? _dataSubscription;
  StreamController<OrientationValue> streamController
    = StreamController.broadcast();
  Timer? _timer;

  /**
   * The yaw value has a noticeable drift over time. To counteract this a value
   * is added over time. The value can be set by the user.
   * This is a ugly hack, but rewriting the AHRS was not part of the scope.
   */
  int time = 0;

  setupListeners() {
    _dataSubscription =
        openEarable.sensorManager.subscribeToSensorData(0).listen((data) {
          valueOffset.roll = data["EULER"]["ROLL"];
          valueOffset.pitch = data["EULER"]["PITCH"];
          valueOffset.yaw = data["EULER"]["YAW"] - yawDrift * time;
          streamController.add(valueOffset);
          time++;
        });
  }

  setupMockListeners() {
    _timer = Timer.periodic(Duration(milliseconds: 100), (timer) {
      valueOffset.roll = 1.234;
      valueOffset.pitch = 5.678;
      valueOffset.yaw = 0 - yawDrift * time;
      streamController.add(valueOffset);
      time++;
    });
  }

  stopListener() {
    _dataSubscription?.cancel();
    _timer?.cancel();
  }

  subscribe() {
    return streamController.stream;
  }

}