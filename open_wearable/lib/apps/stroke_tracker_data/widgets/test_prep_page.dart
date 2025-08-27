import 'package:flutter/material.dart';
import 'package:open_wearable/apps/stroke_tracker_data/widgets/front_camera_view.dart';

import 'test_stage_page.dart';

class TestPrepPage extends StatelessWidget {
  const TestPrepPage({super.key});

  @override
  Widget build(BuildContext context) {
    return TestStagePage(
      header: Text('Get Ready', style: Theme.of(context).textTheme.headlineLarge),
      body: const FrontCameraView(),
    );
  }
}
