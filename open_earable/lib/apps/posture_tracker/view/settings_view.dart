import 'package:flutter/material.dart';
import 'package:open_earable/apps/posture_tracker/view_model/posture_tracker_view_model.dart';
import 'package:provider/provider.dart';

class SettingsView extends StatefulWidget {
  final PostureTrackerViewModel _viewModel;
  
  SettingsView(this._viewModel);

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  late final PostureTrackerViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = widget._viewModel;
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
                    ? "Set as default"
                    : "Start Calibration"
                  ),
                ),
              )
              ]
          ),
        )
      ],
    );
  }


  @override
  void dispose() {
    super.dispose();
  }
}