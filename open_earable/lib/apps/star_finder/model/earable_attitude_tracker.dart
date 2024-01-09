import 'dart:async';
import 'package:open_earable/apps/star_finder/model/attitude_tracker.dart';
import 'package:open_earable/apps/star_finder/model/ewma.dart';
import 'package:open_earable_flutter/src/open_earable_flutter.dart';

/// Extends AttitudeTracker to provide an implementation that works with
/// an OpenEarable device for tracking the attitude (orientation) in the Star Finder app
class StarFinderEarableAttitudeTracker extends AttitudeTracker {
  final OpenEarable _openEarable; // The OpenEarable device interface.
  StreamSubscription<Map<String, dynamic>>? _subscription; // Subscription to sensor data stream

  // Exponentially Weighted Moving Averages (EWMAs) for smoothing the sensor data
  EWMA _roll = EWMA(0.2);
  EWMA _pitch = EWMA(0.2);
  EWMA _yaw = EWMA(0.2);

  StarFinderEarableAttitudeTracker(this._openEarable) {
    // Listens to changes in the connection state of the OpenEarable device
    _openEarable.bleManager.connectionStateStream.listen((connected) {
      didChangeAvailability(this);
      if (!connected) {
        cancle();
      }
    });
  }

  @override
  // Indicates whether the tracker is currently tracking
  bool get isTracking => _subscription != null && !_subscription!.isPaused;
  @override
  // Indicates whether the OpenEarable device is available for tracking
  bool get isAvailable => _openEarable.bleManager.connected;

  @override
  // Starts the tracking of attitude data
  void start() {
    if (_subscription?.isPaused ?? false) {
      _subscription?.resume();
      return;
    }

    // Configures the sensor and subscribes to its data
    _openEarable.sensorManager.writeSensorConfig(_buildSensorConfig());
    _subscription = _openEarable.sensorManager.subscribeToSensorData(0).listen((event) {
      updateAttitude(
          roll: _roll.update(event["EULER"]["ROLL"]) * 180 / 3.14,
          pitch: _pitch.update(event["EULER"]["PITCH"]) * 180 / 3.14,
          yaw: _yaw.update(event["EULER"]["YAW"]) * 180 / 3.14);
    });
  }

  @override
  // Pauses the tracking
  void stop() {
    _subscription?.pause();
  }

  @override
  // Cancels the tracking
  void cancle() {
    stop();
    _subscription?.cancel();
    super.cancle();
  }

  /// Builds the sensor configuration for the OpenEarable device.
  /// This configures the sensor with specific parameters like sampling rate and latency.
  OpenEarableSensorConfig _buildSensorConfig() {
    return OpenEarableSensorConfig(sensorId: 0, samplingRate: 30, latency: 0);
  }
}
