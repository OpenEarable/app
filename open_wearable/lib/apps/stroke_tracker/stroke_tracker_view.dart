import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart' show SensorManager; // for managing sensors
import 'models/test_feedback.dart';
import 'widgets/test_feedback_panel.dart';
import 'widgets/test_progress_bubbles.dart';
import 'tests/counting_test.dart';
import 'tests/direction_test.dart';
import 'tests/touch_test.dart';
import 'tests/repetition_test.dart';
import 'tests/mouth_movement_test.dart';

class StrokeTrackerView extends StatefulWidget {
  // Managers for left/right earable sensors
  final SensorManager leftManager;
  final SensorManager rightManager;

  const StrokeTrackerView({
    Key? key,
    required this.leftManager,
    required this.rightManager,
  }) : super(key: key);
  @override
  State<StrokeTrackerView> createState() => _StrokeTrackerViewState();
}

class _StrokeTrackerViewState extends State<StrokeTrackerView> {
  final List<String> instructions = [
    "Press Start to begin tests.",
    "Please count from 0 to 10 out loud.",
    "Turn your head in the direction the sound played.",
    "Touch your left earphone with your right hand.",
    "Touch your right earphone with your left hand.",
    "Repeat: Today is a sunny day.",
    "Repeat: The quick brown fox jumps over the lazy dog.",
    "Hold a neutral expression.",
    "Now smile.",
    "Processing results...",
    "Stroke Probability: RESULTS HERE",
  ];

  final List<Duration> durations = [
    Duration(seconds: 0),
    Duration(seconds: 15),
    Duration(seconds: 8),
    Duration(seconds: 6),
    Duration(seconds: 6),
    Duration(seconds: 15),
    Duration(seconds: 15),
    Duration(seconds: 6),
    Duration(seconds: 6),
    Duration(seconds: 3),
    Duration.zero,
  ];

  final Map<int, List<int>> testRanges = {
    0: [1],
    1: [2],
    2: [3, 4],
    3: [5, 6],
    4: [7, 8],
  };

  final List<TestFeedback> testFeedbackList = [
    TestFeedback("Counting Test", Icons.format_list_numbered),
    TestFeedback("Direction Test", Icons.explore),
    TestFeedback("Touch Test", Icons.touch_app),
    TestFeedback("Repetition Test", Icons.repeat),
    TestFeedback("Mouth Movement Test", Icons.sentiment_satisfied),
  ];

  int currentIndex = 0;
  bool isRunning = false;
  bool isPaused = false;
  Timer? _timer;
  DateTime? _lastStartTime;
  Duration _elapsed = Duration.zero; 
  List<int>? _retryIndices;
  int _retryPointer = 0;

  late FlutterTts flutterTts;

  @override
  void initState() {
    super.initState();
    flutterTts = FlutterTts()
      ..setLanguage("en-US")
      ..setPitch(1.0)
      ..setSpeechRate(0.5);
  }

  Future<void> _speak(String text) async {
    await flutterTts.stop();
    await flutterTts.speak(text);
  }

  void _startSequence() {
    if (isRunning) return;
    setState(() {
      isRunning = true;
      isPaused = false;
      currentIndex = 1;
      _retryIndices = null;
      _retryPointer = 0;
      _elapsed = Duration.zero;
      _lastStartTime = DateTime.now();
    });
    _speak(instructions[currentIndex]);
    _scheduleNext();
  }

  void _scheduleNext() {
    _timer?.cancel();
    if (_retryIndices != null) {
      // … your retry logic here …
    } else {
      if (currentIndex >= instructions.length - 1) {
        setState(() => isRunning = false);
        _speak(instructions[currentIndex]);
        return;
      }
      _timer = Timer(durations[currentIndex], () {
        setState(() {
          currentIndex++;
          _elapsed = Duration.zero;
          _lastStartTime = DateTime.now();
        });
        _speak(instructions[currentIndex]);
        _scheduleNext();
      });
    }
  }

  void _pause() {
    if (_timer != null && _lastStartTime != null) {
      _elapsed += DateTime.now().difference(_lastStartTime!);
    }
    _timer?.cancel();
    flutterTts.stop();
    setState(() {
      isRunning = false;
      isPaused = true;
    });
  }

  void _resume() {
    if (!isPaused) return;
    setState(() {
      isRunning = true;
      isPaused = false;
      _lastStartTime = DateTime.now();
    });
    _speak(instructions[currentIndex]);
    _scheduleNext();
  }

  void _reset() {
    _timer?.cancel();
    flutterTts.stop();
    setState(() {
      currentIndex = 0;
      isRunning = false;
      isPaused = false;
      _elapsed = Duration.zero;
      _retryIndices = null;
    });
  }

  void _onRetry(int testKey) {
    final range = testRanges[testKey]!;
    setState(() {
      _retryIndices = range;
      _retryPointer = 0;
      currentIndex = range.first;
      isRunning = true;
      isPaused = false;
      _lastStartTime = DateTime.now();
    });
    _speak(instructions[currentIndex]);
    _scheduleNext();
  }

  Widget _buildTestWidget() {
    switch (currentIndex) {
      case 1:
        return CountingTest(onCompleted: _scheduleNext);
      case 2:
        return DirectionTestPlaceholder(onCompleted: _scheduleNext);
      case 3:
          return TouchTest(
            leftManager: widget.leftManager,
            rightManager: widget.rightManager,
            onCompleted: _scheduleNext,
          );
        case 4:
          return TouchTest(
            leftManager: widget.leftManager,
            rightManager: widget.rightManager,
            onCompleted: _scheduleNext,
          );
        case 5:
      case 6:
        return RepetitionTest(onCompleted: _scheduleNext);
      case 7:
      case 8:
        return MouthMovementTest(onCompleted: _scheduleNext);
      default:
        return Center(
          child: Text(instructions[currentIndex], textAlign: TextAlign.center),
        );
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    flutterTts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isFinished = currentIndex == instructions.length - 1;

    return Scaffold(
      appBar: AppBar(title: const Text("Stroke Tracker")),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Expanded(
                flex: 2,
                child: TestFeedbackPanel(
                  feedbackList: testFeedbackList,
                  onRetry: _onRetry,
                ),
              ),
              const Divider(),
              Expanded(
                flex: 1,
                child: Column(
                  children: [
                    Expanded(child: _buildTestWidget()),
                    const SizedBox(height: 12),
                    if (!isRunning && !isFinished)
                      ElevatedButton.icon(
                        icon: Icon(isPaused ? Icons.play_arrow : Icons.play_arrow),
                        label: Text(isPaused ? "Resume" : "Start"),
                        onPressed: isPaused ? _resume : _startSequence,
                      ),
                    if (isRunning)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Text("Running..."),
                          SizedBox(width: 8),
                          SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),),
                        ],
                      ),
                    if (isFinished && !isRunning)
                      ElevatedButton.icon(
                        icon: const Icon(Icons.restart_alt),
                        label: const Text("Restart"),
                        onPressed: _reset,
                      ),
                    const SizedBox(height: 12),
                    TestProgressBubbles(
                      currentIndex: currentIndex,
                      testRanges: testRanges,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.pause),
                  label: const Text("Pause"),
                  onPressed: isRunning ? _pause : null,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.orangeAccent),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.skip_next),
                  label: const Text("Skip to End"),
                  onPressed: isRunning
                      ? () => setState(() => currentIndex = instructions.length - 1)
                      : null,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
