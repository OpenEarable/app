import 'package:flutter/material.dart';
import 'package:open_wearable/apps/stroke_tracker_data/widgets/test_record_page.dart';
import 'package:provider/provider.dart';

import '../controller/stroke_test_flow_controller.dart';
import '../models/stroke_test.dart';
import 'no_tests_left_page.dart';
import 'test_explanation_page.dart';

class StrokeTestRunnerPage extends StatelessWidget {
  final List<StrokeTest> strokeTests;

  const StrokeTestRunnerPage({super.key, required this.strokeTests});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => StrokeTestFlowController(strokeTests: strokeTests),
      child: _RunnerScaffold(),
    );
  }
}

class _RunnerScaffold extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<StrokeTestFlowController>(
      builder: (context, ctrl, child) {
        if (ctrl.currentTest == null) {
          return NoTestsLeftPage();
        }
        return switch (ctrl.currentStage) {
          StrokeTestStage.explanation => TestExplanationPage(),
          StrokeTestStage.preparation => TestRecordPage(),
          StrokeTestStage.recording => TestRecordPage(),
          StrokeTestStage.completed => TestRecordPage(),
        };
      },
    );
  }
}
