import 'package:flutter/material.dart';
import 'package:open_wearable/apps/stroke_tracker_data/widgets/asset_video_player.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';

import '../controller/stroke_test_flow_controller.dart';
import 'test_stage_page.dart';

class TestExplanationPage extends StatefulWidget {

  const TestExplanationPage({super.key});

  @override
  State<TestExplanationPage> createState() => _TestExplanationPageState();
}

class _TestExplanationPageState extends State<TestExplanationPage> {
  late VideoPlayerController _controller;

  @override
  void initState() {
    super.initState();
    final ctrl = context.read<StrokeTestFlowController>();
    if (ctrl.currentTest?.explainerVideoAsset != null) {
      _controller = VideoPlayerController.asset(
        ctrl.currentTest!.explainerVideoAsset!,
      );
    }
  }

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
      body: Center(
        child: strokeTest.explainerVideoAsset == null
            ? Text("No Video Available")
            : AssetVideoPlayer(controller: _controller),
      ),
      redoHidden: false,
      onRedo: () {
        _controller.seekTo(Duration.zero);
        // FIXME: video does not replay
        _controller.play();
      },
    );
  }
}
