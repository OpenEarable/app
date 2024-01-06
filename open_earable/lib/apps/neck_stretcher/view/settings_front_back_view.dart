import 'package:open_earable/apps/neck_stretcher/model/front_back_stretcher.dart';
import 'package:open_earable/apps/neck_stretcher/view_model/device_view_model.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// widget for settings for the front back stretching exercise
class FrontBackSettingsView extends StatefulWidget {
  final DeviceViewModel _viewModel;

  FrontBackSettingsView(this._viewModel);

  @override
  State<FrontBackSettingsView> createState() => _SettingsViewState();
}

/// state of widget
class _SettingsViewState extends State<FrontBackSettingsView>{
  late final TextEditingController _pitchAngleForwardController;
  late final TextEditingController _pitchAngleBackwardController;
  late final TextEditingController _timeThresholdController;
  late final DeviceViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = widget._viewModel;
    _pitchAngleForwardController = TextEditingController(
        text: _viewModel.stretcherSettings.pitchAngleForward.toString());
    _pitchAngleBackwardController = TextEditingController(
        text: _viewModel.stretcherSettings.pitchAngleBackward.toString());
    _timeThresholdController = TextEditingController(
        text: _viewModel.stretcherSettings.timeThreshold.toString());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Neck Stretcher Settings")),
      body: ChangeNotifierProvider<DeviceViewModel>.value(
          value: _viewModel,
          builder: (context, child) => Consumer<DeviceViewModel>(
            builder: (context, postureStretcherViewModel, child) =>
                _buildSettingsView(),
          )),
    );
  }

  Widget _buildSettingsView() {
    return Column(children: [
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
          child: Column(children: [
            Visibility(
                child: Column(children: [
                  ListTile(
                    title: Text("Backwards Pitch Angle Threshold (in degrees)"),
                    trailing: SizedBox(
                      height: 37.0,
                      width: 52,
                      child: TextField(
                        controller: _pitchAngleBackwardController,
                        textAlign: TextAlign.end,
                        style: TextStyle(color: Colors.black),
                        decoration: InputDecoration(
                            contentPadding: EdgeInsets.all(10),
                            floatingLabelBehavior: FloatingLabelBehavior.never,
                            border: OutlineInputBorder(),
                            labelText: 'Roll',
                            filled: true,
                            labelStyle: TextStyle(color: Colors.black),
                            fillColor: Colors.white),
                        keyboardType: TextInputType.number,
                        onChanged: (_) {
                          /// changes settings
                          _updateFrontBackStretchSettings();
                        },
                      ),
                    ),
                  ),
                  ListTile(
                    title: Text("Forwards Pitch Angle Threshold (in degrees)"),
                    trailing: SizedBox(
                      height: 37.0,
                      width: 52,
                      child: TextField(
                        controller: _pitchAngleForwardController,
                        textAlign: TextAlign.end,
                        style: TextStyle(color: Colors.black),
                        decoration: InputDecoration(
                            contentPadding: EdgeInsets.all(10),
                            floatingLabelBehavior: FloatingLabelBehavior.never,
                            border: OutlineInputBorder(),
                            labelText: 'Roll',
                            filled: true,
                            labelStyle: TextStyle(color: Colors.black),
                            fillColor: Colors.white),
                        keyboardType: TextInputType.number,
                        onChanged: (_) {
                          _updateFrontBackStretchSettings();
                        },
                      ),
                    ),
                  ),
                  ListTile(
                    title: Text("Stretch Time Threshold (in seconds)"),
                    trailing: SizedBox(
                      height: 37.0,
                      width: 52,
                      child: TextField(
                        controller: _timeThresholdController,
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
                          _updateFrontBackStretchSettings();
                        },
                      ),
                    ),
                  ),
                ]),
                visible: _viewModel.stretcherSettings.isActive),
          ])),
      Padding(
        padding: EdgeInsets.all(8.0),
      ),
    ]);
  }

  /// change / update the settings with input values
  void _updateFrontBackStretchSettings() {
    FrontBackStretcherSettings settings = _viewModel.stretcherSettings;
    settings.pitchAngleBackward = int.parse(_pitchAngleBackwardController.text);
    settings.pitchAngleForward = int.parse(_pitchAngleForwardController.text);
    settings.timeThreshold = int.parse(_timeThresholdController.text);
    _viewModel.setStretcherSettings(settings);
  }

  @override
  void dispose() {
    super.dispose();
  }

}