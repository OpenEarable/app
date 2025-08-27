import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:provider/provider.dart';

import '../controller/stroke_test_flow_controller.dart';

class CountdownView extends StatefulWidget {
  final bool compact;
  const CountdownView({super.key, this.compact = false});

  @override
  State<CountdownView> createState() => _CountdownViewState();
}

class _CountdownViewState extends State<CountdownView>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((_) {
      final ctrl = context.read<StrokeTestFlowController>();
      if (!ctrl.isCountingDown || ctrl.endAt == null || ctrl.stageTotal == Duration.zero) return;
      // repaint smoothly each frame
      setState(() {});
    })..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Pull stable references (no rebuilds from provider unless these change)
    final (endAt, total, remaining, counting) =
        context.select<StrokeTestFlowController, (DateTime?, Duration, Duration, bool)>(
      (c) => (c.endAt, c.stageTotal, c.remaining, c.isCountingDown),
    );

    if (!counting || endAt == null || total == Duration.zero) {
      return const SizedBox.shrink();
    }

    // Compute continuous remaining/progress from wall-clock
    final now = DateTime.now();
    final contRemaining = endAt.isAfter(now) ? endAt.difference(now) : Duration.zero;
    final progress = (1 - (contRemaining.inMilliseconds / total.inMilliseconds))
        .clamp(0.0, 1.0);

    String two(int n) => n.toString().padLeft(2, '0');
    final mins = two(remaining.inMinutes.remainder(60));
    final secs = two((remaining.inMilliseconds / 1000).ceil().remainder(60));

    final size = widget.compact ? 45.0 : 65.0;

    return Stack(
      alignment: Alignment.center,
      children: [
        SizedBox(
          width: size,
          height: size,
          child: CircularProgressIndicator(value: progress),
        ),
        Text(
          '$mins:$secs',
          style: widget.compact
              ? Theme.of(context).textTheme.titleMedium
              : Theme.of(context).textTheme.headlineSmall,
        ),
      ],
    );
  }
}
