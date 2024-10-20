import 'dart:async';

import 'package:open_earable/apps_tab/powernapper/interact.dart';
import 'package:open_earable/apps_tab/powernapper/sensor_datatypes.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart';

/// Movement Tracker has lgoic for timer & movement validation.
class MovementTracker {
  //Incetaction variables
  final Interact _interact;
  late final OpenEarable _openEarable;

  Timer? _timer;

  //Stream Subscription
  StreamSubscription<Map<String, dynamic>>? _subscription;

  //Constructor
  MovementTracker(this._interact) {
    _openEarable = _interact.getEarable();
  }

  ///Start Subscription and reset timer.
  ///
  /// Input: [minutes] for the time before the ring.
  /// Input: [updateText] as an void callback function for the textupdate.
  void start(int minutes, void Function(SensorDataType s) updateText) {
    //Timer (re-)start
    stop();
    _startTimer(minutes);

    //Sets sensor config
    _openEarable.sensorManager.writeSensorConfig(_buildSensorConfig());

    //Starts listening to the subscription
    _subscription =
        _openEarable.sensorManager.subscribeToSensorData(0).listen((event) {
      //Display update callback
      updateText(Gyroscope(event));

      //Timer update
      _update(Gyroscope(event), minutes);
    });
  }

  ///(Re-)Starts timer and cancels subscription & calls ring() when finished.
  ///
  /// Input: int [minutes] for the timer length.
  void _startTimer(int minutes) {
    _timer?.cancel();
    _timer = Timer(Duration(minutes: minutes), () {
      //End of timer:
      _interact.ring();
      stop();
    });
  }

  /// Cancels timer and subscription to the Earable sensor stream.
  void stop() {
    _timer?.cancel();
    _subscription?.cancel();
  }

  /// Update method for restarting timer when movement is tracked.
  ///
  /// Uses the [SensorDataType] to validate update and int [minutes] to restart the timer.
  void _update(SensorDataType dt, int minutes) {
    if (_validMovement(dt)) {
      _timer?.cancel();
      _startTimer(minutes);
    }
  }

  /// Validates wether the given sensordata could be interpretet as a movement.
  ///
  /// Input: [SensorDataType] with the data to be validated.
  bool _validMovement(SensorDataType dt) {
    Gyroscope gyro;

    if (dt is Gyroscope) {
      gyro = dt;

      //Threshold validating for gyroscope data.
      if (gyro.x.abs() > 5 || gyro.y.abs() > 5 || gyro.z.abs() > 5) {
        return true;
      }
    }
    return false;
  }

  ///Sensor Config for the earable.
  OpenEarableSensorConfig _buildSensorConfig() {
    return OpenEarableSensorConfig(sensorId: 0, samplingRate: 30, latency: 0);
  }
}
