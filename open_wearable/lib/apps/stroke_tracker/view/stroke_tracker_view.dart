import 'dart:async';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

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

  final List<int> sectionStarts = [0, 6, 8, 10, 14];

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

  void _startSequence() {
    if (isRunning) return;
    setState(() {
      isRunning = true;
      currentIndex = 1;
    });
    _scheduleNextInstruction();
  }

  void _scheduleNextInstruction() {
    _timer?.cancel();

    if (currentIndex >= instructions.length - 1) {
      setState(() => isRunning = false);
      return;
    }

    _timer = Timer(durations[currentIndex], () {
      setState(() {
        currentIndex++;
      });
      _scheduleNextInstruction();
    });
  }

  void _skipTest() {
    for (int start in sectionStarts) {
      if (start > currentIndex) {
        setState(() {
          currentIndex = start;
        });
        _scheduleNextInstruction();
        return;
      }
    }
    setState(() {
      currentIndex = instructions.length - 1;
      isRunning = false;
    });
    _timer?.cancel();
  }

  void _reset() {
    _timer?.cancel();
    setState(() {
      currentIndex = 0;
      isRunning = false;
    });
  }

  void _pause() {
    _timer?.cancel();
    setState(() => isRunning = false);
  }

  void _retryTest(int index) {
    if (currentIndex != instructions.length - 1) return;

    _timer?.cancel();
    String testName = testFeedbackList[index].name;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Restarting $testName section…"),
        duration: const Duration(seconds: 2),
      ),
    );
    setState(() {
      switch (index) {
        case 0:
          currentIndex = 1;
          break;
        case 1:
          currentIndex = 3;
          break;
        case 2:
          currentIndex = 6;
          break;
        case 3:
          currentIndex = 8;
          break;
        case 4:
          currentIndex = 10;
          break;
      }
      isRunning = true;
    });
    _scheduleNextInstruction();
  }

  @override
  void dispose() {
    _timer?.cancel();
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
            onPressed: _startSequence,
            icon: const Icon(Icons.play_arrow),
            label: const Text('Start Tests'),
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
                    backgroundColor: Colors.cyan,
                    minimumSize: const Size(120, 40),
                  ),
                  icon: const Icon(Icons.skip_next),
                  label: const Text("Skip Test"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
