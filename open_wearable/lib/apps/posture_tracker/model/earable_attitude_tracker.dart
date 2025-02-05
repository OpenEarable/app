import 'dart:async';

import 'package:open_earable_flutter/open_earable_flutter.dart';
import 'package:open_wearable/apps/posture_tracker/model/attitude_tracker.dart';
import 'package:open_wearable/apps/posture_tracker/model/ewma.dart';

class EarableAttitudeTracker extends AttitudeTracker {
  final SensorManager _sensorManager;
  final SensorConfigurationManager _sensorConfigurationManager;
  StreamSubscription<SensorValue>? _subscription;

  @override
  bool get isAvailable => true;

  @override
  bool get isTracking => _subscription != null && !_subscription!.isPaused;

  final EWMA _rollEWMA = EWMA(0.5);
  final EWMA _pitchEWMA = EWMA(0.5);
  final EWMA _yawEWMA = EWMA(0.5);

  EarableAttitudeTracker(this._sensorManager, this._sensorConfigurationManager);

  @override
  void start() {
    if (_subscription?.isPaused ?? false) {
      _subscription?.resume();
      return;
    }

    SensorConfiguration sensorConfig =
      _sensorConfigurationManager.sensorConfigurations.firstWhere((element) => element.name == "IMU");

    sensorConfig.setConfiguration(sensorConfig.values.last);

    _subscription = _sensorManager.sensors.firstWhere((s) => s.sensorName == "ATT").sensorStream.listen(
      (data) {
        SensorDoubleValue attitude = data as SensorDoubleValue;
        updateAttitude(
          roll: _rollEWMA.update(attitude.values[0]),
          pitch: _pitchEWMA.update(attitude.values[1]),
          yaw: _yawEWMA.update(attitude.values[2]),
        );
      },
    );
  }

  @override
  void stop() {
    _subscription?.pause();
  }

  @override
  void cancel() {
    stop();
    _subscription?.cancel();
    super.cancel();
  }
}
