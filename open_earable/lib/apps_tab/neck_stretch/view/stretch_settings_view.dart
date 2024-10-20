import 'package:flutter/material.dart';
import 'package:open_earable/apps_tab/neck_stretch/model/stretch_state.dart';
import 'package:open_earable/apps_tab/neck_stretch/view_model/stretch_view_model.dart';
import 'package:provider/provider.dart';
import 'dart:core';

class SettingsView extends StatefulWidget {
  final StretchViewModel _viewModel;

  const SettingsView(this._viewModel, {super.key});

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  late final TextEditingController _mainNeckDuration;
  late final TextEditingController _leftNeckDuration;
  late final TextEditingController _rightNeckDuration;
  late final TextEditingController _restingDuration;
  late final TextEditingController _forwardStretchAngle;
  late final TextEditingController _sideStretchAngle;

  late final StretchViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = widget._viewModel;
    _mainNeckDuration = TextEditingController(
        text:
            _viewModel.stretchSettings.mainNeckRelaxation.inSeconds.toString(),);
    _leftNeckDuration = TextEditingController(
        text:
            _viewModel.stretchSettings.leftNeckRelaxation.inSeconds.toString(),);
    _rightNeckDuration = TextEditingController(
        text: _viewModel.stretchSettings.rightNeckRelaxation.inSeconds
            .toString(),);
    _restingDuration = TextEditingController(
        text: _viewModel.stretchSettings.restingTime.inSeconds.toString(),);
    _forwardStretchAngle = TextEditingController(
        text: _viewModel.stretchSettings.forwardStretchAngle.toString(),);
    _sideStretchAngle = TextEditingController(
        text: _viewModel.stretchSettings.sideStretchAngle.toString(),);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(title: const Text("Stretch Settings")),
      body: ChangeNotifierProvider<StretchViewModel>.value(
          value: _viewModel,
          builder: (context, child) => Consumer<StretchViewModel>(
                builder: (context, postureTrackerViewModel, child) =>
                    _buildSettingsView(),
              ),),
    );
  }

  /// Creates the actual settings view
  Widget _buildSettingsView() {
    return SingleChildScrollView(
      child: Column(
        children: [
          Card(
            color: Theme.of(context).colorScheme.primary,
            child: ListTile(
              title: Text("OpenEarable"),
              trailing: Text(_viewModel.isTracking
                  ? "Tracking"
                  : _viewModel.isAvailable
                      ? "Available"
                      : "Unavailable",),
            ),
          ),
          Card(
            color: Theme.of(context).colorScheme.primary,
            child: Column(
              children: [
                /// Settings for all timers used
                ListTile(
                  title: Text("Timers"),
                ),
                ListTile(
                  title: Text("Main Neck Relaxation Duration\n(in seconds)"),
                  trailing: SizedBox(
                    height: 37.0,
                    width: 62.0,
                    child: TextField(
                      controller: _mainNeckDuration,
                      textAlign: TextAlign.end,
                      style: TextStyle(color: Colors.black),
                      decoration: InputDecoration(
                          contentPadding: EdgeInsets.all(10),
                          floatingLabelBehavior: FloatingLabelBehavior.never,
                          border: OutlineInputBorder(),
                          labelText: 'Seconds',
                          filled: true,
                          labelStyle: TextStyle(color: Colors.black),
                          fillColor: Colors.white,),
                      keyboardType: TextInputType.number,
                      onChanged: (_) {
                        _updateMeditationSettings();
                      },
                    ),
                  ),
                ),
                ListTile(
                  title: Text("Right Neck Relaxation Duration\n(in seconds)"),
                  trailing: SizedBox(
                    height: 37.0,
                    width: 62.0,
                    child: TextField(
                      controller: _rightNeckDuration,
                      textAlign: TextAlign.end,
                      style: TextStyle(color: Colors.black),
                      decoration: InputDecoration(
                          contentPadding: EdgeInsets.all(10),
                          floatingLabelBehavior: FloatingLabelBehavior.never,
                          border: OutlineInputBorder(),
                          labelText: 'Seconds',
                          filled: true,
                          labelStyle: TextStyle(color: Colors.black),
                          fillColor: Colors.white,),
                      keyboardType: TextInputType.number,
                      onChanged: (_) {
                        _updateMeditationSettings();
                      },
                    ),
                  ),
                ),
                ListTile(
                  title: Text("Left Neck Relaxation Duration\n(in seconds)"),
                  trailing: SizedBox(
                    height: 37.0,
                    width: 62.0,
                    child: TextField(
                      controller: _leftNeckDuration,
                      textAlign: TextAlign.end,
                      style: TextStyle(color: Colors.black),
                      decoration: InputDecoration(
                          contentPadding: EdgeInsets.all(10),
                          floatingLabelBehavior: FloatingLabelBehavior.never,
                          border: OutlineInputBorder(),
                          labelText: 'Seconds',
                          filled: true,
                          labelStyle: TextStyle(color: Colors.black),
                          fillColor: Colors.white,),
                      keyboardType: TextInputType.number,
                      onChanged: (_) {
                        _updateMeditationSettings();
                      },
                    ),
                  ),
                ),
                ListTile(
                  title:
                      Text("Resting Duration between exercises\n(in seconds)"),
                  trailing: SizedBox(
                    height: 37.0,
                    width: 62.0,
                    child: TextField(
                      controller: _restingDuration,
                      textAlign: TextAlign.end,
                      style: TextStyle(color: Colors.black),
                      decoration: InputDecoration(
                          contentPadding: EdgeInsets.all(10),
                          floatingLabelBehavior: FloatingLabelBehavior.never,
                          border: OutlineInputBorder(),
                          labelText: 'Seconds',
                          filled: true,
                          labelStyle: TextStyle(color: Colors.black),
                          fillColor: Colors.white,),
                      keyboardType: TextInputType.number,
                      onChanged: (_) {
                        _updateMeditationSettings();
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          Card(
            color: Theme.of(context).colorScheme.primary,
            child: Column(
              children: [
                /// Settings for all timers used
                ListTile(
                  title: Text("Stretch Thresholds"),
                ),
                ListTile(
                  title: Text("Main Neck Stretch Goal\n(as an angle)"),
                  trailing: SizedBox(
                    height: 37.0,
                    width: 62.0,
                    child: TextField(
                      controller: _forwardStretchAngle,
                      textAlign: TextAlign.end,
                      style: TextStyle(color: Colors.black),
                      decoration: InputDecoration(
                          contentPadding: EdgeInsets.all(10),
                          floatingLabelBehavior: FloatingLabelBehavior.never,
                          border: OutlineInputBorder(),
                          labelText: 'Angle',
                          filled: true,
                          labelStyle: TextStyle(color: Colors.black),
                          fillColor: Colors.white,),
                      keyboardType: TextInputType.number,
                      onChanged: (_) {
                        _updateMeditationSettings();
                      },
                    ),
                  ),
                ),
                ListTile(
                  title: Text("Side Neck Stretch Goal\n(as an angle)"),
                  trailing: SizedBox(
                    height: 37.0,
                    width: 62.0,
                    child: TextField(
                      controller: _sideStretchAngle,
                      textAlign: TextAlign.end,
                      style: TextStyle(color: Colors.black),
                      decoration: InputDecoration(
                          contentPadding: EdgeInsets.all(10),
                          floatingLabelBehavior: FloatingLabelBehavior.never,
                          border: OutlineInputBorder(),
                          labelText: 'Angle',
                          filled: true,
                          labelStyle: TextStyle(color: Colors.black),
                          fillColor: Colors.white,),
                      keyboardType: TextInputType.number,
                      onChanged: (_) {
                        _updateMeditationSettings();
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.all(8.0),
            child: Row(children: [
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _viewModel.isTracking
                        ? Colors.green[300]
                        : Colors.blue[300],
                    foregroundColor: Colors.black,
                  ),
                  onPressed: _viewModel.isTracking
                      ? () {
                          _viewModel.calibrate();
                          _viewModel.stopTracking();
                        }
                      : () => _viewModel.startTracking(),
                  child: Text(_viewModel.isTracking
                      ? "Calibrate as Main Posture"
                      : "Start Calibration",),
                ),
              ),
            ],),
          ),
        ],
      ),
    );
  }

  /// Returns the new duration acquired from the Text.
  /// Checks if the string is valid (doesn't contain '-' or '.'.
  /// Maximum allows time of 59 Minute 59 Seconds for UI consistency, if its more it sets 59 Minutes 59 Seconds
  Duration _getNewDuration(Duration duration, String newDuration) {
    if (newDuration.contains('.') || newDuration.contains('-')) return duration;

    int parsed = int.parse(newDuration);

    return parsed > 3599 ? Duration(seconds: 3599) : Duration(seconds: parsed);
  }

  double _parseAngle(double old, String input) {
    if (input.contains('-')) return old;

    return double.parse(input);
  }

  /// Update the Meditation Settings according to values, if field is empty set that timer Duration to 0
  void _updateMeditationSettings() {
    StretchSettings settings = _viewModel.stretchSettings;
    settings.mainNeckRelaxation =
        _getNewDuration(settings.mainNeckRelaxation, _mainNeckDuration.text);
    settings.rightNeckRelaxation =
        _getNewDuration(settings.rightNeckRelaxation, _rightNeckDuration.text);
    settings.leftNeckRelaxation =
        _getNewDuration(settings.leftNeckRelaxation, _leftNeckDuration.text);
    settings.restingTime =
        _getNewDuration(settings.restingTime, _restingDuration.text);
    settings.forwardStretchAngle =
        _parseAngle(settings.forwardStretchAngle, _forwardStretchAngle.text);
    settings.sideStretchAngle =
        _parseAngle(settings.sideStretchAngle, _sideStretchAngle.text);
  }

  @override
  void dispose() {
    super.dispose();
  }
}
