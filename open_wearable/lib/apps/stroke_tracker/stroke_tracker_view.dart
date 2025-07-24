import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart';
import 'models/test_feedback.dart';
import 'widgets/test_feedback_panel.dart';
import 'widgets/test_progress_bubbles.dart';
import 'tests/counting_test.dart';
import 'tests/direction_test.dart';
import 'tests/touch_test.dart';
import 'tests/naming_test.dart';
import 'tests/repetition_test.dart';
import 'tests/mouth_movement_test.dart';


// Main view that runs the stroke test sequence
class StrokeTrackerView extends StatefulWidget {

  final Wearable leftWearable;
  final Wearable rightWearable;

  const StrokeTrackerView({super.key, required this.leftWearable, required this.rightWearable});
  @override
  State<StrokeTrackerView> createState() => _StrokeTrackerViewState();
}

class _StrokeTrackerViewState extends State<StrokeTrackerView> {
  // Instructions to be spoken aloud at each stage of the test
  final List<String> instructions = [
    "We will now begin the test. Please remain seated calmly. I will guide you step by step.", // plays immediately
    "Please count from 1 to 10 out loud.",
    "Turn your head in the direction the sound played.",
    "Press left earphone with your right hand.",
    "Press your right earphone with your left hand.",
    "Repeat: Today is a sunny day.",
    "Repeat: The quick brown fox jumps over the lazy dog.",
    "Hold a neutral expression.",
    "Now smile.",
    "Name the large gray animal that roams in Africa.",
    "Processing results...",
    "Stroke Probability: RESULTS HERE",
  ];

  // How long each test should run (if time-based)
  final List<Duration> durations = [
    Duration(seconds: 8), // Intro duration
    Duration(seconds: 15), // Counting
    Duration(seconds: 8),  // Direction
    Duration(seconds: 6),  // Touch left
    Duration(seconds: 6),  // Touch right
    Duration(seconds: 15), // Repeat phrase 1
    Duration(seconds: 15), // Repeat phrase 2
    Duration(seconds: 6),  // Neutral expression
    Duration(seconds: 6),  // Smile
    Duration(seconds: 10), // Naming test
    Duration(seconds: 3),  // Processing results
    Duration.zero,
  ];

  // Mapping test categories to their instruction index range
  final Map<int, List<int>> testRanges = {
    0: [1],        // Counting
    1: [2],        // Direction
    2: [3, 4],     // Touch
    3: [5, 6],     // Repetition
    4: [7, 8],     // Mouth Movement
    5: [9],        // Naming test
  };

late List<TestFeedback> testFeedbackList;

@override
void initState() {
  super.initState();
  flutterTts = FlutterTts()
    ..setLanguage("en-US")
    ..setPitch(1.0)
    ..setSpeechRate(0.5);

  // Populating feedbck panel
  testFeedbackList = [
    TestFeedback("Counting Test", Icons.format_list_numbered),
    TestFeedback("Direction Test", Icons.explore),
    TestFeedback("Touch Test", Icons.touch_app),
    TestFeedback("Repetition Test", Icons.repeat),
    TestFeedback("Mouth Movement Test", Icons.sentiment_satisfied),
    TestFeedback("Naming Test", Icons.text_fields),
  ];

  WidgetsBinding.instance.addPostFrameCallback((_) {
    _playIntroThenEnableStart();
  });
}

  // Test state variables
  int currentIndex = 0;
  bool isRunning = false;
  bool isPaused = false;
  bool _introComplete = false;
  Timer? _timer;
  DateTime? _lastStartTime;
  Duration _elapsed = Duration.zero;
  List<int>? _retryIndices; // Stores range of steps to retry
  int _retryPointer = 0;

  // Iniatlizie test-to-speech
  late FlutterTts flutterTts;

  // Plays the intro audio and then enables the start button
  void _playIntroThenEnableStart() async {
  await _speak(instructions[0]); // Play the intro
  setState(() {
    _introComplete = true; // Show the button
  });
}

  // Speaks the given string using TTS
  Future<void> _speak(String text) async {
    await flutterTts.stop();
    await flutterTts.speak(text);
  }

  // Starts the test sequence
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
    // _scheduleNext(); <-- No auto-schedule! Wait for sensor or skip
  }

  // This is now ONLY for "retry" logic, otherwise advancing is controlled by completion or skip
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
      setState(() {
        currentIndex++;
        _elapsed = Duration.zero;
        _lastStartTime = DateTime.now();
      });
      _speak(instructions[currentIndex]);
      // Do not auto-schedule next!
    }
  }

  // Pauses the test
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

  // Resumes a paused test
  void _resume() {
    if (!isPaused) return;
    setState(() {
      isRunning = true;
      isPaused = false;
      _lastStartTime = DateTime.now();
    });
    _speak(instructions[currentIndex]);
    // No auto-schedule! Wait for sensor or skip
  }

  // Fully resets the test sequence
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

  // Restarts a given test section
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
    // No auto-schedule!
  }

  // Called by each test widget once it's completed successfully
  void _onTestCompleted() {
  if (currentIndex < instructions.length - 2) { // -2 for last "results" step
    setState(() {
      // Mark the CURRENT test as finished before incrementing currentIndex
      for (final entry in testRanges.entries) {
        if (entry.value.contains(currentIndex)) {
          final testKey = entry.key;
          testFeedbackList[testKey].result = "100%"; // test now complete
        }
      }

      // Move to the next test
      currentIndex++;
      _elapsed = Duration.zero;
      _lastStartTime = DateTime.now();
    });

    _speak(instructions[currentIndex]);
  } else {
    setState(() => isRunning = false);
    _speak(instructions.last);
  }
}


  /// Called by Skip button. Skips *current* test and moves to next.
  void _skipCurrentTest() {
    if (currentIndex < instructions.length - 2) {
      setState(() {
        currentIndex++;
        _elapsed = Duration.zero;
        _lastStartTime = DateTime.now();
      });
      _speak("Test skipped. " + instructions[currentIndex]);
    } else {
      setState(() => isRunning = false);
      _speak(instructions.last);
    }
  }

  Widget _buildTestWidget() {
    // Dynamically builds the correct test widget based on the current index
    switch (currentIndex) {
      case 1:
        return CountingTest(onCompleted: _onTestCompleted); // Sensor or widget calls this
      case 2:
        return DirectionTest(onCompleted: _onTestCompleted);
      case 3:
        return TouchTest(
          key: ValueKey('left'),
          onCompleted: _onTestCompleted,
          side: 'left',
          wearable: widget.leftWearable,
        );
      case 4:
        return TouchTest(
          key: ValueKey('right'),
          onCompleted: _onTestCompleted,
          side: 'right',
          wearable: widget.rightWearable,
        );
      case 5:
      case 6:
        return RepetitionTest(onCompleted: _onTestCompleted);
      case 7:
      case 8:
        return MouthMovementTest(onCompleted: _onTestCompleted);
      case 9:
        return NamingTest(onCompleted: _onTestCompleted);
      default:
        return Center(
          child: Text(
            instructions[currentIndex],
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 20),
          ),
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
                              child: CircularProgressIndicator(strokeWidth: 2)),
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
                  label: const Text("Skip Test"),
                  onPressed: isRunning ? _skipCurrentTest : null,
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
