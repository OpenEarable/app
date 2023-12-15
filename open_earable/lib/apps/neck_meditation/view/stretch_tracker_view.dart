import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:open_earable/apps/posture_tracker/model/attitude_tracker.dart';
import 'package:open_earable/apps/neck_meditation/view/stretch_roll_view.dart';
import 'package:open_earable/apps/neck_meditation/view_model/stretch_view_model.dart';
import 'package:open_earable/apps/neck_meditation/model/stretch_state.dart';
import 'package:open_earable/apps/neck_meditation/view/stretch_settings_view.dart';

import 'package:open_earable_flutter/src/open_earable_flutter.dart';

class StretchTrackerView extends StatefulWidget {
  final AttitudeTracker _tracker;
  final OpenEarable _openEarable;

  StretchTrackerView(this._tracker, this._openEarable);

  @override
  State<StretchTrackerView> createState() => _StretchTrackerViewState();
}

class _StretchTrackerViewState extends State<StretchTrackerView> {
  late final StretchViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    this._viewModel = StretchViewModel(widget._tracker, widget._openEarable);
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<StretchViewModel>.value(
        value: _viewModel,
        builder: (context, child) =>
            Consumer<StretchViewModel>(
                builder: (context, neckStretchViewModel, child) =>
                    Scaffold(
                      appBar: AppBar(
                        title: const Text("Guided Neck Relaxation"),
                        actions: [
                          IconButton(
                              onPressed: (this._viewModel.meditationState ==
                                  NeckStretchState.noStretch ||
                                  this._viewModel.meditationState ==
                                      NeckStretchState.doneStretching)
                                  ? () =>
                                  Navigator.of(context).push(
                                      MaterialPageRoute(
                                          builder: (context) =>
                                              SettingsView(this._viewModel)))
                                  : null,
                              icon: Icon(Icons.settings)),
                        ],
                      ),
                      body: Center(
                        child: this._buildContentView(neckStretchViewModel),
                      ),
                    )));
  }

  /// Used to start the meditation via the button
  void _startMeditation() {
    this._viewModel.meditation.startMeditation();
  }

  /// Used to stop the meditation via the button
  void _stopMeditation() {
    this._viewModel.meditation.stopMeditation();
  }

  TextSpan _getStatusText() {
    if (!_viewModel.isAvailable)
      return TextSpan(
        text: "Connect an Earable to start Stretching!",
        style: TextStyle(
          color: Colors.red,
          fontSize: 12,
        ),
      );

    if (_viewModel.meditationState == NeckStretchState.noStretch ||
        _viewModel.meditationState == NeckStretchState.doneStretching)
      return TextSpan(text: "Click the Button below\n to start Meditating!");

    return TextSpan(children: <TextSpan>[
      TextSpan(
        text: "Currently Stretching: \n",
      ),
      TextSpan(
        text: this._viewModel.meditationState.display,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 15,
          color: Color.fromARGB(255, 0, 186, 255),
        ),
      )
    ]);
  }

  Text _getButtonText() {
    if (!_viewModel.isTracking) return Text('Start Meditation');

    if (_viewModel.meditationState == NeckStretchState.doneStretching ||
        _viewModel.meditationState == NeckStretchState.noStretch)
      return Text('Stop Meditation');

    return Text(_viewModel.restDuration.toString().substring(2, 7));
  }

  /// Build the actual content you can see in the app
  Widget _buildContentView(StretchViewModel neckStretchViewModel) {
    var headViews = this._createHeadViews(neckStretchViewModel);
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.all(5),
          child: Container(
            height: 40,
            child: Padding(
              padding: EdgeInsets.fromLTRB(0, 8, 0, 0),
              child: RichText(
                textAlign: TextAlign.center,
                text: _getStatusText(),
              ),
            ),
          ),
        ),

        ...headViews.map(
              (e) =>
              FractionallySizedBox(
                widthFactor: .6,
                child: e,
              ),
        ),
        // Used to place the Meditation-Button always at the bottom
        Expanded(
          child: Container(),
        ),
        this._buildMeditationButton(neckStretchViewModel),
      ],
    );
  }

  /// Gets the correct background color for the meditation button
  Color _getBackgroundColor(StretchViewModel neckStretchViewModel) {
    if (neckStretchViewModel.isResting) {
      return Color(0xffffbb3d);
    }

    return !neckStretchViewModel.isTracking ? Color(0xff77F2A1)
        : Color(0xfff27777);
  }

  // Creates the Button used to start the meditation
  Widget _buildMeditationButton(StretchViewModel neckStretchViewModel) {
    return Padding(
      padding: EdgeInsets.all(5),
      child: Column(children: [
        ElevatedButton(
          onPressed: neckStretchViewModel.isAvailable
              ? () {
            neckStretchViewModel.isTracking
                ? _stopMeditation()
                : _startMeditation();
          }
              : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: _getBackgroundColor(neckStretchViewModel),
            foregroundColor: Colors.black,
          ),
          child: _getButtonText(),
        ),
      ]),
    );
  }

  /// Creates the Head Views that display depending on the MeditationState.
  List<Widget> _createHeadViews(StretchViewModel neckStretchViewModel) {
    return [
      // Visible Head-Displays when not stretching
      _buildStretchViews(
          NeckStretchState.noStretch, neckStretchViewModel, 0.0, 0.0),

      /// Visible Widgets for the main stretch
      _buildStretchViews(
          NeckStretchState.mainNeckStretch, neckStretchViewModel, 7.0, 50.0),

      /// Visible Widgets for the right stretch
      _buildStretchViews(
          NeckStretchState.rightNeckStretch, neckStretchViewModel, 30.0, 15.0),

      /// Visible Widgets for the left stretch
      _buildStretchViews(
          NeckStretchState.leftNeckStretch, neckStretchViewModel, 30.0, 15.0),
    ];
  }

  /// Builds the head tracking/stretch view parts for a certain state and thresholds
  Visibility _buildStretchViews(NeckStretchState state,
      StretchViewModel neckStretchViewModel,
      double frontThreshold,
      double sideThreshold) {
    var visibility;
    if (state == NeckStretchState.noStretch) {
      visibility = this._viewModel.meditationState ==
          NeckStretchState.noStretch ||
          this._viewModel.meditationState == NeckStretchState.doneStretching;
    } else {
      visibility = this._viewModel.meditationState == state;
    }

    return Visibility(
        visible: visibility,
        child: Column(
          children: <Widget>[
            this._buildHeadView(
                state.assetPathHeadFront,
                state.assetPathNeckFront,
                Alignment.center.add(Alignment(0, 0.3)),
                neckStretchViewModel.attitude.roll,
                frontThreshold,
                state),
            this._buildHeadView(
                state.assetPathHeadSide,
                state.assetPathNeckSide,
                Alignment.center.add(Alignment(0, 0.3)),
                neckStretchViewModel.attitude.pitch,
                sideThreshold,
                state),
          ],
        ));
  }

  /// Builds the actual head views using the StretchRollView
  Widget _buildHeadView(String headAssetPath,
      String neckAssetPath,
      AlignmentGeometry headAlignment,
      double roll,
      double angleThreshold,
      NeckStretchState state) {
    return Padding(
      padding: const EdgeInsets.all(5),
      child: StretchRollView(
        roll: roll,
        angleThreshold: angleThreshold * 3.14 / 180,
        headAssetPath: headAssetPath,
        neckAssetPath: neckAssetPath,
        headAlignment: headAlignment,
        stretchState: state,
      ),
    );
  }
}
