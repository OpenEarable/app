import 'package:flutter/material.dart';
import 'package:open_earable/apps/driving_assistant/controller/driving_assistant_notifier.dart';
import 'package:open_earable/apps/driving_assistant/view/driving_assistant_view.dart';
import 'package:open_earable/apps/driving_assistant/controller/tiredness_monitor.dart';
import 'package:open_earable/apps/posture_tracker/model/bad_posture_reminder.dart';
import 'package:open_earable/apps/posture_tracker/view_model/posture_tracker_view_model.dart';
import 'package:provider/provider.dart';

class DrivingSettingsView extends StatefulWidget {
  final DrivingAssistantNotifier _drivingNotifier;
  final DrivingAssistantView _view;

  DrivingSettingsView(this._drivingNotifier, this._view);

  @override
  State<DrivingSettingsView> createState() => _DrivingSettingsViewState();
}

class _DrivingSettingsViewState extends State<DrivingSettingsView> {
  late final TextEditingController _timeDeltaController;
  late final TextEditingController _pitchAngleThresholdController;
  late final TextEditingController _yellowController;
  late final TextEditingController _redController;

  late final DrivingAssistantNotifier _drivingNotifier;
  late final DrivingAssistantView _drivingAssistantView;

  @override
  void initState() {
    super.initState();
    _drivingNotifier = widget._drivingNotifier;
    _drivingAssistantView = widget._view;
    _timeDeltaController = TextEditingController(
        text: _drivingNotifier.monitor.settings.timeOffset.toString());
    _yellowController = TextEditingController(
        text: _drivingNotifier.monitor.settings.timesToYellow.toString());
    _redController = TextEditingController(
        text: _drivingNotifier.monitor.settings.timesToRed.toString());
    _pitchAngleThresholdController = TextEditingController(
        text: _drivingNotifier.monitor.settings.gyroYThreshold.toString());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Posture Tracker Settings")),
      body: ChangeNotifierProvider<DrivingAssistantNotifier>.value(
        value: _drivingNotifier,
        builder: (context, child) => Consumer<DrivingAssistantNotifier>(
          builder: (context, DrivingAssistantNotifier, child) =>
              _buildDrivingSettingsView(),
        ),
      ),
    );
  }

  Widget _buildDrivingSettingsView() {
    return Column(
      children: [
        Card(
          color: Theme.of(context).colorScheme.primary,
          child: ListTile(
            title: Text("Status"),
            trailing: Text(_drivingNotifier.isTracking
                ? "Tracking"
                : _drivingNotifier.isAvailable
                    ? "Available"
                    : "Unavailable"),
          ),
        ),
        Card(
          color: Theme.of(context).colorScheme.primary,
          child: Column(children: [
            Column(children: [
              ListTile(
                title: Text("Time offset before next possible alarm"),
                trailing: SizedBox(
                  height: 37.0,
                  width: 52,
                  child: TextField(
                    controller: _timeDeltaController,
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
                      _updatePostureSettings();
                    },
                  ),
                ),
              ),
              ListTile(
                title: Text("Gyro Y Threshold (in degrees)"),
                trailing: SizedBox(
                  height: 37.0,
                  width: 52,
                  child: TextField(
                    controller: _pitchAngleThresholdController,
                    textAlign: TextAlign.end,
                    style: TextStyle(color: Colors.black),
                    decoration: InputDecoration(
                        contentPadding: EdgeInsets.all(10),
                        floatingLabelBehavior: FloatingLabelBehavior.never,
                        border: OutlineInputBorder(),
                        labelText: 'Degrees',
                        filled: true,
                        labelStyle: TextStyle(color: Colors.black),
                        fillColor: Colors.white),
                    keyboardType: TextInputType.number,
                    onChanged: (_) {
                      _updatePostureSettings();
                    },
                  ),
                ),
              ),
              ListTile(
                title: Text("Signs of tiredness till yellow cup"),
                trailing: SizedBox(
                  height: 37.0,
                  width: 52,
                  child: TextField(
                    controller: _yellowController,
                    textAlign: TextAlign.end,
                    style: TextStyle(color: Colors.black),
                    decoration: InputDecoration(
                        contentPadding: EdgeInsets.all(10),
                        floatingLabelBehavior: FloatingLabelBehavior.never,
                        border: OutlineInputBorder(),
                        labelText: 'Times',
                        filled: true,
                        labelStyle: TextStyle(color: Colors.black),
                        fillColor: Colors.white),
                    keyboardType: TextInputType.number,
                    onChanged: (_) {
                      _updatePostureSettings();
                    },
                  ),
                ),
              ),
              ListTile(
                title: Text("Signs of tiredness till red cup"),
                trailing: SizedBox(
                  height: 37.0,
                  width: 52,
                  child: TextField(
                    controller: _redController,
                    textAlign: TextAlign.end,
                    style: TextStyle(color: Colors.black),
                    decoration: InputDecoration(
                        contentPadding: EdgeInsets.all(10),
                        floatingLabelBehavior: FloatingLabelBehavior.never,
                        border: OutlineInputBorder(),
                        labelText: 'Times',
                        filled: true,
                        labelStyle: TextStyle(color: Colors.black),
                        fillColor: Colors.white),
                    keyboardType: TextInputType.number,
                    onChanged: (_) {
                      _updatePostureSettings();
                    },
                  ),
                ),
              ),
            ]),
          ]),
        ),
      ],
    );
  }

  void _updatePostureSettings() {
    TrackingSettings settings = _drivingNotifier.monitor.settings;
    settings.timeOffset = int.parse(_timeDeltaController.text);
    settings.gyroYThreshold = int.parse(_pitchAngleThresholdController.text);
    settings.timesToYellow = int.parse(_yellowController.text);
    settings.timesToRed = int.parse(_redController.text);
    _drivingNotifier.setTrackingSettings(settings);
  }

  @override
  void dispose() {
    super.dispose();
  }
}
