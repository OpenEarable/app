import 'dart:async';
import 'dart:math';

import 'package:open_earable_flutter/open_earable_flutter.dart';
import 'package:open_wearable/apps/posture_tracker/model/attitude.dart';
import 'package:open_wearable/apps/posture_tracker/model/attitude_tracker.dart';
import 'package:open_wearable/apps/posture_tracker/model/ewma.dart';
import 'package:open_wearable/view_models/sensor_configuration_provider.dart';

class EarableAttitudeTracker extends AttitudeTracker {
  SensorManager? _sensorManager;
  SensorConfigurationProvider? _sensorConfigurationProvider;
  StreamSubscription<SensorValue>? _subscription;
  final Set<SensorConfiguration> _activeConfigurations = {};
  bool _startedBefore = false;
  bool _resumeWhenAvailable = false;

  @override
  bool get isAvailable => _sensorManager != null;

  @override
  bool get isTracking => _subscription != null && !_subscription!.isPaused;

  final EWMA _rollEWMA = EWMA(0.5);
  final EWMA _pitchEWMA = EWMA(0.5);
  final EWMA _yawEWMA = EWMA(0.5);

  final bool _isLeft;

  EarableAttitudeTracker(
    SensorManager sensorManager,
    SensorConfigurationProvider sensorConfigurationProvider,
    this._isLeft,
  ) : _sensorManager = sensorManager,
        _sensorConfigurationProvider = sensorConfigurationProvider;

  void updateConnection(
    SensorManager? sensorManager,
    SensorConfigurationProvider? sensorConfigurationProvider,
  ) {
    assert((sensorManager == null) == (sensorConfigurationProvider == null));
    if (identical(_sensorManager, sensorManager) &&
        identical(_sensorConfigurationProvider, sensorConfigurationProvider)) {
      return;
    }
    final resume = isTracking || _resumeWhenAvailable;
    unawaited(_subscription?.cancel());
    _subscription = null;
    // The old connection is gone; do not write through its disposed provider.
    _activeConfigurations.clear();
    _sensorManager = sensorManager;
    _sensorConfigurationProvider = sensorConfigurationProvider;
    _resumeWhenAvailable = resume && !isAvailable;
    if (resume && isAvailable) {
      start();
    }
    notifyListeners();
  }

  @override
  void start() {
    if (_subscription != null) return;
    final sensorManager = _sensorManager;
    final sensorConfigurationProvider = _sensorConfigurationProvider;
    if (sensorManager == null || sensorConfigurationProvider == null) return;
    _resumeWhenAvailable = false;

    final Sensor accelSensor = sensorManager.sensors.firstWhere(
      (s) => s.sensorName.toLowerCase() == "accelerometer".toLowerCase(),
    );

    final Set<SensorConfiguration> configurations = {};
    configurations.addAll(accelSensor.relatedConfigurations);

    for (final SensorConfiguration configuration in configurations) {
      _activeConfigurations.add(configuration);
      if (configuration is ConfigurableSensorConfiguration &&
          configuration.availableOptions.contains(StreamSensorConfigOption())) {
        sensorConfigurationProvider.addSensorConfigurationOption(
          configuration,
          StreamSensorConfigOption(),
          markPending: false,
        );
      }
      List<SensorConfigurationValue> values = sensorConfigurationProvider
          .getSensorConfigurationValues(configuration, distinct: true);
      sensorConfigurationProvider.addSensorConfiguration(
        configuration,
        values.first,
        markPending: false,
      );
      configuration.setConfiguration(
        sensorConfigurationProvider
            .getSelectedConfigurationValue(configuration)!,
      );
    }

    if (!_startedBefore) {
      calibrate(
        Attitude(
          roll: pi / 2 * (_isLeft ? -1 : 1),
          pitch: 0.0,
          yaw: 0.0,
        ),
      );
      _startedBefore = true;
    }

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
    _resumeWhenAvailable = false;
    unawaited(_subscription?.cancel());
    _subscription = null;
    for (final configuration in _activeConfigurations) {
      final off = configuration.offValue;
      if (off != null) {
        _sensorConfigurationProvider?.applyConfiguration(configuration, off);
      }
    }
    _activeConfigurations.clear();
  }

  @override
  void cancel() {
    stop();
    super.cancel();
  }
}
