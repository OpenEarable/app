import 'dart:async';
import 'dart:math';

import 'package:open_earable_flutter/open_earable_flutter.dart';
import 'package:open_wearable/apps/posture_tracker/model/attitude.dart';
import 'package:open_wearable/apps/posture_tracker/model/attitude_tracker.dart';
import 'package:open_wearable/apps/posture_tracker/model/ewma.dart';
import 'package:open_wearable/view_models/sensor_configuration_provider.dart';

class EarableAttitudeTracker extends AttitudeTracker {
  final SensorManager _sensorManager;
  final SensorConfigurationProvider _sensorConfigurationProvider;
  StreamSubscription<SensorValue>? _subscription;

  @override
  bool get isAvailable => true;

  @override
  bool get isTracking => _subscription != null && !_subscription!.isPaused;

  final EWMA _rollEWMA = EWMA(0.5);
  final EWMA _pitchEWMA = EWMA(0.5);
  final EWMA _yawEWMA = EWMA(0.5);

  final bool _isLeft;

  EarableAttitudeTracker(this._sensorManager, this._sensorConfigurationProvider, this._isLeft);

  @override
  void start() {
    if (_subscription?.isPaused ?? false) {
      _subscription?.resume();
      return;
    }

    final Sensor accelSensor = _sensorManager.sensors.firstWhere((s) => s.sensorName.toLowerCase() == "accelerometer".toLowerCase());

    final Set<SensorConfiguration> configurations = {};
    configurations.addAll(accelSensor.relatedConfigurations);

    for (final SensorConfiguration configuration in configurations) {
      if (configuration is ConfigurableSensorConfiguration && configuration.availableOptions.contains(StreamSensorConfigOption())) {
        _sensorConfigurationProvider.addSensorConfigurationOption(configuration, StreamSensorConfigOption());
      }
      List<SensorConfigurationValue> values = _sensorConfigurationProvider.getSensorConfigurationValues(configuration, distinct: true);
      _sensorConfigurationProvider.addSensorConfiguration(configuration, values.first);
      configuration.setConfiguration(_sensorConfigurationProvider.getSelectedConfigurationValue(configuration)!);
    }

    calibrate(
      Attitude(
        roll: pi / 2 * (_isLeft ? -1 : 1),
        pitch: 0.0,
        yaw: 0.0,
      ),
    );

    _subscription = accelSensor.sensorStream.listen((data) {
      if (data is SensorDoubleValue) {
        final double ax = data.values[0];
        final double ay = data.values[1];
        final double az = -data.values[2];
        List<double> angles = _calculateAngles(ax, ay, az);
        double roll = _rollEWMA.update(angles[0]);
        double pitch = _pitchEWMA.update(angles[1]);
        double yaw = _yawEWMA.update(angles[2]);

        updateAttitude(roll: roll, pitch: pitch, yaw: yaw);
      }
    });
  }

  /// Calculate roll and pitch angles from accelerometer data
  /// -- [ax] accelerometer x-axis value, pointing backwards
  /// -- [ay] accelerometer y-axis value, pointing upwards
  /// -- [az] accelerometer z-axis value, pointing to the left
  List<double> _calculateAngles(double ax, double ay, double az) {
    // Normalize accelerometer data
    double norm = sqrt(ax * ax + ay * ay + az * az);
    if (norm == 0.0) return [0.0, 0.0, 0.0];
    ax /= norm;
    ay /= norm;
    az /= norm;

    // Calculate roll and pitch angles
    final double roll = atan2(ay, az);
    final double pitch = atan2(-ax, sqrt(ay * ay + az * az));

    return [roll, pitch, 0.0]; // Yaw is not calculated here
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
