// stroke_tracker_view.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter_tts/flutter_tts.dart';

class StrokeTrackerView extends StatefulWidget {
  const StrokeTrackerView({super.key});

  @override
  State<StrokeTrackerView> createState() => _StrokeTrackerViewState();
}

class TestFeedback {
  final String name;
  final IconData icon;
  String result;
  TestFeedback(this.name, this.icon, {this.result = "100%"});
}

class _StrokeTrackerViewState extends State<StrokeTrackerView> {
  final List<String> instructions = [
    "The first test will begin when the button is pressed.",
    "Please count from 0 to 10 out loud.",
    "Look straight ahead.",
    "Turn your head 90° in the direction the sound played.",
    "Look straight ahead.",
    "Turn your head 90° in the direction the sound played.",
    "Touch your left earphone with your right hand.",
    "Touch your right earphone with your left hand.",
    "Repeat: Today is a sunny day.",
    "Repeat: The quick brown fox jumps over the lazy dog.",
    "Hold a neutral expression.",
    "Now smile.",
    "Hold a neutral expression.",
    "Now smile again.",
    "Processing results...",
    "Stroke Probability: RESULTS HERE",
  ];

  final List<Duration> durations = [
    Duration(seconds: 0),
    Duration(seconds: 15),
    Duration(seconds: 7),
    Duration(seconds: 8),
    Duration(seconds: 7),
    Duration(seconds: 8),
    Duration(seconds: 6),
    Duration(seconds: 6),
    Duration(seconds: 15),
    Duration(seconds: 15),
    Duration(seconds: 6),
    Duration(seconds: 6),
    Duration(seconds: 6),
    Duration(seconds: 6),
    Duration(seconds: 3),
    Duration(seconds: 15),
  ];

  final Map<int, List<int>> testRanges = {
    0: [1],
    1: [2, 3, 4, 5],
    2: [6, 7],
    3: [8, 9],
    4: [10, 11, 12, 13],
  };

  final List<TestFeedback> testFeedbackList = [
    TestFeedback("Counting Test", LucideIcons.hash),
    TestFeedback("Direction Test", LucideIcons.compass),
    TestFeedback("Touch Test", LucideIcons.hand),
    TestFeedback("Repetition Test", LucideIcons.repeat),
    TestFeedback("Mouth Movement Test", LucideIcons.smile),
  ];

  int currentIndex = 0;
  Timer? _timer;
  bool isRunning = false;
  bool isPaused = false;
  DateTime? _lastStartTime;
  Duration _elapsed = Duration.zero;
  List<int>? _retryIndices;
  int _retryPointer = 0;

  late FlutterTts flutterTts;

  @override
  void initState() {
    super.initState();
    flutterTts = FlutterTts();

    flutterTts.setLanguage("en-US");
    flutterTts.setPitch(1.0);
    flutterTts.setSpeechRate(0.5);
  }

  Future<void> _speak(String text) async {
    await flutterTts.stop(); // Stop any ongoing speech first
    await flutterTts.speak(text);
  }

  void _startSequence() {
    if (isRunning) return;
    setState(() {
      isRunning = true;
      isPaused = false;
      currentIndex = _retryIndices != null ? _retryIndices!.first : 1;
      _retryPointer = 0;
      _elapsed = Duration.zero;
      _lastStartTime = DateTime.now();
    });
    _speak(instructions[currentIndex]);
    _scheduleNextInstruction();
  }

