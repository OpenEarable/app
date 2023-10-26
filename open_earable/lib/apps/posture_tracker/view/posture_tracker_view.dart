// ignore_for_file: unnecessary_this

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:open_earable/apps/posture_tracker/model/attitude_tracker.dart';
import 'package:open_earable/apps/posture_tracker/model/mock_attitude_tracker.dart';
import 'package:open_earable/apps/posture_tracker/model/phone_attitude_tracker.dart';
import 'package:open_earable/apps/posture_tracker/view/posture_roll_view.dart';
import 'package:open_earable/apps/posture_tracker/view_model/posture_tracker_view_model.dart';
import 'package:provider/provider.dart';
import 'package:open_earable_flutter/src/open_earable_flutter.dart';

class PostureTrackerView extends StatefulWidget {
  final AttitudeTracker _tracker;

  PostureTrackerView(this._tracker);

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
    return Scaffold(
      appBar: AppBar(
        title: const Text("Posture Tracker"),
      ),
      body: ChangeNotifierProvider<PostureTrackerViewModel>(
        create: (_) => this._viewModel,
        builder: (context, child) => Consumer<PostureTrackerViewModel>(
          builder: (context, postureTrackerViewModel, child) => this._buildContentView(postureTrackerViewModel)
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
        postureTrackerViewModel.attitude.roll
      ),
      this._buildHeadView(
        "assets/posture_tracker/Head_Side.png",
        "assets/posture_tracker/Neck_Side.png",
        Alignment.center.add(Alignment(0, 0.3)),
        postureTrackerViewModel.attitude.yaw
      ),
    ];
  }
  
  Widget _buildTrackingButton(PostureTrackerViewModel postureTrackerViewModel) {
    return ElevatedButton(
      onPressed: () { postureTrackerViewModel.isTracking ? this._viewModel.stopTracking() : this._viewModel.startTracking(); },
      style: ElevatedButton.styleFrom(
          backgroundColor: !postureTrackerViewModel.isTracking ? Color(0xff77F2A1) : Color(0xfff27777),
          foregroundColor: Colors.black,
        ),
      child: postureTrackerViewModel.isTracking ? const Text("Stop Tracking") : const Text("Start Tracking"),
    );
  }
}
