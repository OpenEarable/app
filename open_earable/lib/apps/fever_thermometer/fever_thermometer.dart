import 'dart:async';
import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:open_earable/apps/fever_thermometer/settings.dart';
import 'package:open_earable/apps/fever_thermometer/states.dart';
import 'package:open_earable/apps/fever_thermometer/views/idle_view.dart';
import 'package:open_earable/apps/fever_thermometer/views/measuring_view.dart';
import 'package:open_earable/apps/fever_thermometer/views/referencing_view.dart';
import 'package:open_earable_flutter/src/open_earable_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The main widget of the Fever Thermometer app. Contains the logic and the UI.
class FeverThermometer extends StatefulWidget {
  final Key? key;
  final OpenEarable openEarable;
  final Settings settings;
  final bool? referenceSet;

  FeverThermometer(
      {this.key,
      required this.openEarable,
      required this.settings,
      this.referenceSet})
      : super(key: key);

  @override
  State<FeverThermometer> createState() =>
      _FeverThermometerState(openEarable, settings, referenceSet);
}

class _FeverThermometerState extends State<FeverThermometer> {
  final OpenEarable _openEarable;
  final Settings _settings;

  /// Indicates whether the reference measurement was taken
  bool? _referenceSet;

  ///store the last values of the sensor, to see when temperature is stable
  var _queue = Queue<double>();

  /// current state of the app. Defines what is shown on the lower half of the screen
  CurrentState _currentState = CurrentState.uninitialized;

  /// Indicates whether a measurement for the reference is currently being taken
  bool isReferencing = false;

  /// Indicates whether a measurement for the actual temperature is currently being taken
  bool isMeasuring = false;

  /// Counts how often the value has remained the same. Required for the termination condition.
  int counter = 0;

  /// Highest value of the temperature during the measurement.
  double _highestValue = 0;

  /// The current temperature
  double _sensorData = 0;

  StreamSubscription? _dataSubscription;

  late MeasuringView _measuringView;