  void _scheduleNextInstruction() {
    _timer?.cancel();

    if (_retryIndices != null) {
      if (_retryPointer >= _retryIndices!.length) {
        setState(() {
          currentIndex = instructions.length - 1;
          _retryIndices = null;
          isRunning = false;
        });
        _speak(instructions[currentIndex]);
        return;
      }
      int idx = _retryIndices![_retryPointer];
      _timer = Timer(durations[idx], () {
        setState(() {
          _retryPointer++;
          currentIndex = _retryPointer < _retryIndices!.length
              ? _retryIndices![_retryPointer]
              : instructions.length - 1;
          _elapsed = Duration.zero;
          _lastStartTime = DateTime.now();
        });
        _speak(instructions[currentIndex]);
        _scheduleNextInstruction();
      });
    } else {
      if (currentIndex >= instructions.length - 1) {
        setState(() {
          currentIndex = instructions.length - 1;
          isRunning = false;
        });
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
        _scheduleNextInstruction();
      });
    }
  }

  void _retryTest(int index) {
    _timer?.cancel();
    flutterTts.stop();

    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger != null) {
      messenger.showSnackBar(
        SnackBar(
          content: Text("Restarting ${testFeedbackList[index].name}..."),
          duration: const Duration(seconds: 2),
        ),
      );
    }

    setState(() {
      _retryIndices = testRanges[index]!;
      currentIndex = _retryIndices!.first;
      _retryPointer = 0;
      isRunning = true;
      _elapsed = Duration.zero;
      _lastStartTime = DateTime.now();
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _speak(instructions[currentIndex]);
      _scheduleNextInstruction();
    });
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
    if (isPaused) {
      setState(() {
        isRunning = true;
        isPaused = false;
        _lastStartTime = DateTime.now();
      });
      _speak(instructions[currentIndex]);
      _scheduleNextInstruction();
    }
  }

 void _skipTest() {
  _timer?.cancel();

  // Find current test index containing currentIndex
  int? currentTestKey;
  testRanges.forEach((key, range) {
    if (range.contains(currentIndex)) {
      currentTestKey = key;
    }
  });

  setState(() {
    if (currentTestKey == null) {
      // Not in a test range — go to results
      currentIndex = instructions.length - 1;
      isRunning = false;
      _retryIndices = null;
    } else {
      int nextTestKey = currentTestKey! + 1;
      if (testRanges.containsKey(nextTestKey)) {
        // Jump to first instruction of next test block
        currentIndex = testRanges[nextTestKey]!.first;
        _retryIndices = null;
        isRunning = true;
        _elapsed = Duration.zero;
        _lastStartTime = DateTime.now();

        // Reschedule timer for next instruction
        _scheduleNextInstruction();
      } else {
        // No next test, go to results
        currentIndex = instructions.length - 1;
        isRunning = false;
        _retryIndices = null;
      }
    }
  });
}


  @override
  void dispose() {
    _timer?.cancel();
    flutterTts.stop();
    super.dispose();
  }

  Widget _buildFeedbackPanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 8.0),
          child: Text(
            "Test Results",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              children: testFeedbackList.asMap().entries.map((entry) {
                final index = entry.key;
                final feedback = entry.value;
                return Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: Colors.grey.shade300),
                    ),
                    elevation: 3,
                    child: ListTile(
                      leading: Icon(feedback.icon, size: 28, color: Colors.blueAccent),
                      title: Text(feedback.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text("Result: ${feedback.result}", style: const TextStyle(color: Colors.green)),
                      trailing: IconButton(
                        icon: const Icon(Icons.refresh),
                        onPressed: () => _retryTest(index),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomControls(bool isFinished) {
    return Column(
      children: [
        Expanded(
          child: Center(
            child: Text(
              instructions[currentIndex],
              style: const TextStyle(fontSize: 18),
              textAlign: TextAlign.center,
            ),
          ),
        ),
        if (!isRunning && !isFinished)
          ElevatedButton.icon(
            onPressed: isPaused ? _resume : _startSequence,
            icon: Icon(isPaused ? Icons.play_arrow : Icons.play_arrow),
            label: Text(isPaused ? 'Resume' : 'Start Tests'),
          ),
        if (isRunning)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Text("Test in progress..."),
              SizedBox(width: 10),
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ],
          ),
        if (isFinished && !isRunning)
          ElevatedButton.icon(
            onPressed: _reset,
            icon: const Icon(Icons.restart_alt),
            label: const Text('Restart'),
          ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 4,
          children: List.generate(instructions.length, (i) {
            return CircleAvatar(
              radius: 6,
              backgroundColor:
                  i == currentIndex ? Colors.blue : Colors.grey[300],
            );
          }),
        ),
        const SizedBox(height: 10),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isFinished = currentIndex == instructions.length - 1;

    return Scaffold(
      appBar: AppBar(title: const Text("Stroke Tracker")),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              Expanded(flex: 2, child: _buildFeedbackPanel()),
              const Divider(thickness: 1),
              Expanded(flex: 1, child: _buildBottomControls(isFinished)),
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
                  onPressed: isRunning ? _pause : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orangeAccent,
                    minimumSize: const Size(120, 40),
                  ),
                  icon: const Icon(Icons.pause),
                  label: const Text("Pause"),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: isRunning ? _skipTest : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    minimumSize: const Size(120, 40),
                  ),
                  icon: const Icon(Icons.skip_next),
                  label: const Text("Skip"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
