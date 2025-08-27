import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:open_wearable/apps/stroke_tracker_data/widgets/count_down_view.dart';
import 'package:provider/provider.dart';

import '../controller/stroke_test_flow_controller.dart';

const _kHeaderHeight = 88.0;

class TestStagePage extends StatelessWidget {
  final Widget header;
  final Widget body;
  final bool nextHidden;
  final bool redoHidden;

  const TestStagePage({
    super.key,
    required this.header,
    required this.body,
    this.nextHidden = false,
    this.redoHidden = false,
  });

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<StrokeTestFlowController>();
    final theme = Theme.of(context);
    final surface = theme.colorScheme.surface;

    return PlatformScaffold(
      // Keep the native-looking title bar; content goes behind custom header/footer
      appBar: PlatformAppBar(
        title: PlatformText('Stroke Tracker Data Collection'),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return Stack(
            children: [
              body,

              // HEADER (frosted)
              SafeArea(
                bottom: false,
                child: _FrostedBar(
                  height: _kHeaderHeight,
                  background: surface,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: DefaultTextStyle(
                      style: theme.textTheme.titleMedium!,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: header,
                      ),
                    ),
                  ),
                ),
              ),

              // FOOTER with pinned buttons
              SafeArea(
                top: false,
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Directionality(
                      textDirection: Directionality.of(context),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          CountdownView(compact: true,),
                          // Leading corner: Redo
                          if (!redoHidden)
                            PlatformIconButton(
                              icon: const Icon(Icons.refresh),
                              onPressed: () {
                                // TODO: redo current stage
                              },
                              cupertino: (_, __) =>
                                  CupertinoIconButtonData(padding: EdgeInsets.zero),
                              material: (_, __) =>
                                  MaterialIconButtonData(padding: EdgeInsets.zero),
                            )
                          else
                            const SizedBox(width: 48), // keep spacing symmetric

                          // Trailing corner: Next
                          if (!nextHidden)
                            PlatformElevatedButton(
                              child: const Text('Next'),
                              onPressed: () {
                                if (ctrl.currentStage == StrokeTestStage.completed) {
                                  // TODO: advance to next test or finish
                                }
                                context.read<StrokeTestFlowController>().nextStage();
                              },
                            )
                          else
                            const SizedBox(width: 48),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Reusable frosted “glass” bar with subtle divider and shadow.
class _FrostedBar extends StatelessWidget {
  final double height;
  final Color background;
  final Widget child;

  const _FrostedBar({
    required this.height,
    required this.background,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      // Slight rounding to make it feel like a sheet
      child: SizedBox(
        width: double.infinity,
        height: height,
        child: Stack(
          children: [
            // blur the content behind
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: const SizedBox(),
              ),
            ),
            // content
            Positioned.fill(child: child),
            // subtle divider at top/bottom depending on placement
          ],
        ),
      ),
    );
  }
}
