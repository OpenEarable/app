// ignore_for_file: unnecessary_this

import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:open_wearable/apps/posture_tracker/model/attitude_tracker.dart';
import 'package:open_wearable/apps/posture_tracker/model/bad_posture_reminder.dart';
import 'package:open_wearable/apps/posture_tracker/view/posture_roll_view.dart';
import 'package:open_wearable/apps/posture_tracker/view/settings_view.dart';
import 'package:open_wearable/apps/posture_tracker/view_model/posture_tracker_view_model.dart';
import 'package:provider/provider.dart';

class PostureTrackerView extends StatefulWidget {
  final AttitudeTracker _tracker;

  const PostureTrackerView(this._tracker, {super.key});

  @override
  State<PostureTrackerView> createState() => _PostureTrackerViewState();
}

class _PostureTrackerViewState extends State<PostureTrackerView> {
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<PostureTrackerViewModel>(
        create: (context) => PostureTrackerViewModel(widget._tracker,
            BadPostureReminder(attitudeTracker: widget._tracker),),
        builder: (context, child) => Consumer<PostureTrackerViewModel>(
            builder: (context, postureTrackerViewModel, child) => Scaffold(
                  appBar: AppBar(
                    title: PlatformText("Posture Tracker"),
                    actions: [
                      IconButton(
                          onPressed: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                  builder: (context) =>
                                      SettingsView(postureTrackerViewModel),),),
                          icon: Icon(Icons.settings),),
                    ],
                  ),
                  body: Center(
                    child: this._buildContentView(postureTrackerViewModel),
                  ),
                  backgroundColor: Theme.of(context).colorScheme.surface,
                ),),);
  }

  Widget _buildContentView(PostureTrackerViewModel postureTrackerViewModel) {
    var headViews = this._createHeadViews(postureTrackerViewModel);
    return Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      ...headViews.map((e) => FractionallySizedBox(
            widthFactor: .7,
            child: e,
          ),),
      this._buildTrackingButton(postureTrackerViewModel),
    ],);
  }

  Widget _buildHeadView(String headAssetPath, String neckAssetPath,
      AlignmentGeometry headAlignment, double roll, double angleThreshold,) {
    return Padding(
      padding: const EdgeInsets.all(5),
      child: PostureRollView(
        roll: roll,
        angleThreshold: angleThreshold * 3.14 / 180,
        headAssetPath: headAssetPath,
        neckAssetPath: neckAssetPath,
        headAlignment: headAlignment,
      ),
    );
  }

  List<Widget> _createHeadViews(postureTrackerViewModel) {
    return [
      this._buildHeadView(
          "lib/apps/posture_tracker/assets/Head_Front.png",
          "lib/apps/posture_tracker/assets/Neck_Front.png",
          Alignment.center.add(Alignment(0, 0.3)),
          postureTrackerViewModel.attitude.roll,
          postureTrackerViewModel.badPostureSettings.rollAngleThreshold
              .toDouble(),),
      this._buildHeadView(
          "lib/apps/posture_tracker/assets/Head_Side.png",
          "lib/apps/posture_tracker/assets/Neck_Side.png",
          Alignment.center.add(Alignment(0, 0.3)),
          -postureTrackerViewModel.attitude.pitch,
          postureTrackerViewModel.badPostureSettings.pitchAngleThreshold
              .toDouble(),),
    ];
  }

  Widget _buildTrackingButton(PostureTrackerViewModel postureTrackerViewModel) {
    return Column(children: [
      ElevatedButton(
        onPressed: postureTrackerViewModel.isAvailable
            ? () {
                postureTrackerViewModel.isTracking
                    ? postureTrackerViewModel.stopTracking()
                    : postureTrackerViewModel.startTracking();
              }
            : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: !postureTrackerViewModel.isTracking
              ? Color(0xff77F2A1)
              : Color(0xfff27777),
          foregroundColor: Colors.black,
        ),
        child: postureTrackerViewModel.isTracking
            ? PlatformText("Stop Tracking")
            : PlatformText("Start Tracking"),
      ),
      Visibility(
        visible: !postureTrackerViewModel.isAvailable,
        maintainState: true,
        maintainAnimation: true,
        maintainSize: true,
        child: PlatformText(
          "No Earable Connected",
          style: TextStyle(
            color: Colors.red,
            fontSize: 12,
          ),
        ),
      ),
    ],);
  }
}
