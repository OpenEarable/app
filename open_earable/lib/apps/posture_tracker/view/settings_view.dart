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
      ],
    );
  }


  @override
  void dispose() {
    super.dispose();
  }
}