  _FeverThermometerState(this._openEarable, this._settings, this._referenceSet);

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Expanded(
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _sensorData.toStringAsFixed(2) + " °C",
                style: TextStyle(
                    fontSize: 70,
                    color: (isReferencing || isMeasuring)
                        ? Colors.green
                        : Colors.white),
              ),
              Container(
                  child: (_sensorData == 0)
                      ? Text(
                          "Please configure Barometer Sensor to 10Hz on Controls Screen",
                          style: TextStyle(color: Colors.red))
                      : null),
              Container(
                  child: (isReferencing || isMeasuring)
                      ? Text(
                          "The temperature at your ear is being measured. Please wait.\nThe measurement will stop automatically upon completion.",
                          textAlign: TextAlign.center,
                        )
                      : null)
            ]),
      ),
      Expanded(
        child: loweHalf(),
      ),
    ]);
  }

  /// Returns the lower half of the screen, depending on the current state.
  Widget loweHalf() {
    if (_currentState == CurrentState.referencing) {
      return ReferencingView(_settings, finishSensing, referenceSet);
    } else if (_currentState == CurrentState.measuring) {
      return _measuringView;
    } else if (_currentState == CurrentState.idle) {
      return IdleView(() {
        measureTemp();
      }, () {
        setReference();
      }, _referenceSet!);
    } else {
      return Container();
    }
  }

  @override
  void initState() {
    super.initState();
    _dataSubscription =
        _openEarable.sensorManager.subscribeToSensorData(1).listen((data) {
      updateData(data["TEMP"]["Temperature"]);
    });

    getPersistedData();

    _measuringView = MeasuringView(_settings, () {
      _finishMeasuring();
    }, _openEarable);

    if (_referenceSet == null) {
      setState(() {
        _referenceSet = false;
      });
    }
  }

  /// Sets the state to idle if the reference temperature is set.
  void setNewState() {
    if (_currentState == CurrentState.referencing &&
        _settings.getTemperature(0) != null) {
      setState(() {
        _currentState = CurrentState.idle;
      });
    }
  }

  /// Called on every data update.
  void updateData(double newData) {
    setState(() {
      _sensorData = newData;
    });

    //logic for the termination condition:
    if (isReferencing || isMeasuring) {
      _queue.removeFirst();
      _queue.add(newData);

      if (isFinishedSensing(_queue)) {
        finishSensing();
      }
      if (newData > _highestValue) {
        _highestValue = newData;
      }
    }
  }

  /// Checks if the temperature is stable.
  bool isFinishedSensing(Queue<double> queue) {
    // It is called stable if:
    // - the highest value is the same for fixed amount of times
    final double amount = 200;
    // - the difference of the current last 100 elements is small
    final double diff = 0.009;
    // - the measured temperature decreases
    final double decrease = 0.1;

    double smallest = queue.first;
    double biggest = queue.first;
    queue.forEach((element) {
      if (smallest > element) smallest = element;
      if (biggest < element) biggest = element;
    });

    if (biggest == _highestValue) {
      counter++;
    } else {
      counter = 0;
    }

    if (counter > amount ||
        (biggest - smallest) < diff ||
        _highestValue - biggest > decrease) {
      //As soon as it is possible to adjust the volume, you can add it here.
      //_openEarable.audioPlayer.jingle(6);
      print("Finished sensing!");

      return true;
    }

    return false;
  }

  /// Starts the sensing process for the reference or the real measurement.
  void startSensing() {
    _highestValue = 0;
    _queue.clear();
    counter = 0;

    _queue.addAll(List<double>.generate(200, (index) => 0));
  }

  /// Finishes the sensing process for the reference or the real measurement.
  Future<void> finishSensing() async {
    if (_currentState == CurrentState.referencing) {
      setState(() {
        _settings.setReferenceMeasuredTemperature(_sensorData);
      });
      if (_settings.getReferenceRealTemperature() != null) {
        setState(() {
          _referenceSet = true;
        });
      }
    }

    setState(() {
      isMeasuring = false;
      isReferencing = false;
    });

    setNewState();
  }

  /// Called, when the self measured real temperature is measured. Finishes the
  /// measurement, if Earable temperature is measured.
  void referenceSet() {
    if (_settings.getReferenceMeasuredTemperature() != null) {
      setState(() {
        _referenceSet = true;
      });
    }
    setNewState();
  }

  /// Initiates the reference measurement.
  void setReference() {
    deleteSettings();

    startSensing();

    setState(() {
      isReferencing = true;
      _currentState = CurrentState.referencing;
    });
  }

  /// Initiates the real measurement.
  void measureTemp() {
    if (!_referenceSet!) {
      return;
    }
    startSensing();

    setState(() {
      isMeasuring = true;
      _currentState = CurrentState.measuring;
    });
  }

  /// Loads the persisted reference measurement.
  getPersistedData() async {
    final prefs = await SharedPreferences.getInstance();

    await _settings.setReferenceMeasuredTemperature(
        prefs.getDouble('referenceMeasuredTemperature'));
    await _settings.setReferenceRealTemperature(
        prefs.getDouble('referenceRealTemperature'));

    if (_settings.getTemperature(0) != null) {
      setState(() {
        _referenceSet = true;
      });
    }
    setState(() {
      _currentState = CurrentState.idle;
    });
  }

  /// Persists the reference measurement.
  persistData(double? referenceMeasuredTemperature,
      double? referenceRealTemperature) async {
    final prefs = await SharedPreferences.getInstance();
    if (referenceMeasuredTemperature == null ||
        referenceRealTemperature == null) {
      await prefs.remove('referenceMeasuredTemperature');
      await prefs.remove('referenceRealTemperature');
    } else {
      await prefs.setDouble(
          'referenceMeasuredTemperature', referenceMeasuredTemperature);
      await prefs.setDouble(
          'referenceRealTemperature', referenceRealTemperature);
    }
  }

  /// Deletes the reference measurement.
  deleteSettings() {
    _settings.setReferenceMeasuredTemperature(null);
    _settings.setReferenceRealTemperature(null);
    setState(() {
      _referenceSet = false;
    });
  }

  /// Called when the real measurement is finished.
  _finishMeasuring() {
    setState(() {
      finishSensing();
      _currentState = CurrentState.idle;
    });
  }

  @override
  void dispose() {
    _dataSubscription?.cancel();
    persistData(_settings.getReferenceMeasuredTemperature(),
        _settings.getReferenceRealTemperature());
    super.dispose();
  }
}
