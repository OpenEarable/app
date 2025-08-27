import 'package:flutter/material.dart';
import 'package:open_wearable/apps/stroke_tracker_data/widgets/test_record_page.dart';
import 'package:provider/provider.dart';

import '../controller/stroke_test_flow_controller.dart';
import '../models/stroke_test.dart';
import 'test_explanation_page.dart';
import 'test_prep_page.dart';

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
        Widget body;
        switch (ctrl.currentStage) {
          case StrokeTestStage.explanation:
            body = TestExplanationPage();
            break;
          case StrokeTestStage.preparation:
            body = TestPrepPage();
            break;
          case StrokeTestStage.recording:
            body = TestRecordPage();
            break;
          case StrokeTestStage.completed:
            body = Center(child: Text('Completed: '));
            break;
        }

        return body;
      },
    );
  }
}
