import 'package:flutter/material.dart';

enum StrokeTestStage {
  spatialAudio,
  touch,
  counting,
  sentence,
  smile,
  done,
}

class StrokeTrackerView extends StatefulWidget {
  const StrokeTrackerView({super.key});

  @override
  State<StrokeTrackerView> createState() => _StrokeTrackerViewState();
}

class _StrokeTrackerViewState extends State<StrokeTrackerView> {
  StrokeTestStage _currentStage = StrokeTestStage.spatialAudio;

  @override
  void initState() {
    super.initState();
    _startNextTest();
  }

  void _startNextTest() async {
    // Simulate running a test with a short delay
    await Future.delayed(Duration(seconds: 2));

    setState(() {
      _currentStage = StrokeTestStage.values[
          (_currentStage.index + 1).clamp(0, StrokeTestStage.values.length - 1)];
    });

    if (_currentStage != StrokeTestStage.done) {
      _startNextTest(); // Chain next test
    }
  }

  String _getStageMessage() {
    switch (_currentStage) {
      case StrokeTestStage.spatialAudio:
        return "Running Spatial Audio Test...";
      case StrokeTestStage.touch:
        return "Running Touch Test...";
      case StrokeTestStage.counting:
        return "Running Counting Test...";
      case StrokeTestStage.sentence:
        return "Running Sentence Repetition Test...";
      case StrokeTestStage.smile:
        return "Running Smile Detection Test...";
      case StrokeTestStage.done:
        return "All Tests Completed.";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Stroke Tracker")),
      body: Center(
        child: Text(
          _getStageMessage(),
          style: const TextStyle(fontSize: 20),
        ),
      ),
    );
  }
}
