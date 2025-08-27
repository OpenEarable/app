import 'package:flutter/material.dart';
import 'package:open_wearable/apps/stroke_tracker_data/widgets/front_camera_view.dart';
import 'package:open_wearable/apps/stroke_tracker_data/widgets/test_stage_page.dart';

class TestRecordPage extends StatelessWidget {
  const TestRecordPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const TestStagePage(
      header: Text('Recording'),
      body: FrontCameraView(),
    );
  }
}
