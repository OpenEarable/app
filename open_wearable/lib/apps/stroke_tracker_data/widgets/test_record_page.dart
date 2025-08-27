import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:open_wearable/apps/stroke_tracker_data/widgets/front_camera_view.dart';
import 'package:open_wearable/apps/stroke_tracker_data/widgets/test_stage_page.dart';
import 'package:provider/provider.dart';

import '../controller/stroke_test_flow_controller.dart';
import 'count_down_view.dart';

class TestRecordPage extends StatelessWidget {
  const TestRecordPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Show an alert when being in finished stage
    final ctrl = Provider.of<StrokeTestFlowController>(context);
    if (ctrl.currentStage == StrokeTestStage.completed) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        showPlatformDialog(
          context: context,
          builder: (context) {
            return PlatformAlertDialog(
              title: Text('Test Completed'),
              content: Text('The data collection for this test has completed. Do you want to proceed to the next test?'),
              actions: [
                PlatformTextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    ctrl.setStage(StrokeTestStage.preparation);
                  },
                  child: Text('Redo'),
                ),
                PlatformTextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    ctrl.next();
                  },
                  child: Text('Next'),
                ),
              ],
            );
          },
        );
      });
    }

    return TestStagePage(
      header: Builder(builder: (context) {
        switch (ctrl.currentStage) {
          case StrokeTestStage.preparation:
            return Text('Get Ready', style: Theme.of(context).textTheme.headlineLarge);
          case StrokeTestStage.recording:
            return Text('Recording', style: Theme.of(context).textTheme.headlineLarge);
          case StrokeTestStage.completed:
            return Text('Test Completed', style: Theme.of(context).textTheme.headlineLarge);
          default:
            return Text('Unknown Stage', style: Theme.of(context).textTheme.headlineLarge);
        }
      },),
      body: Stack(
        children: [
          FrontCameraView(),
          if (ctrl.currentStage == StrokeTestStage.preparation)
            Center(child: CountdownView()),
        ],
      ),
    );
  }
}
