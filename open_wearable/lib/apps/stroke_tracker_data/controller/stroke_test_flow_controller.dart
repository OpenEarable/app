import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:open_wearable/apps/stroke_tracker_data/models/stroke_test.dart';

enum StrokeTestStage {
  explanation,
  preparation,
  recording,
  completed,
}

class StrokeTestFlowController with ChangeNotifier {
  final List<StrokeTest> _strokeTests;
  int _testIndex = 0;
  StrokeTestStage _testStage = StrokeTestStage.explanation;

  StrokeTest? get currentTest =>
      _testIndex < _strokeTests.length ? _strokeTests[_testIndex] : null;

  StrokeTestStage get currentStage => _testStage;

  bool get isLast => _testIndex == _strokeTests.length - 1;

  Timer? _stageTransitionTimer;

  Timer? _ticker;
  Duration _stageTotal = Duration.zero;
  Duration _remaining = Duration.zero;
  DateTime? _endAt;
  Duration get stageTotal => _stageTotal;
  bool get isCountingDown => _ticker != null;
  Duration get remaining => _remaining;
  DateTime? get endAt => _endAt;

  StrokeTestFlowController({List<StrokeTest> strokeTests = const []})
      : _strokeTests = strokeTests;

  StrokeTest? next() {
    _testIndex++;
    setStage(StrokeTestStage.explanation);
    notifyListeners();
    return currentTest!;
  }

  void setStage(StrokeTestStage stage) {
    _stageTransitionTimer?.cancel();
    _testStage = stage;
    switch (stage) {
      case StrokeTestStage.preparation:
        _startTimer(const Duration(seconds: 5));
        break;
      case StrokeTestStage.recording:
        Duration recordingDuration = currentTest?.recordingDuration ?? Duration.zero;
        _startTimer(recordingDuration);
        break;
      default:
        break;
    }
    notifyListeners();
  }

  void nextStage() {
    _stageTransitionTimer?.cancel();
    switch (_testStage) {
      case StrokeTestStage.explanation:
        setStage(StrokeTestStage.preparation);
        break;
      case StrokeTestStage.preparation:
        setStage(StrokeTestStage.recording);
        break;
      case StrokeTestStage.recording:
        setStage(StrokeTestStage.completed);
        break;
      case StrokeTestStage.completed:
        throw StateError('No more stages available');
    }
    notifyListeners();
  }

  void _startTimer(Duration duration) {
    _ticker?.cancel();
    _stageTransitionTimer?.cancel();
    _stageTotal = duration;
    _remaining = duration;
    if (duration > Duration.zero) {
      _endAt = DateTime.now().add(duration);
      
      _ticker = Timer.periodic(const Duration(seconds: 1), (t) {
        final now = DateTime.now();
        _remaining = _endAt!.isAfter(now) ? _endAt!.difference(now) : Duration.zero;
        notifyListeners();
        if (_remaining == Duration.zero) {
          t.cancel();
          _ticker = null;
          _endAt = null;
          nextStage();
        }
      });
    } else {
      _remaining = Duration.zero;
      _ticker = null;
      _stageTransitionTimer = null;
      _endAt = null;
      notifyListeners();
    }
  }
}
