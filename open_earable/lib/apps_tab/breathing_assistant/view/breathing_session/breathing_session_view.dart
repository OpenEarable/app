import 'dart:async';
import 'package:flutter/material.dart';
import '../../model/breathing_session_model.dart';
import 'breathing_session_widgets.dart';

/// A [BreathingSessionView] widget that manages the breathing session process,
/// including animations, phases, posture feedback, and session completion.
///
/// This widget adapts to both portrait and landscape orientations, and it dynamically
/// updates based on the user's progress in the breathing session
///
/// ### Features:
/// - Countdown before starting the session.
/// - Breathing phase animations with progress indicators.
/// - Posture feedback display.
/// - Completion view at the end of the session.
class BreathingSessionView extends StatefulWidget {
  /// The session model containing logic and data for the breathing exercise.
  final BreathingSessionModel model;

  /// The user's position mode: either 'sitting' or 'lying'.
  final String positionMode;

  BreathingSessionView(this.model, {required this.positionMode});

  @override
  _BreathingSessionViewState createState() => _BreathingSessionViewState();
}

class _BreathingSessionViewState extends State<BreathingSessionView>
    with TickerProviderStateMixin {
  late AnimationController _progressController;
  late Animation<double> _progressAnimation;
  late AnimationController _sizeController;
  late Animation<double> _sizeAnimation;
  late final String positionMode;

  String _currentPhase = 'Inhale';
  int _currentPhaseDuration = 4;
  bool _isSessionComplete = false;
  bool _isCountdownActive = true;
  int _countdown = 3;
  String _postureFeedback = '';

  @override
  void initState() {
    super.initState();
    positionMode = widget.positionMode;

    // Set the position mode for the sensor tracker.
    widget.model.sensorTracker?.setMode(positionMode);

    widget.model.postureFeedbackStream.listen((feedback) {
      setState(() {
        _postureFeedback = feedback;
      });
    });

    _startCountdown();

    _progressController = AnimationController(
      vsync: this,
      duration: Duration(seconds: _currentPhaseDuration),
    );
    _progressAnimation =
        Tween<double>(begin: 0, end: 1).animate(_progressController);

    _sizeController = AnimationController(
      vsync: this,
      duration: Duration(seconds: _currentPhaseDuration),
    );
    _sizeAnimation =
        Tween<double>(begin: 150, end: 200).animate(_sizeController);

    // Listen for breathing phase updates and handle animations.
    widget.model.breathingPhaseStream.listen((phase) {
      setState(() {
        _currentPhase = phase;
        _currentPhaseDuration = widget.model.phases
            .firstWhere((p) => p['phase'] == phase)['duration'] as int;

        _progressController.duration =
            Duration(seconds: _currentPhaseDuration);
        _progressController.reset();
        _progressController.forward();

        if (phase == 'Inhale') {
          _sizeAnimation =
              Tween<double>(begin: 150, end: 200).animate(_sizeController);
        } else if (phase == 'Hold') {
          _sizeAnimation =
              Tween<double>(begin: 200, end: 200).animate(_sizeController);
        } else if (phase == 'Exhale') {
          _sizeAnimation =
              Tween<double>(begin: 200, end: 150).animate(_sizeController);
        }
        _sizeController.reset();
        _sizeController.forward();
      });
    });

    // Listen for session completion updates.
    widget.model.breathingPhaseStream.listen((phase) {
      if (phase == 'Completed') {
        setState(() {
          _isSessionComplete = true;
        });
      }
    });
  }

  /// Starts the countdown before the session begins.
  void _startCountdown() {
    Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdown > 1) {
        setState(() {
          _countdown--;
        });
      } else {
        timer.cancel();
        setState(() {
          _isCountdownActive = false;
          widget.model.startSession();
          _progressController.forward();
          _sizeController.forward();
        });
      }
    });
  }

  @override
  void dispose() {
    // Dispose animation controllers and stop the session.
    _progressController.dispose();
    _sizeController.dispose();
    widget.model.stopSession();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Set the background color based on night mode.
    final backgroundColor = widget.model.isNightMode
        ? Colors.grey[850]
        : const Color.fromARGB(255, 116, 165, 250);

    // Check if the device is in landscape orientation.
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            widget.model.stopSession();
            Navigator.pop(context);
          },
        ),
      ),
      body: isLandscape
          ? Row(
              children: [
                // Posture feedback on the left in landscape mode.
                Expanded(
                  flex: 1,
                  child: PostureFeedbackWidget(
                    isNightMode: widget.model.isNightMode,
                    feedback: _postureFeedback,
                  ),
                ),
                // Main content on the right in landscape mode.
                Expanded(
                  flex: 2,
                  child: _buildContent(),
                ),
              ],
            )
          : Column(
              children: [
                // Posture feedback on the top in portrait mode.
                PostureFeedbackWidget(
                  isNightMode: widget.model.isNightMode,
                  feedback: _postureFeedback,
                ),
                // Main content below in portrait mode.
                Expanded(child: _buildContent()),
              ],
            ),
    );
  }

  /// Builds the dynamic content for the breathing session view.
  ///
  /// This includes:
  /// - The countdown view.
  /// - The breathing animation view.
  /// - The completion view.
  Widget _buildContent() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 500),
      child: _isSessionComplete
          ? CompletionWidget(
              onGoBack: () {
                Navigator.pop(context);
              },
            )
          : _isCountdownActive
              ? CountdownWidget(countdown: _countdown)
              : BreathingWidget(
                  progressAnimation: _progressAnimation,
                  sizeAnimation: _sizeAnimation,
                  currentPhase: _currentPhase,
                  isNightMode: widget.model.isNightMode,
                  onEndSession: () {
                    widget.model.stopSession();
                    Navigator.pop(context);
                  },
                ),
    );
  }
}
