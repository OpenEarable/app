// ignore_for_file: unnecessary_this

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:open_earable/apps/posture_tracker/model/attitude_tracker.dart';
import 'package:open_earable/apps/posture_tracker/model/mock_attitude_tracker.dart';
import 'package:open_earable/apps/posture_tracker/model/phone_attitude_tracker.dart';
import 'package:open_earable/apps/posture_tracker/view_model/posture_tracker_view_model.dart';
import 'package:provider/provider.dart';

class PostureTrackerView extends StatefulWidget {
  final AttitudeTracker _tracker;

  PostureTrackerView() : this._tracker = PhoneAttitudeTracker();

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
            builder: (context, value, child) => Center(
              child: Row(
                children: [
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text("Roll: ${this._viewModel.attitude.roll}"),
                      Text("Pitch: ${this._viewModel.attitude.pitch}"),
                      Text("Yaw: ${this._viewModel.attitude.yaw}"),
                    ],
                  ),
                  Column(
                    children: [
                      CupertinoButton(child: Text("start"), onPressed: () => this._viewModel.startTracking()),
                      CupertinoButton(child: Text("stop"), onPressed: () => this._viewModel.stopTracking()),
                    ],
                  )
                ]
              )
            )
          )
        )
      );
  }
}