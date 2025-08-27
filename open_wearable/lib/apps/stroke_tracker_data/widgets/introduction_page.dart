import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';

import '../models/stroke_test.dart';
import 'stroke_test_runner_page.dart';

class IntroductionPage extends StatelessWidget {
  final List<StrokeTest> strokeTests = [
    StrokeTest(
      title: 'Test 1',
      description: 'Description for Test 1',
      id: 'Prep',
      explainerVideoAsset: 'lib/apps/stroke_tracker_data/assets/example-video.mp4',
      recordingDuration: Duration(seconds: 10),
    ),
    StrokeTest(
      title: 'Test 2',
      description: 'Description for Test 2',
      id: 'Test2',
    ),
  ];

  IntroductionPage({super.key});

  @override
  Widget build(BuildContext context) {
    return PlatformScaffold(
      appBar: PlatformAppBar(
        title: const Text('Stroke Tracker Data Collection'),
      ),
      body: PlatformElevatedButton(
        onPressed: () {
          Navigator.push(
            context,
            platformPageRoute(
              context: context,
              builder: (context) => StrokeTestRunnerPage(strokeTests: strokeTests),
            ),
          );
        },
        child: const Text('Start Stroke Test'),
      ),
    );
  }
}
