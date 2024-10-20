import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:open_earable/apps_tab/neck_stretch/view/stretch_roll_view.dart';
import 'package:open_earable/apps_tab/neck_stretch/view_model/stretch_view_model.dart';
import 'package:open_earable/apps_tab/neck_stretch/model/stretch_state.dart';
import 'package:open_earable/apps_tab/neck_stretch/view/stretch_settings_view.dart';
import 'package:open_earable/apps_tab/neck_stretch/model/stretch_colors.dart';

class StretchTrackerView extends StatefulWidget {
  final StretchViewModel _viewModel;

  const StretchTrackerView(this._viewModel, {super.key});

  @override
  State<StretchTrackerView> createState() => _StretchTrackerViewState();

  /// Builds the actual head views using the StretchRollView
  static Widget buildHeadView(
    String headAssetPath,
    String neckAssetPath,
    AlignmentGeometry headAlignment,
    double roll,
    double angleThreshold,
    NeckStretchState state,
  ) {
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

class _StretchTrackerViewState extends State<StretchTrackerView> {
  late final StretchViewModel _viewModel;

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
                  _stopStretching();
                }
                Navigator.of(context).pop();
              },
            ),
            title: const Text("Guided Neck Stretch"),
            actions: [
              IconButton(
                /// Settings button, only active when not stretching
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
            child: _buildContentView(neckStretchViewModel),
          ),
        ),
      ),
    );
  }

  /// Used to start stretching via the button
  void _startStretching() {
    _viewModel.neckStretch.startStretching();
  }

  /// Used to stop stretching via the button
  void _stopStretching() {
    _viewModel.neckStretch.stopStretching();
  }

  /// Returns the TextSpan representing the Status Text at the top of the app
  TextSpan _getStatusText() {
    if (!_viewModel.isAvailable) {
      return TextSpan(
        text: "Connect an Earable to start Stretching!",
        style: TextStyle(
          color: Colors.red,
          fontSize: 12,
        ),
      );
    }

    if (_viewModel.stretchState == NeckStretchState.noStretch) {
      return TextSpan(text: "Click the Button below\n to start Stretching!");
    }

    if (_viewModel.stretchState == NeckStretchState.doneStretching) {
      return TextSpan(text: "You are done stretching,\n good job!");
    }

    return TextSpan(
      children: <TextSpan>[
        TextSpan(
          text: "Currently Stretching: \n",
        ),
        TextSpan(
          text: _viewModel.stretchState.display,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 15,
            color: stretchedAreaColor,
          ),
        ),
      ],
    );
  }

  /// Returns the button text displayed within the button. Used to also display
  /// the remaining time of each phase
  Text _getButtonText() {
    if (!_viewModel.isTracking) return Text('Start Stretching');

    if (_viewModel.stretchState == NeckStretchState.doneStretching ||
        _viewModel.stretchState == NeckStretchState.noStretch) {
      return Text('Stop Stretching');
    }

    return Text(_viewModel.restDuration.toString().substring(2, 7));
  }

  /// Build the actual content you can see in the app
  Widget _buildContentView(StretchViewModel neckStretchViewModel) {
    var headViews = _createHeadViews(neckStretchViewModel);
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.all(5),
          child: SizedBox(
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
          (e) => FractionallySizedBox(
            widthFactor: .6,
            child: e,
          ),
        ),
        _buildStretchButton(neckStretchViewModel),
      ],
    );
  }

  /// Gets the correct background color for the stretching button
  Color _getBackgroundColor(StretchViewModel neckStretchViewModel) {
    if (neckStretchViewModel.isResting) {
      return restingButtonColor;
    }

    return !neckStretchViewModel.isTracking
        ? startButtonColor
        : stopButtonColor;
  }

  // Creates the Button used to start the stretch exercise
  Widget _buildStretchButton(StretchViewModel neckStretchViewModel) {
    return Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          ElevatedButton(
            onPressed: neckStretchViewModel.isAvailable
                ? () {
                    neckStretchViewModel.isTracking
                        ? _stopStretching()
                        : _startStretching();
                  }
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: _getBackgroundColor(neckStretchViewModel),
              foregroundColor: Colors.black,
            ),
            child: _getButtonText(),
          ),
        ],
      ),
    );
  }

  /// Creates the Head Views that display depending on the stretch state.
  List<Widget> _createHeadViews(StretchViewModel neckStretchViewModel) {
    return [
      // Visible Head-Displays when not stretching
      _buildStretchViews(
        NeckStretchState.noStretch,
        neckStretchViewModel,
        0.0,
        0.0,
      ),

      /// Visible Widgets for the main stretch
      _buildStretchViews(
        NeckStretchState.mainNeckStretch,
        neckStretchViewModel,
        7.0,
        (neckStretchViewModel.stretchSettings.forwardStretchAngle % 180),
      ),

      /// Visible Widgets for the right stretch
      _buildStretchViews(
        NeckStretchState.rightNeckStretch,
        neckStretchViewModel,
        (neckStretchViewModel.stretchSettings.sideStretchAngle % 180),
        15.0,
      ),

      /// Visible Widgets for the left stretch
      _buildStretchViews(
        NeckStretchState.leftNeckStretch,
        neckStretchViewModel,
        (neckStretchViewModel.stretchSettings.sideStretchAngle % 180),
        15.0,
      ),
    ];
  }

  /// Builds the head tracking/stretch view parts for a certain state and thresholds
  Visibility _buildStretchViews(
    NeckStretchState state,
    StretchViewModel neckStretchViewModel,
    double frontThreshold,
    double sideThreshold,
  ) {
    bool visibility;
    if (state == NeckStretchState.noStretch) {
      visibility = _viewModel.stretchState == NeckStretchState.noStretch ||
          _viewModel.stretchState == NeckStretchState.doneStretching;
    } else {
      visibility = _viewModel.stretchState == state;
    }

    return Visibility(
      visible: visibility,
      child: Column(
        children: <Widget>[
          StretchTrackerView.buildHeadView(
            state.assetPathHeadFront,
            state.assetPathNeckFront,
            Alignment.center.add(Alignment(0, 0.3)),
            neckStretchViewModel.attitude.roll,
            frontThreshold,
            state,
          ),
          StretchTrackerView.buildHeadView(
            state.assetPathHeadSide,
            state.assetPathNeckSide,
            Alignment.center.add(Alignment(0, 0.3)),
            -neckStretchViewModel.attitude.pitch,
            sideThreshold,
            state,
          ),
        ],
      ),
    );
  }
}
