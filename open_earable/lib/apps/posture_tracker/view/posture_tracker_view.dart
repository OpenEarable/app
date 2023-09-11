// ignore_for_file: unnecessary_this

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:open_earable/apps/posture_tracker/model/attitude_tracker.dart';
import 'package:open_earable/apps/posture_tracker/model/mock_attitude_tracker.dart';
import 'package:open_earable/apps/posture_tracker/model/phone_attitude_tracker.dart';
import 'package:open_earable/apps/posture_tracker/view/face_sketch_painter.dart';
import 'package:open_earable/apps/posture_tracker/view/posture_roll_view.dart';
import 'package:open_earable/apps/posture_tracker/view_model/posture_tracker_view_model.dart';
import 'package:provider/provider.dart';

class PostureTrackerView extends StatefulWidget {
  final AttitudeTracker _tracker;

  PostureTrackerView() : this._tracker = MockAttitudeTracker();

  @override
  _PostureTrackerViewState createState() => _PostureTrackerViewState(this._tracker);
}

class _PostureTrackerViewState extends State<PostureTrackerView> {
  final PostureTrackerViewModel _viewModel;

  _PostureTrackerViewState(AttitudeTracker tracker) : this._viewModel = PostureTrackerViewModel(tracker);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text("Posture Tracker"),
        ),
        body: ChangeNotifierProvider<PostureTrackerViewModel>(
          create: (_) => this._viewModel,
          builder: (context, child) => Consumer<PostureTrackerViewModel>(
            builder: (context, value, child) => Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: PostureRollView(
                        roll: value.attitude.roll,
                        headAssetPath: "assets/posture_tracker/Head_Front.png",
                        neckAssetPath: "assets/posture_tracker/Neck_Front.png",
                        headAlignment: Alignment.center.add(Alignment(0, 0.25)),
                      )
                    ),
                    Expanded(
                      child: PostureRollView(
                        roll: value.attitude.pitch,
                        headAssetPath: "assets/posture_tracker/Head_Side.png",
                        neckAssetPath: "assets/posture_tracker/Neck_Side.png",
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    CupertinoButton(child: Text("start"), onPressed: () => this._viewModel.startTracking()),
                    CupertinoButton(child: Text("stop"), onPressed: () => this._viewModel.stopTracking()),
                  ],
                )
              ]
            )
          )
        )
      );
  }
}