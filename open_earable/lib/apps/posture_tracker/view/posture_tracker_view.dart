// ignore_for_file: unnecessary_this

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:open_earable/apps/posture_tracker/model/attitude_tracker.dart';
import 'package:open_earable/apps/posture_tracker/model/mock_attitude_tracker.dart';
import 'package:open_earable/apps/posture_tracker/model/phone_attitude_tracker.dart';
import 'package:open_earable/apps/posture_tracker/view/posture_roll_view.dart';
import 'package:open_earable/apps/posture_tracker/view_model/posture_tracker_view_model.dart';
import 'package:provider/provider.dart';

class PostureTrackerView extends StatefulWidget {
  final AttitudeTracker _tracker;

  PostureTrackerView() : this._tracker = MockAttitudeTracker();

  @override
  State<PostureTrackerView> createState() => _PostureTrackerViewState();
}

class _PostureTrackerViewState extends State<PostureTrackerView> {
  late final PostureTrackerViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    this._viewModel = PostureTrackerViewModel(widget._tracker);
  }

  @override
  Widget build(BuildContext context) {
    createHeadViews(postureTrackerViewModel) => [
      this._buildHeadView(
        "assets/posture_tracker/Head_Front.png",
        "assets/posture_tracker/Neck_Front.png",
        Alignment.center.add(Alignment(0, 0.3)),
        postureTrackerViewModel.attitude.roll
      ),
      this._buildHeadView(
        "assets/posture_tracker/Head_Side.png",
        "assets/posture_tracker/Neck_Side.png",
        Alignment.center.add(Alignment(0, 0.3)),
        postureTrackerViewModel.attitude.yaw
      ),
    ];

    return Scaffold(
        appBar: AppBar(
          title: const Text("Posture Tracker"),
        ),
        body: ChangeNotifierProvider<PostureTrackerViewModel>(
          create: (_) => this._viewModel,
          builder: (context, child) => Consumer<PostureTrackerViewModel>(
            builder: (context, postureTrackerViewModel, child) => Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(children: createHeadViews(postureTrackerViewModel)),
                CupertinoButton(
                  onPressed: postureTrackerViewModel.isTracking ? () => this._viewModel.stopTracking() : () => this._viewModel.startTracking(),
                  color: postureTrackerViewModel.isTracking ? Colors.red : Colors.green,
                  child: postureTrackerViewModel.isTracking ? const Text("Stop Tracking") : const Text("Start Tracking"),
                ),
              ]
            )
          )
        )
      );
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
}
