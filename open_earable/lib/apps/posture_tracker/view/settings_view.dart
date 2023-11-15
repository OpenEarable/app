import 'package:flutter/material.dart';
import 'package:open_earable/apps/posture_tracker/model/bad_posture_reminder.dart';
import 'package:open_earable/apps/posture_tracker/view_model/posture_tracker_view_model.dart';
import 'package:provider/provider.dart';

class SettingsView extends StatefulWidget {
  final PostureTrackerViewModel _viewModel;
  
  SettingsView(this._viewModel);

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  late final TextEditingController _rollAngleThresholdController;
  late final TextEditingController _pitchAngleThresholdController;
  late final TextEditingController _badPostureTimeThresholdController;
  late final TextEditingController _goodPostureTimeThresholdController;

  late final PostureTrackerViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = widget._viewModel;
    _rollAngleThresholdController = TextEditingController(text: _viewModel.badPostureSettings.rollAngleThreshold.toString());
    _pitchAngleThresholdController = TextEditingController(text: _viewModel.badPostureSettings.pitchAngleThreshold.toString());
    _badPostureTimeThresholdController = TextEditingController(text: _viewModel.badPostureSettings.timeThreshold.toString());
    _goodPostureTimeThresholdController = TextEditingController(text: _viewModel.badPostureSettings.resetTimeThreshold.toString());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Posture Tracker Settings")
      ),
      body: ChangeNotifierProvider<PostureTrackerViewModel>.value(
        value: _viewModel,
        builder: (context, child) => Consumer<PostureTrackerViewModel>(
          builder: (context, postureTrackerViewModel, child) => _buildSettingsView(),
        )
      ),
    );
  }

  Widget _buildSettingsView() {
    return Column(
      children: [
        Card(
          color: Theme.of(context).colorScheme.primary,
          child: ListTile(
            title: Text("Status"),
            trailing: Text(_viewModel.isTracking ? "Tracking" : _viewModel.isAvailable ? "Available" : "Unavailable"),
          ),
        ),
        Card(
          color: Theme.of(context).colorScheme.primary,
          child: Column(
            children: [
              // add a switch to control the `isActive` property of the `BadPostureSettings`
              SwitchListTile(
                title: Text("Bad Posture Reminder"),
                value: _viewModel.badPostureSettings.isActive,
                onChanged: (value) {
                  BadPostureSettings settings = _viewModel.badPostureSettings;
                  settings.isActive = value;
                  _viewModel.setBadPostureSettings(settings);
                },
              ),
              Visibility(
                child: Column(
                  children: [
                    ListTile(
                      title: Text("Roll Angle Threshold (in degrees)"),
                      trailing: SizedBox(
                        height: 37.0,
                        width: 52,
                        child: TextField(
                          controller: _rollAngleThresholdController,
                          textAlign: TextAlign.end,
                          style: TextStyle(color: Colors.black),
                          decoration: InputDecoration(
                            contentPadding: EdgeInsets.all(10),
                            floatingLabelBehavior:
                                FloatingLabelBehavior.never,
                            border: OutlineInputBorder(),
                            labelText: 'Roll',
                            filled: true,
                            labelStyle: TextStyle(color: Colors.black),
                            fillColor: Colors.white
                          ),
                          keyboardType: TextInputType.number,
                          onChanged: (_) { _updatePostureSettings(); },
                        ),
                      ),
                    ),
                    ListTile(
                      title: Text("Pitch Angle Threshold (in degrees)"),
                      trailing: SizedBox(
                        height: 37.0,
                        width: 52,
                        child: TextField(
                          controller: _pitchAngleThresholdController,
                          textAlign: TextAlign.end,
                          style: TextStyle(color: Colors.black),
                          decoration: InputDecoration(
                            contentPadding: EdgeInsets.all(10),
                            floatingLabelBehavior:
                                FloatingLabelBehavior.never,
                            border: OutlineInputBorder(),
                            labelText: 'Pitch',
                            filled: true,
                            labelStyle: TextStyle(color: Colors.black),
                            fillColor: Colors.white
                          ),
                          keyboardType: TextInputType.number,
                          onChanged: (_) { _updatePostureSettings(); },
                        ),
                      ),
                    ),
                    ListTile(
                      title: Text("Bad Posture Time Threshold (in seconds)"),
                      trailing: SizedBox(
                        height: 37.0,
                        width: 52,
                        child: TextField(
                          controller: _badPostureTimeThresholdController,
                          textAlign: TextAlign.end,
                          style: TextStyle(color: Colors.black),
                          decoration: InputDecoration(
                            contentPadding: EdgeInsets.all(10),
                            floatingLabelBehavior:
                                FloatingLabelBehavior.never,
                            border: OutlineInputBorder(),
                            labelText: 'Seconds',
                            filled: true,
                            labelStyle: TextStyle(color: Colors.black),
                            fillColor: Colors.white
                          ),
                          keyboardType: TextInputType.number,
                          onChanged: (_) { _updatePostureSettings(); },
                        ),
                      ),
                    ),
                    ListTile(
                      title: Text("Good Posture Time Threshold (in seconds)"),
                      trailing: SizedBox(
                        height: 37.0,
                        width: 52,
                        child: TextField(
                          controller: _goodPostureTimeThresholdController,
                          textAlign: TextAlign.end,
                          style: TextStyle(color: Colors.black),
                          decoration: InputDecoration(
                            contentPadding: EdgeInsets.all(10),
                            floatingLabelBehavior:
                                FloatingLabelBehavior.never,
                            border: OutlineInputBorder(),
                            labelText: 'Seconds',
                            filled: true,
                            labelStyle: TextStyle(color: Colors.black),
                            fillColor: Colors.white
                          ),
                          keyboardType: TextInputType.number,
                          onChanged: (_) { _updatePostureSettings(); },
                        ),
                      ),
                    ),
                  ]
                ),
                visible: _viewModel.badPostureSettings.isActive
              ),
            ]
          )
          
        ),
        Padding(
          padding: EdgeInsets.all(8.0),
          child: Row(
              children: [
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: 
                      _viewModel.isTracking
                      ? Colors.green[300]
                      : Colors.blue[300],
                    foregroundColor: Colors.black,
                  ),
                  onPressed:
                    _viewModel.isTracking
                    ? () {
                      _viewModel.calibrate();
                      Navigator.of(context).pop();
                    }
                    : () => _viewModel.startTracking(),
                  child: Text(
                    _viewModel.isTracking
                    ? "Calibrate as Main Posture"
                    : "Start Calibration"
                  ),
                ),
              )
              ]
          ),
        ),
      ],
    );
  }

  void _updatePostureSettings() {
    BadPostureSettings settings = _viewModel.badPostureSettings;
    settings.rollAngleThreshold = int.parse(_rollAngleThresholdController.text);
    settings.pitchAngleThreshold = int.parse(_pitchAngleThresholdController.text);
    settings.timeThreshold = int.parse(_badPostureTimeThresholdController.text);
    settings.resetTimeThreshold = int.parse(_goodPostureTimeThresholdController.text);
    _viewModel.setBadPostureSettings(settings);
  }


  @override
  void dispose() {
    super.dispose();
  }
}