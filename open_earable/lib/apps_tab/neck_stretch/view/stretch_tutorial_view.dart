import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:youtube_player_flutter/youtube_player_flutter.dart';

import 'package:open_earable/apps_tab/neck_stretch/model/stretch_colors.dart';
import 'package:open_earable/apps_tab/neck_stretch/view/stretch_tracker_view.dart';
import 'package:open_earable/apps_tab/neck_stretch/view_model/stretch_view_model.dart';
import 'package:open_earable/apps_tab/neck_stretch/model/stretch_state.dart';
import 'package:open_earable/apps_tab/neck_stretch/view/stretch_settings_view.dart';

class StretchTutorialView extends StatefulWidget {
  final StretchViewModel _viewModel;

  const StretchTutorialView(this._viewModel, {super.key});

  @override
  State<StretchTutorialView> createState() => _StretchTutorialViewState();
}

class _StretchTutorialViewState extends State<StretchTutorialView> {
  late final StretchViewModel _viewModel;
  final YoutubePlayerController _ytController = YoutubePlayerController(
    initialVideoId: "H5h54Q0wpps",
    flags: YoutubePlayerFlags(mute: false, autoPlay: false),
  );

  @override
  void initState() {
    super.initState();
    _viewModel = widget._viewModel;
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<StretchViewModel>.value(
      value: _viewModel,
      builder: (context, child) => Consumer<StretchViewModel>(
        builder: (context, neckStretchViewModel, child) => Scaffold(
          backgroundColor: Theme.of(context).colorScheme.surface,
          appBar: AppBar(
            /// Override leading back arrow button to stop tracking if
            /// user stopped stretching
            leading: IconButton(
              icon: Icon(Icons.arrow_back),
              onPressed: () {
                if (neckStretchViewModel.isTracking) {
                  neckStretchViewModel.stopTracking();
                }
                Navigator.of(context).pop();
              },
            ),
            title: const Text("Guided Neck Stretch"),
            actions: [
              IconButton(
                onPressed: (_viewModel.stretchState ==
                            NeckStretchState.noStretch ||
                        _viewModel.stretchState ==
                            NeckStretchState.doneStretching)
                    ? () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => SettingsView(_viewModel),
                          ),
                        )
                    : null,
                icon: Icon(Icons.settings),
              ),
            ],
          ),
          body: Center(
            child: SingleChildScrollView(
              child: _buildContentView(neckStretchViewModel),
            ),
          ),
        ),
      ),
    );
  }

  /// Build the actual content you can see in the app
  Widget _buildContentView(StretchViewModel neckStretchViewModel) {
    return Column(
      children: <Widget>[
        /// Card with a YoutubePlayer containing a Video explaining all the stretches
        Card(
          color: Theme.of(context).colorScheme.primary,
          child: Column(
            children: [
              ListTile(
                title: Text("Video showing the different stretches"),
              ),
              YoutubePlayer(
                controller: _ytController,
                bottomActions: [
                  CurrentPosition(),
                  ProgressBar(
                    isExpanded: true,
                  ),
                ],
              ),
            ],
          ),
        ),

        /// Card used to explain the tracking colors
        Card(
          color: Theme.of(context).colorScheme.primary,
          child: Column(
            children: [
              ListTile(
                title: Text("Explaining the Tracking Colors"),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, 0),
                child: RichText(
                  textAlign: TextAlign.justify,
                  text: TextSpan(
                    children: <TextSpan>[
                      TextSpan(
                        text:
                            'With these widgets you can you can track your current head positioning. Depending on the color of the area you are supposed to be inside of it or outside of it.\n',
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(24, 0, 24, 0),
                child: RichText(
                  textAlign: TextAlign.justify,
                  text: TextSpan(
                    children: <TextSpan>[
                      TextSpan(
                        text: 'Green: ',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: goodStretchIndicatorColor,
                        ),
                      ),
                      TextSpan(
                        text: 'Try to keep your head within this area\n\n',
                      ),
                      TextSpan(
                        text: 'Dark Grey: ',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: wrongAreaIndicator,
                        ),
                      ),
                      TextSpan(
                        text:
                            'You are currently stretching, try to gently move your head into the ',
                      ),
                      TextSpan(
                        text: 'light grey ',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: rightAreaIndicator,
                        ),
                      ),
                      TextSpan(
                        text: 'area\n\n',
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        /// Example of the Tracker in Main Neck Stretch state
        Card(
          color: Theme.of(context).colorScheme.primary,
          child: Column(
            children: [
              ListTile(
                title: Text('Example: Tracker for Main Neck Stretch'),
                titleAlignment: ListTileTitleAlignment.center,
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(0, 0, 0, 16),
                child: Column(
                  children: <Widget>[
                    RichText(
                      textAlign: TextAlign.center,
                      text: TextSpan(
                        children: <TextSpan>[
                          TextSpan(
                            text: "Currently Stretching: \n",
                          ),
                          TextSpan(
                            text: NeckStretchState.mainNeckStretch.display,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: stretchedAreaColor,
                            ),
                          ),
                        ],
                      ),
                    ),

                    /// The head views used for stretching
                    FractionallySizedBox(
                      widthFactor: 0.6,
                      child: StretchTrackerView.buildHeadView(
                        NeckStretchState.mainNeckStretch.assetPathHeadFront,
                        NeckStretchState.mainNeckStretch.assetPathNeckFront,
                        Alignment.center.add(Alignment(0, 0.3)),
                        neckStretchViewModel.attitude.roll,
                        30,
                        NeckStretchState.mainNeckStretch,
                      ),
                    ),
                    FractionallySizedBox(
                      widthFactor: 0.6,
                      child: StretchTrackerView.buildHeadView(
                        NeckStretchState.mainNeckStretch.assetPathHeadSide,
                        NeckStretchState.mainNeckStretch.assetPathNeckSide,
                        Alignment.center.add(Alignment(0, 0.3)),
                        -neckStretchViewModel.attitude.pitch,
                        50,
                        NeckStretchState.mainNeckStretch,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, 0),
                child: RichText(
                  textAlign: TextAlign.justify,
                  text: TextSpan(
                    children: <TextSpan>[
                      TextSpan(
                        text:
                            'The area of your neck that is currently being stretched will be colored in ',
                      ),
                      TextSpan(
                        text: 'blue',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: stretchedAreaColor,
                        ),
                      ),
                      TextSpan(
                        text:
                            '.\n\nWhenever an exercise is over a sound will play to inform you that you are done with the current stretch. Afterwards you will have a small time to prepare for the next stretch (normally 5 seconds). The button will always keep you up to date with your time limits, and above the tracker is also a text telling you what exactly you are currently stretching.\n\n',
                      ),
                      TextSpan(
                        text:
                            'You can use the button bellow to have a preview of how the tracking will look.\n',
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        /// Card explaining the stretching button
        Card(
          color: Theme.of(context).colorScheme.primary,
          child: Column(
            children: [
              ListTile(
                title: Text("Explaining the Stretching Button"),
              ),

              /// Explainer text for the button
              Padding(
                padding: EdgeInsets.all(16),
                child: RichText(
                  textAlign: TextAlign.justify,
                  text: TextSpan(
                    children: <TextSpan>[
                      TextSpan(
                        text:
                            'This button is used to start the meditation or to stop it preemptively. Depending on the color you can tell the current state:\n',
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(24, 0, 24, 0),
                child: RichText(
                  textAlign: TextAlign.justify,
                  text: TextSpan(
                    children: <TextSpan>[
                      TextSpan(
                        text: 'Green: ',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: startButtonColor,
                        ),
                      ),
                      TextSpan(
                        text: 'You are currently not meditating\n\n',
                      ),
                      TextSpan(
                        text: 'Red: ',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: stopButtonColor,
                        ),
                      ),
                      TextSpan(
                        text:
                            'You are currently meditating, the button will display the remaining time\n\n',
                      ),
                      TextSpan(
                        text: 'Yellow: ',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: restingButtonColor,
                        ),
                      ),
                      TextSpan(
                        text:
                            'You are currently having a break between the stretches. The button displays the remaining time.\n\n',
                      ),
                    ],
                  ),
                ),
              ),

              _buildMeditationButton(neckStretchViewModel),
            ],
          ),
        ),
      ],
    );
  }

  // Creates the Button used to start the stretch exercise
  Widget _buildMeditationButton(StretchViewModel neckStretchViewModel) {
    return Padding(
      padding: EdgeInsets.all(5),
      child: Column(
        children: [
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
                  ? startButtonColor
                  : stopButtonColor,
              foregroundColor: Colors.black,
            ),
            child: neckStretchViewModel.isTracking
                ? const Text("Stop Stretching")
                : const Text("Start Stretching"),
          ),
        ],
      ),
    );
  }
}
