import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:open_earable/apps/posture_tracker/model/attitude_tracker.dart';
import 'package:open_earable/apps/neck_meditation/view/stretch_roll_view.dart';
import 'package:open_earable/apps/neck_meditation/view_model/stretch_view_model.dart';
import 'package:open_earable/apps/neck_meditation/model/stretch_state.dart';
import 'package:open_earable/apps/neck_meditation/view/stretch_settings_view.dart';

import 'package:open_earable_flutter/src/open_earable_flutter.dart';

class StretchTutorialView extends StatefulWidget {
  final AttitudeTracker _tracker;
  final OpenEarable _openEarable;

  StretchTutorialView(this._tracker, this._openEarable);

  @override
  State<StretchTutorialView> createState() => _StretchTutorialViewState();
}

class _StretchTutorialViewState extends State<StretchTutorialView> {
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
        builder: (context, child) => Consumer<StretchViewModel>(
            builder: (context, neckStretchViewModel, child) => Scaffold(
                  appBar: AppBar(
                    title: const Text("Guided Neck Relaxation"),
                    actions: [
                      IconButton(
                          onPressed: (this._viewModel.meditationState ==
                                      NeckStretchState.noStretch ||
                                  this._viewModel.meditationState ==
                                      NeckStretchState.doneStretching)
                              ? () => Navigator.of(context).push(
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

  /// Build the actual content you can see in the app
  Widget _buildContentView(StretchViewModel neckStretchViewModel) {
    return Column(
      children: <Widget>[
        Padding(
          padding: EdgeInsets.all(5),
          child: Padding(
            padding: EdgeInsets.fromLTRB(8, 8, 8, 8),
            child: RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                children: <TextSpan>[
                  TextSpan(
                      text:
                          'Here the body part, which is currently being stretched, will be displayed.')
                ],
              ),
            ),
          ),
        ),

        Padding(
          padding: EdgeInsets.all(8),
          child: RichText(
            textAlign: TextAlign.left,
            text: TextSpan(
                text:
                    "Here both your Front and Side view of your head will be displayed. The blue part shows you what part of your neck should currently be stretched. When starting to stretch you should gently tilt your head towards the instructed direction (the gray area of the circle). Once you feel your neck stretch stop and hold the position till the sound occurs. Then you can start stretching the next part of your neck."),
          ),
        ),

        FractionallySizedBox(
          widthFactor: 0.6,
          child: this._buildHeadView(
              NeckStretchState.mainNeckStretch.assetPathNeckSide,
              NeckStretchState.mainNeckStretch.assetPathHeadSide,
              Alignment.center.add(Alignment(0, 0.3)),
              neckStretchViewModel.attitude.pitch,
              30,
              NeckStretchState.noStretch),
        ),

        /// Used to place the Meditation-Button always at the bottom
        Expanded(
          child: Container(),
        ),

        /// Explainer text for the button
        Padding(
          padding: EdgeInsets.all(8),
          child: RichText(
            textAlign: TextAlign.left,
            text: TextSpan(
              children: <TextSpan>[
                TextSpan(
                    text:
                        'This button will be used to start and to preemptively stop the meditation. If you are currently meditating the button will show you the remaining time for the current stretch.'),
                TextSpan(text: ''),
              ],
            ),
          ),
        ),
        this._buildMeditationButton(neckStretchViewModel),
      ],
    );
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
                      ? neckStretchViewModel.stopTracking()
                      : neckStretchViewModel.startTracking();
                }
              : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: !neckStretchViewModel.isTracking
                ? Color(0xff77F2A1)
                : Color(0xfff27777),
            foregroundColor: Colors.black,
          ),
          child: neckStretchViewModel.isTracking
              ? const Text("Stop Meditation")
              : const Text("Start Meditation"),
        ),
      ]),
    );
  }

  /// Builds the actual head views using the StretchRollView
  Widget _buildHeadView(
      String headAssetPath,
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
