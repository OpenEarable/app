import 'package:flutter/material.dart';
import 'package:open_earable/apps/posture_tracker/model/meditation_state.dart';
import 'package:open_earable/apps/posture_tracker/view_model/meditation_view_model.dart';
import 'package:provider/provider.dart';

class SettingsView extends StatefulWidget {
  final MeditationViewModel _viewModel;

  SettingsView(this._viewModel);

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  late final TextEditingController _mainNeckDuration;
  late final TextEditingController _leftNeckDuration;
  late final TextEditingController _rightNeckDuration;

  late final MeditationViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    this._viewModel = widget._viewModel;
    _mainNeckDuration = TextEditingController(
        text: _viewModel.meditationSettings.mainNeckRelaxation.inSeconds.toString());
    _leftNeckDuration = TextEditingController(
        text: _viewModel.meditationSettings.leftNeckRelaxation.inSeconds.toString());
    _rightNeckDuration = TextEditingController(
        text: _viewModel.meditationSettings.rightNeckRelaxation.inSeconds.toString());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Guided Neck Meditation Settings")),
      body: ChangeNotifierProvider<MeditationViewModel>.value(
          value: _viewModel,
          builder: (context, child) => Consumer<MeditationViewModel>(
                builder: (context, postureTrackerViewModel, child) =>
                    _buildSettingsView(),
              )),
    );
  }

  Widget _buildSettingsView() {
    return Column(
      children: [
        Card(
          color: Theme.of(context).colorScheme.primary,
          child: ListTile(
            title: Text("Status"),
            trailing: Text(_viewModel.isTracking
                ? "Tracking"
                : _viewModel.isAvailable
                    ? "Available"
                    : "Unavailable"),
          ),
        ),
        Card(
          color: Theme.of(context).colorScheme.primary,
          child: Column(
            children: [
              // add a switch to control the `isActive` property of the `BadPostureSettings`
              ListTile(
                title: Text("Guided Neck Relaxation"),
              ),
              ListTile(
                title: Text("Main Neck Relaxation Duration (in seconds)"),
                trailing: SizedBox(
                  height: 37.0,
                  width: 52,
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
                        fillColor: Colors.white),
                    keyboardType: TextInputType.number,
                    onChanged: (_) {
                      _updateMeditationSettings();
                    },
                  ),
                ),
              ),
              ListTile(
                title: Text("Left Neck Relaxation Duration (in seconds)"),
                trailing: SizedBox(
                  height: 37.0,
                  width: 52,
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
                        fillColor: Colors.white),
                    keyboardType: TextInputType.number,
                    onChanged: (_) {
                      _updateMeditationSettings();
                    },
                  ),
                ),
              ),
              ListTile(
                title: Text("Right Neck Relaxation Duration (in seconds)"),
                trailing: SizedBox(
                  height: 37.0,
                  width: 52,
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
                        fillColor: Colors.white),
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
                        Navigator.of(context).pop();
                      }
                    : () => _viewModel.startTracking(),
                child: Text(_viewModel.isTracking
                    ? "Calibrate as Main Posture"
                    : "Start Calibration"),
              ),
            )
          ]),
        ),
      ],
    );
  }

  void _updateMeditationSettings() {
    MeditationSettings settings = _viewModel.meditationSettings;
    settings.mainNeckRelaxation = Duration(seconds:int.parse(_mainNeckDuration.text));
    settings.rightNeckRelaxation = Duration(seconds:int.parse(_rightNeckDuration.text));
    settings.leftNeckRelaxation = Duration(seconds:int.parse(_leftNeckDuration.text));
    _viewModel.setMeditationSettings(settings);
  }

  @override
  void dispose() {
    super.dispose();
  }
}
