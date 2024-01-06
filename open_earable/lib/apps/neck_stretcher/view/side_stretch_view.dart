import 'package:flutter/material.dart';

import 'package:open_earable/apps/neck_stretcher/view_model/stretcher_view_model.dart';
import 'package:open_earable/apps/neck_stretcher/model/attitude_tracker.dart';
import 'package:open_earable/apps/neck_stretcher/model/side_stretcher.dart';
import 'package:open_earable/apps/neck_stretcher/view/posture_roll_stretch_view.dart';
import 'package:open_earable/apps/neck_stretcher/view/settings_side_view.dart';
import 'package:provider/provider.dart';

import 'package:open_earable_flutter/src/open_earable_flutter.dart';

/// widget for side to side stretching exercise
class SideStretcherView extends StatefulWidget {
  final AttitudeTracker _tracker;
  final OpenEarable _openEarable;

  SideStretcherView(this._tracker, this._openEarable);

  @override
  State<SideStretcherView> createState() => _SideStretcherViewState();
}

class _SideStretcherViewState extends State<SideStretcherView> {
  late final StretcherViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    this._viewModel =
        StretcherViewModel(widget._tracker, SideStretcher(widget._openEarable));
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<StretcherViewModel>.value(
        value: _viewModel,
        builder: (context, child) => Consumer<StretcherViewModel>(
            builder: (context, postureStretcherViewModel, child) => Scaffold(
                  appBar: AppBar(
                    title: const Text("Neck Stretcher"),
                    actions: [
                      IconButton(
                          onPressed: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                  builder: (context) =>
                                      SideSettingsView(this._viewModel))),
                          icon: Icon(Icons.settings)),
                    ],
                  ),
                  body: Center(
                    child: this._buildContentView(postureStretcherViewModel),
                  ),
                )));
  }

  /// organizes widget tree
  Widget _buildContentView(StretcherViewModel stretcherViewModel) {
    var headViews = this._createHeadViews(stretcherViewModel);
    return Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      this._buildInstruction(stretcherViewModel),
      this._buildCountdown(stretcherViewModel),
      ...headViews.map((e) => FractionallySizedBox(
            widthFactor: .7,
            child: e,
          )),
      this._buildTrackingButton(stretcherViewModel),
      this._buildCalibrateButton(stretcherViewModel),
    ]);
  }

  /// heads for stretching view
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

  List<Widget> _createHeadViews(stretcherViewModel) {
    return [
      this._buildHeadView(
          "assets/posture_tracker/Head_Front.png",
          "assets/posture_tracker/Neck_Front.png",
          Alignment.center.add(Alignment(0, 0.3)),
          stretcherViewModel.attitude.roll,
          stretcherViewModel.stretcherSettings.rollAngleRight.toDouble()),
    ];
  }

  /// create tracking button based on whether stretching is active
  Widget _buildTrackingButton(StretcherViewModel stretcherViewModel) {
    return Column(children: [
      ElevatedButton(
        onPressed: stretcherViewModel.isAvailable
            ? () {
                stretcherViewModel.isTracking
                    ? this._viewModel.stopTracking()
                    : this._viewModel.startTracking();
              }
            : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: !stretcherViewModel.isTracking
              ? Color(0xff77F2A1)
              : Color(0xfff27777),
          foregroundColor: Colors.black,
        ),
        child: stretcherViewModel.isTracking
            ? const Text("Stop Stretching")
            : const Text("Start Stretching"),
      ),
      Visibility(
        visible: !stretcherViewModel.isAvailable,
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

  /// button that calibrates earable when pressed
  Widget _buildCalibrateButton(StretcherViewModel stretcherViewModel) {
    return Visibility(
      visible:
          stretcherViewModel.isAvailable && !stretcherViewModel.isStretching,
      child: ElevatedButton(
          onPressed: () {
            this._viewModel.calibrate();
          },
          style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black54, foregroundColor: Colors.white),
          child: Text("Calibrate")),
    );
  }

  /// instruction from view model
  Widget _buildInstruction(StretcherViewModel stretcherViewModel) {
    String instruction = stretcherViewModel.instructionText;
    return SizedBox(
      height: 50,
      child: Text(
        "$instruction",
        style: TextStyle(
          fontSize: 20.0,
          fontWeight: FontWeight.bold,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  /// displays countdown for when to stop stretching
  Widget _buildCountdown(StretcherViewModel stretcherViewModel) {
    int seconds = stretcherViewModel.seconds;
    return SizedBox(
      height: 50,
      child: Visibility(
        visible:
            stretcherViewModel.isTracking && stretcherViewModel.isStretching,
        child: Text(
          '$seconds seconds left.',
          style: TextStyle(
            fontSize: 20.0,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
