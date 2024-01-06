import 'package:flutter/material.dart';
import 'package:open_earable/apps/neck_stretcher/view_model/stretcher_view_model.dart';
import 'package:open_earable/apps/neck_stretcher/model/side_stretcher.dart';
import 'package:provider/provider.dart';

/// widget for side to side stretching settings
class SideSettingsView extends StatefulWidget {
  final StretcherViewModel _viewModel;

  SideSettingsView(this._viewModel);

  @override
  State<SideSettingsView> createState() => _SettingsViewState();
}

/// state to widget
class _SettingsViewState extends State<SideSettingsView> {
  late final TextEditingController _rollAngleLeftController;
  late final TextEditingController _rollAngleRightController;
  late final TextEditingController _stretchTimeThresholdController;

  late final StretcherViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = widget._viewModel;
    _rollAngleRightController = TextEditingController(
        text: _viewModel.stretcherSettings.rollAngleRight.toString());
    _rollAngleLeftController = TextEditingController(
        text: _viewModel.stretcherSettings.rollAngleLeft.toString());
    _stretchTimeThresholdController = TextEditingController(
        text: _viewModel.stretcherSettings.timeThreshold.toString());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Neck Stretcher Settings")),
      body: ChangeNotifierProvider<StretcherViewModel>.value(
          value: _viewModel,
          builder: (context, child) => Consumer<StretcherViewModel>(
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
                    title: Text("Left Roll Angle Threshold (in degrees)"),
                    trailing: SizedBox(
                      height: 37.0,
                      width: 52,
                      child: TextField(
                        controller: _rollAngleLeftController,
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
                          _updateSideStretchSettings();
                        },
                      ),
                    ),
                  ),
                  ListTile(
                    title: Text("Right Roll Angle Threshold (in degrees)"),
                    trailing: SizedBox(
                      height: 37.0,
                      width: 52,
                      child: TextField(
                        controller: _rollAngleRightController,
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
                          _updateSideStretchSettings();
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
                        controller: _stretchTimeThresholdController,
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
                          _updateSideStretchSettings();
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

  /// updates settings with input values
  void _updateSideStretchSettings() {
    SideStretcherSettings settings = _viewModel.stretcherSettings;
    settings.rollAngleRight = int.parse(_rollAngleRightController.text);
    settings.rollAngleLeft = int.parse(_rollAngleLeftController.text);
    settings.timeThreshold = int.parse(_stretchTimeThresholdController.text);
    _viewModel.setStretcherSettings(settings);
  }

  @override
  void dispose() {
    super.dispose();
  }
}
