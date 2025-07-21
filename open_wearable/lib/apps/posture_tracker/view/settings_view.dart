import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:open_wearable/apps/posture_tracker/model/bad_posture_reminder.dart';
import 'package:open_wearable/apps/posture_tracker/view_model/posture_tracker_view_model.dart';
import 'package:provider/provider.dart';

class SettingsView extends StatefulWidget {
  final PostureTrackerViewModel _viewModel;

  const SettingsView(this._viewModel, {super.key});

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
    _rollAngleThresholdController = TextEditingController(
        text: _viewModel.badPostureSettings.rollAngleThreshold.toString(),);
    _pitchAngleThresholdController = TextEditingController(
        text: _viewModel.badPostureSettings.pitchAngleThreshold.toString(),);
    _badPostureTimeThresholdController = TextEditingController(
        text: _viewModel.badPostureSettings.timeThreshold.toString(),);
    _goodPostureTimeThresholdController = TextEditingController(
        text: _viewModel.badPostureSettings.resetTimeThreshold.toString(),);
  }

  @override
  Widget build(BuildContext context) {
    return PlatformScaffold(
      appBar: PlatformAppBar(title: PlatformText("Posture Tracker Settings")),
      body: ChangeNotifierProvider<PostureTrackerViewModel>.value(
          value: _viewModel,
          builder: (context, child) => Consumer<PostureTrackerViewModel>(
                builder: (context, postureTrackerViewModel, child) =>
                    _buildSettingsView(),
              ),),
      backgroundColor: Theme.of(context).colorScheme.surface,
    );
  }

  Widget _buildSettingsView() {
    return Padding(
      padding: EdgeInsets.all(10),
      child: Column(
      children: [
        Card(
          child: PlatformListTile(
            title: PlatformText("Status"),
            trailing: PlatformText(_viewModel.isTracking
                ? "Tracking"
                : _viewModel.isAvailable
                    ? "Available"
                    : "Unavailable",),
          ),
        ),
        Card(
          child: Column(children: [
            // add a switch to control the `isActive` property of the `BadPostureSettings`
            PlatformListTile(
              title: PlatformText("Bad Posture Reminder"),
              trailing: PlatformSwitch(
                value: _viewModel.badPostureSettings.isActive,
                onChanged: (value) {
                  BadPostureSettings settings = _viewModel.badPostureSettings;
                  settings.isActive = value;
                  _viewModel.setBadPostureSettings(settings);
                },
              ),
            ),
            Visibility(
                visible: _viewModel.badPostureSettings.isActive,
                child: Column(children: [
                  PlatformListTile(
                    title: PlatformText("Roll Angle Threshold (in degrees)"),
                    trailing: SizedBox(
                      height: 37.0,
                      width: 52,
                      //TODO: use cupertino text field on ios
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
                            fillColor: Colors.white,),
                        keyboardType: TextInputType.number,
                        onChanged: (_) {
                          _updatePostureSettings();
                        },
                      ),
                    ),
                  ),
                  PlatformListTile(
                    title: PlatformText("Pitch Angle Threshold (in degrees)"),
                    trailing: SizedBox(
                      height: 37.0,
                      width: 52,
                      //TODO: use cupertino text field on ios
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
                            fillColor: Colors.white,),
                        keyboardType: TextInputType.number,
                        onChanged: (_) {
                          _updatePostureSettings();
                        },
                      ),
                    ),
                  ),
                  PlatformListTile(
                    title: PlatformText("Bad Posture Time Threshold (in seconds)"),
                    trailing: SizedBox(
                      height: 37.0,
                      width: 52,
                      //TODO: use cupertino text field on ios
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
                            fillColor: Colors.white,),
                        keyboardType: TextInputType.number,
                        onChanged: (_) {
                          _updatePostureSettings();
                        },
                      ),
                    ),
                  ),
                  PlatformListTile(
                    title: PlatformText("Good Posture Time Threshold (in seconds)"),
                    trailing: SizedBox(
                      height: 37.0,
                      width: 52,
                      //TODO: use cupertino text field on ios
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
                            fillColor: Colors.white,),
                        keyboardType: TextInputType.number,
                        onChanged: (_) {
                          _updatePostureSettings();
                        },
                      ),
                    ),
                  ),
                ],),),
          ],),),
        Padding(
          padding: EdgeInsets.only(top: 8.0),
          child: Row(children: [
            Expanded(
              child: PlatformElevatedButton(
                color: _viewModel.isTracking
                    ? Colors.green[300]
                    : Colors.blue[300],
                onPressed: _viewModel.isTracking
                    ? () {
                        _viewModel.calibrate();
                        Navigator.of(context).pop();
                      }
                    : () => _viewModel.startTracking(),
                child: PlatformText(_viewModel.isTracking
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

  void _updatePostureSettings() {
    BadPostureSettings settings = _viewModel.badPostureSettings;
    settings.rollAngleThreshold = int.parse(_rollAngleThresholdController.text);
    settings.pitchAngleThreshold =
        int.parse(_pitchAngleThresholdController.text);
    settings.timeThreshold = int.parse(_badPostureTimeThresholdController.text);
    settings.resetTimeThreshold =
        int.parse(_goodPostureTimeThresholdController.text);
    _viewModel.setBadPostureSettings(settings);
  }

  @override
  void dispose() {
    super.dispose();
  }
}
