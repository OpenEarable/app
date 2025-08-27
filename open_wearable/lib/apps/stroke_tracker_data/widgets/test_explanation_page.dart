import 'package:flutter/material.dart';
import 'package:open_wearable/apps/stroke_tracker_data/widgets/asset_video_player.dart';
import 'package:provider/provider.dart';

import '../controller/stroke_test_flow_controller.dart';
import 'test_stage_page.dart';

class TestExplanationPage extends StatelessWidget {

  const TestExplanationPage({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<StrokeTestFlowController>();
    final strokeTest = ctrl.currentTest!;

    return TestStagePage(
      header: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(strokeTest.title, style: Theme.of(context).textTheme.headlineLarge),
          Text(strokeTest.description),
        ],
      ),
      body: AssetVideoPlayer(assetPath: strokeTest.explainerVideoAsset ?? ''),
      redoHidden: true,
    );
  }
}
