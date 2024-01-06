import 'package:flutter/material.dart';
import 'package:open_earable/apps/neck_stretcher/view/settings_front_back_view.dart';
import 'package:open_earable_flutter/src/open_earable_flutter.dart';
import 'package:open_earable/apps/neck_stretcher/model/attitude_tracker.dart';
import 'package:provider/provider.dart';

import '../model/front_back_stretcher.dart';
import '../view_model/device_view_model.dart';
import 'package:open_earable/apps/neck_stretcher/view/posture_roll_stretch_view.dart';

/// widget for front back stretcher exercise
class FrontBackStretcherView extends StatefulWidget {
  final AttitudeTracker _tracker;
  final OpenEarable _openEarable;

  FrontBackStretcherView(this._tracker, this._openEarable);

  @override
  State<FrontBackStretcherView> createState() => _FrontBackStretcherViewState();
}

/// state for view
class _FrontBackStretcherViewState extends State<FrontBackStretcherView> {
  late final DeviceViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    this._viewModel = DeviceViewModel(widget._tracker,
        FrontBackStretcher(widget._openEarable));
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<DeviceViewModel>.value(
        value: _viewModel,
        builder: (context, child) => Consumer<DeviceViewModel>(
            builder: (context, stretcherViewModel, child) => Scaffold(
                  appBar: AppBar(
                    title: const Text("Neck Stretcher"),
                    actions: [
                      IconButton(
                          onPressed: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                  builder: (context) =>
                                      FrontBackSettingsView(this._viewModel))),
                          icon: Icon(Icons.settings))
                    ],
                  ),
                  body: Center(
                    child: this._buildContentView(stretcherViewModel),
                  ),
                )));
  }

  Widget _buildContentView(DeviceViewModel stretcherViewModel) {
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

  /// taken from example
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

  /// taken from example
  List<Widget> _createHeadViews(stretcherViewModel) {
    return [
      this._buildHeadView(
          "assets/posture_tracker/Head_Side.png",
          "assets/posture_tracker/Neck_Side.png",
          Alignment.center.add(Alignment(0, 0.3)),
          -stretcherViewModel.attitude.pitch,
          stretcherViewModel.stretcherSettings.pitchAngleForward.toDouble()),
    ];
  }

  /// stretch instructions
  Widget _buildInstruction(DeviceViewModel deviceViewModel) {
    String instruction = deviceViewModel.instructionText;
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

  /// countdown display
  Widget _buildCountdown(DeviceViewModel deviceViewModel) {
    int seconds = deviceViewModel.seconds;
    return SizedBox(
      height: 50,
      child: Visibility(
        visible: deviceViewModel.isTracking && deviceViewModel.isStretching,
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

  /// stop and start tracking button
  Widget _buildTrackingButton(DeviceViewModel deviceViewModel) {
    return Column(children: [
      ElevatedButton(
        /// start or stop tracking based on if the model was tracking or not
        onPressed: deviceViewModel.isAvailable
            ? () {
                deviceViewModel.isTracking
                    ? this._viewModel.stopTracking()
                    : this._viewModel.startTracking();
              }
            : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: !deviceViewModel.isTracking
              ? Color(0xff77F2A1)
              : Color(0xfff27777),
          foregroundColor: Colors.black,
        ),
        child: deviceViewModel.isTracking
            ? const Text("Stop Stretching")
            : const Text("Start Stretching"),
      ),
      Visibility(
        visible: !deviceViewModel.isAvailable,
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

  /// button that calibrates the earable
  Widget _buildCalibrateButton(DeviceViewModel deviceViewModel) {
    return Visibility(
      visible: deviceViewModel.isAvailable && !deviceViewModel.isStretching,
      child: ElevatedButton(
          onPressed: () {
            deviceViewModel.calibrate();
          },
          style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black54, foregroundColor: Colors.white),
          child: Text("Calibrate")),
    );
  }
}
