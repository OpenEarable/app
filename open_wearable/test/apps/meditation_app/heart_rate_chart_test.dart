// The heart-rate chart accumulates its history in State, so anything that
// replaces its element loses the whole session's trace. That is what happened
// when a meditation started: the view wrapped the layout in an extra listener
// only once a meditation existed, which changed the widget type at that slot
// and made Flutter rebuild the subtree from scratch.

import 'dart:async';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_wearable/apps/meditation_app/views/meditation_modes/bio_adaptive_view.dart';

void main() {
  late StreamController<int> heartRates;
  // StreamController.stream hands back a new object on every call, so the
  // stream is taken once here - as Measurement does with its `late final`
  // metric streams. A caller that re-reads it per build would look like a new
  // measurement to the chart on every rebuild.
  late Stream<int> heartRateStream;

  setUp(() {
    heartRates = StreamController<int>.broadcast();
    heartRateStream = heartRates.stream;
  });
  tearDown(() => heartRates.close());

  Future<void> emit(WidgetTester tester, List<int> values) async {
    for (final value in values) {
      heartRates.add(value);
      await tester.pump(const Duration(seconds: 1));
    }
  }

  int plottedPoints(WidgetTester tester) {
    final chart = tester.widget<LineChart>(find.byType(LineChart));
    return chart.data.lineBarsData.first.spots.length;
  }

  testWidgets('re-parenting the chart discards the whole trace', (
    tester,
  ) async {
    // Mirrors what the view does when a meditation starts: the same chart,
    // still at the same position, but with another builder around the subtree.
    Widget host({required bool wrapped}) {
      final chart = HeartRateChart(heartRateStream: heartRateStream);
      return MaterialApp(
        home: Scaffold(
          body: wrapped
              ? ValueListenableBuilder<int>(
                  valueListenable: ValueNotifier(0),
                  builder: (context, _, __) => chart,
                )
              : chart,
        ),
      );
    }

    await tester.pumpWidget(host(wrapped: false));
    await emit(tester, [70, 72, 74]);
    expect(plottedPoints(tester), 3);

    // Re-parenting the chart is exactly what loses the history.
    await tester.pumpWidget(host(wrapped: true));
    await emit(tester, [76]);
    expect(
      plottedPoints(tester),
      1,
      reason: 'a changed widget type at this slot discards the trace',
    );
  });

  testWidgets('the trace survives rebuilds that keep the chart in place', (
    tester,
  ) async {
    // The shape the view now always uses: the wrapper is present whether or
    // not a meditation is running, so only its inputs change.
    Widget host(int rebuildToken) {
      return MaterialApp(
        home: Scaffold(
          body: ValueListenableBuilder<int>(
            valueListenable: ValueNotifier(rebuildToken),
            builder: (context, _, __) =>
                HeartRateChart(heartRateStream: heartRateStream),
          ),
        ),
      );
    }

    await tester.pumpWidget(host(0));
    await emit(tester, [70, 72, 74]);
    expect(plottedPoints(tester), 3);

    await tester.pumpWidget(host(1));
    await emit(tester, [76]);
    expect(
      plottedPoints(tester),
      4,
      reason: 'the session trace must continue across a rebuild',
    );
  });

  testWidgets('a replaced measurement is followed, not ignored', (
    tester,
  ) async {
    // Starting the recorded-stress playback swaps the measurement while the
    // chart stays at the same place in the tree. The chart has to follow the
    // new stream; it used to keep listening to the disposed one and freeze.
    final replacement = StreamController<int>.broadcast();
    addTearDown(replacement.close);

    Widget host(Stream<int> stream) => MaterialApp(
          home: Scaffold(body: HeartRateChart(heartRateStream: stream)),
        );

    await tester.pumpWidget(host(heartRateStream));
    await emit(tester, [70, 72]);
    expect(plottedPoints(tester), 2);

    await tester.pumpWidget(host(replacement.stream));
    await tester.pump();

    // The previous session's trace does not carry into the new one.
    expect(find.byType(LineChart), findsNothing);

    replacement.add(80);
    await tester.pump(const Duration(seconds: 1));
    expect(plottedPoints(tester), 1);

    // And the old stream no longer reaches it.
    heartRates.add(99);
    await tester.pump(const Duration(seconds: 1));
    expect(plottedPoints(tester), 1);
  });
}
