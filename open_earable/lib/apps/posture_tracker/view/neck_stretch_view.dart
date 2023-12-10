// ignore_for_file: unnecessary_this

import 'package:flutter/material.dart';
import 'package:open_earable/apps/posture_tracker/model/attitude_tracker.dart';
import 'package:open_earable/apps/posture_tracker/view/posture_roll_view.dart';
import 'package:open_earable/apps/posture_tracker/view_model/neck_stretch_view_model.dart';
import 'package:provider/provider.dart';

import 'package:open_earable_flutter/src/open_earable_flutter.dart';

enum MeditationState { mainNeckStretch, leftNeckStretch, rightNeckStretch }

extension MeditationStateExtension on MeditationState {
  String get display {
    switch (this) {
      case MeditationState.mainNeckStretch:
        return 'Main neck area';
      case MeditationState.leftNeckStretch:
        return 'Right neck area';
      case MeditationState.rightNeckStretch:
        return 'Left neck area';
      default:
        return 'Invalid State';
    }
  }
}

class NeckStretchView extends StatefulWidget {
  final AttitudeTracker _tracker;
  final OpenEarable _openEarable;

  NeckStretchView(this._tracker, this._openEarable);

  @override
  State<NeckStretchView> createState() => _NeckStretchViewState();
}

class _NeckStretchViewState extends State<NeckStretchView> {
  late final NeckStretchViewModel _viewModel;
  var _stretchState = MeditationState.mainNeckStretch;

  @override
  void initState() {
    super.initState();
    this._viewModel = NeckStretchViewModel(widget._tracker);
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<NeckStretchViewModel>.value(
        value: _viewModel,
        builder: (context, child) => Consumer<NeckStretchViewModel>(
            builder: (context, neckStretchViewModel, child) => Scaffold(
                  appBar: AppBar(
                    title: const Text("Guided Neck Relaxation"),
                  ),
                  body: Center(
                    child: this._buildContentView(neckStretchViewModel),
                  ),
                )));
  }

  Widget _buildContentView(NeckStretchViewModel neckStretchViewModel) {
    var headViews = this._createHeadViews(neckStretchViewModel);
    var stretchString = this._stretchState.display;
    return Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Padding(
        padding: EdgeInsets.all(2),
        child: Text(
          "Currently stretching: $stretchString",
        ),
      ),
      ...headViews.map((e) => FractionallySizedBox(
            widthFactor: .7,
            child: e,
          )),
      this._buildTrackingButton(neckStretchViewModel),
    ]);
  }

  Widget _buildHeadView(String headAssetPath, String neckAssetPath,
      AlignmentGeometry headAlignment, double roll, double angleThreshold) {
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

  List<Widget> _createHeadViews(neckStretchViewModel) {
    return [
      // Visible Widgets for the main stretch
      Visibility(
        visible: _stretchState == MeditationState.mainNeckStretch,
        child: this._buildHeadView(
            "assets/posture_tracker/Head_Front.png",
            "assets/neck_stretch/Neck_Side_Stretch.png",
            Alignment.center.add(Alignment(0, 0.3)),
            neckStretchViewModel.attitude.roll,
            4.0),
      ),
      Visibility(
        visible: _stretchState == MeditationState.mainNeckStretch,
        child: this._buildHeadView(
            "assets/posture_tracker/Head_Side.png",
            "assets/neck_stretch/Neck_Main_Stretch.png",
            Alignment.center.add(Alignment(0, 0.3)),
            -neckStretchViewModel.attitude.pitch,
            16.0),
      ),
      // Visible Widgets for the side stretch
      Visibility(
        visible: _stretchState != MeditationState.mainNeckStretch,
        child: this._buildHeadView(
            "assets/posture_tracker/Head_Front.png",
            "assets/neck_stretch/Neck_Side_Stretch.png",
            Alignment.center.add(Alignment(0, 0.3)),
            neckStretchViewModel.attitude.roll,
            4.0),
      ),
      Visibility(
        visible: _stretchState != MeditationState.mainNeckStretch,
        child: this._buildHeadView(
            "assets/posture_tracker/Head_Side.png",
            "assets/neck_stretch/Neck_Main_Stretch.png",
            Alignment.center.add(Alignment(0, 0.3)),
            -neckStretchViewModel.attitude.pitch,
            16.0),
      ),
    ];
  }

  Widget _buildTrackingButton(NeckStretchViewModel postureTrackerViewModel) {
    return Column(children: [
      ElevatedButton(
        onPressed: postureTrackerViewModel.isAvailable
            ? () {
                postureTrackerViewModel.isTracking
                    ? this._viewModel.stopTracking()
                    : this._viewModel.startTracking();
              }
            : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: !postureTrackerViewModel.isTracking
              ? Color(0xff77F2A1)
              : Color(0xfff27777),
          foregroundColor: Colors.black,
        ),
        child: postureTrackerViewModel.isTracking
            ? const Text("Stop Meditation")
            : const Text("Start Meditation"),
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
