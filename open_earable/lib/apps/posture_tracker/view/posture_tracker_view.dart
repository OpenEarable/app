// ignore_for_file: unnecessary_this

import 'package:flutter/material.dart';
import 'package:open_earable/apps/posture_tracker/model/attitude_tracker.dart';
import 'package:open_earable/apps/posture_tracker/model/bad_posture_reminder.dart';
import 'package:open_earable/apps/posture_tracker/view/posture_roll_view.dart';
import 'package:open_earable/apps/posture_tracker/view/settings_view.dart';
import 'package:open_earable/apps/posture_tracker/view_model/posture_tracker_view_model.dart';
import 'package:provider/provider.dart';

import 'package:open_earable_flutter/src/open_earable_flutter.dart';


class PostureTrackerView extends StatefulWidget {
  final AttitudeTracker _tracker;
  final OpenEarable _openEarable;

  PostureTrackerView(this._tracker, this._openEarable);

  @override
  State<PostureTrackerView> createState() => _PostureTrackerViewState();
}

class _PostureTrackerViewState extends State<PostureTrackerView> {
  late final PostureTrackerViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    this._viewModel = PostureTrackerViewModel(widget._tracker, BadPostureReminder(widget._openEarable, widget._tracker));
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<PostureTrackerViewModel>.value(
        value: _viewModel,
        builder: (context, child) => Consumer<PostureTrackerViewModel>(
          builder: (context, postureTrackerViewModel, child) => Scaffold(
            appBar: AppBar(
              title: const Text("Posture Tracker"),
              actions: [
                IconButton(
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (context) => SettingsView(this._viewModel))),
                  icon: Icon(Icons.settings)
                ),
              ],
            ),
            body: _buildContentView(postureTrackerViewModel)
          )
        )
      );
  }

  Widget _buildContentView(PostureTrackerViewModel postureTrackerViewModel) {
    var orientation = MediaQuery.of(context).orientation;
    switch (orientation) {
      case Orientation.landscape:
        return Center(child: LayoutBuilder(
          builder: (context, constraints) => SizedBox(
            width: constraints.maxWidth / 2,
            child: Column(
              children: [
                Row(
                  children: this._createHeadViews(postureTrackerViewModel)
                ),
                this._buildTrackingButton(postureTrackerViewModel),
              ]
            )
          )
        ));

      case Orientation.portrait:
        var headViews = this._createHeadViews(postureTrackerViewModel);
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: headViews
            ),
            this._buildTrackingButton(postureTrackerViewModel),
          ]
        );
    }
  }

  Widget _buildHeadView(String headAssetPath, String neckAssetPath, AlignmentGeometry headAlignment, double roll) {
    return Flexible(
      fit: FlexFit.loose,
      child: Padding(
        padding: const EdgeInsets.all(5),
        child: PostureRollView(
          roll: roll,
          headAssetPath: headAssetPath,
          neckAssetPath: neckAssetPath,
          headAlignment: headAlignment,
        ),
      )
    );
  }

  List<Widget> _createHeadViews(postureTrackerViewModel) {
    return [
      this._buildHeadView(
        "assets/posture_tracker/Head_Front.png",
        "assets/posture_tracker/Neck_Front.png",
        Alignment.center.add(Alignment(0, 0.3)),
        -postureTrackerViewModel.attitude.roll
      ),
      this._buildHeadView(
        "assets/posture_tracker/Head_Side.png",
        "assets/posture_tracker/Neck_Side.png",
        Alignment.center.add(Alignment(0, 0.3)),
        -postureTrackerViewModel.attitude.pitch
      ),
    ];
  }
  
  Widget _buildTrackingButton(PostureTrackerViewModel postureTrackerViewModel) {
    return Column(children: [
      ElevatedButton(
        onPressed: postureTrackerViewModel.isAvailable
          ? () { postureTrackerViewModel.isTracking ? this._viewModel.stopTracking() : this._viewModel.startTracking(); }
          : null,
        style: ElevatedButton.styleFrom(
            backgroundColor: !postureTrackerViewModel.isTracking ? Color(0xff77F2A1) : Color(0xfff27777),
            foregroundColor: Colors.black,
          ),
        child: postureTrackerViewModel.isTracking ? const Text("Stop Tracking") : const Text("Start Tracking"),
      ),
      Visibility(
        visible: !postureTrackerViewModel.isAvailable,
        maintainState: true,
        maintainAnimation: true,
        maintainSize: true,
        child: Text(
          "No Earable Connected",
          style: TextStyle(
            color: Colors.red,
            fontSize: 12,
          ),
        ),
      )
    ]);
  }
}
