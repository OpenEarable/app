import 'package:flutter/material.dart';
import 'package:open_earable/apps_tab/neck_stretch/model/stretch_state.dart';
import 'package:open_earable/apps_tab/neck_stretch/view_model/stretch_view_model.dart';

class StretchStatsView extends StatefulWidget {
  final StretchViewModel _viewModel;

  const StretchStatsView(this._viewModel, {super.key});

  @override
  State<StretchStatsView> createState() => _StretchStatsViewState();
}

/// Stateful Widget to display the current stretching stats of the most recent stretch
class _StretchStatsViewState extends State<StretchStatsView> {
  /// The stretching stats
  late StretchStats _stats;

  @override
  void initState() {
    super.initState();
    _stats = widget._viewModel.stretchStats;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(title: const Text("Stretch Stats")),
      body: SingleChildScrollView(
        child: Column(
          children: <Widget>[
            Card(
              color: Theme.of(context).colorScheme.primary,
              child: Column(
                children: [
                  ListTile(
                    title: Text("Maximum Stretch Angle Achieved"),
                  ),
                  ListTile(
                    title: Text("Main Stretch Max Angle:"),
                    trailing: Text(
                        "${(_stats.maxMainAngle * 180 / 3.14).abs().toStringAsFixed(0)}°",),
                  ),
                  ListTile(
                    title: Text("Right Stretch Max Angle:"),
                    trailing: Text(
                        "${(_stats.maxRightAngle * 180 / 3.14).abs().toStringAsFixed(0)}°",),
                  ),
                  ListTile(
                    title: Text("Left Stretch Max Angle:"),
                    trailing: Text(
                        "${(_stats.maxLeftAngle * 180 / 3.14).abs().toStringAsFixed(0)}°",),
                  ),
                ],
              ),
            ),
            Card(
              color: Theme.of(context).colorScheme.primary,
              child: Column(
                children: <Widget>[
                  ListTile(
                    title: Text("Stretch Duration over Threshold Angle"),
                  ),
                  ListTile(
                    title: Text("Main Neck Stretch Duration"),
                    trailing: Text(
                        "${_stats.mainStretchDuration.toStringAsFixed(2)} s",),
                  ),
                  ListTile(
                    title: Text("Right Neck Stretch Duration"),
                    trailing: Text(
                        "${_stats.rightStretchDuration.toStringAsFixed(2)} s",),
                  ),
                  ListTile(
                    title: Text("Left Neck Stretch Duration"),
                    trailing: Text(
                        "${_stats.leftStretchDuration.toStringAsFixed(2)} s",),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
