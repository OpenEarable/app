import 'dart:async';

import 'package:flutter/material.dart';

import 'package:open_earable/apps/fever_thermometer/settings.dart';
import 'package:open_earable_flutter/src/open_earable_flutter.dart';

/// Measuring view of the Fever Thermometer app. Contains the real Temperature and disclaimers.
class MeasuringView extends StatefulWidget {
  final VoidCallback? _finishMeasuring;
  final OpenEarable _openEarable;
  final Settings _settings;

  MeasuringView(this._settings, this._finishMeasuring, this._openEarable);

  @override
  State<MeasuringView> createState() =>
      MeasuringViewState(_settings, _finishMeasuring, _openEarable);
}

class MeasuringViewState extends State<MeasuringView> {
  final Settings _settings;
  final OpenEarable _openEarable;
  final VoidCallback? _finishMeasuring;
  StreamSubscription? _dataSubscription;

  double _sensorData = 0;

  String estimatedTemp() {
    if (_settings.getTemperature(_sensorData) != null) {
      return _settings.getTemperature(_sensorData)!.toStringAsFixed(2);
    } else {
      return "Configuration Problem";
    }
  }

  MeasuringViewState(this._settings, this._finishMeasuring, this._openEarable);

  @override
  Widget build(BuildContext context) {
    return Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Text("Estimated real Temperature: " + estimatedTemp() + "°C",
              style: TextStyle(fontSize: 20)),
          Padding(
            padding: EdgeInsets.all(10),
            child: Text(
                "The measured values provided come with a warranty, yet it's important to note that these are approximate estimations, susceptible to potential inaccuracies due to various influencing factors. In case of any concerns, it's advisable to use a certified thermometer or consult a medical professional for accurate readings and guidance.",
                style: TextStyle(fontSize: 10)),
          ),
          ElevatedButton(onPressed: _finishMeasuring, child: Text("Finish")),
        ]);
  }

  @override
  void initState() {
    super.initState();
    _dataSubscription =
        _openEarable.sensorManager.subscribeToSensorData(1).listen((data) {
      _updateData(data["TEMP"]["Temperature"]);
    });
  }

  /// Updates the variable on new data.
  _updateData(double data) {
    setState(() {
      _sensorData = data;
    });
  }

  @override
  void dispose() {
    _dataSubscription?.cancel();
    super.dispose();
  }
}
