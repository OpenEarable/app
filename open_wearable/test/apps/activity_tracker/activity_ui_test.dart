import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:open_wearable/apps/activity_tracker/models/activity_models.dart';
import 'package:open_wearable/apps/activity_tracker/view_models/activity_tracker_controller.dart';
import 'package:open_wearable/apps/activity_tracker/widgets/activity_session_pages.dart';
import 'package:open_wearable/apps/activity_tracker/widgets/activity_tracker_page.dart';
import 'package:open_wearable/theme/app_theme.dart';
import 'activity_test_support.dart';

void main() {
  testWidgets('saved sessions remain accessible without a connected device',
      (tester) async {
    final c = ActivityTrackerController(
      source: ReplayActivitySource(),
      storage: MemoryActivityStorage(),
      observeLifecycle: false,
    );
    await c.ready;
    c.sessions.add(
      ActivitySession(
        id: 'offline',
        startedAt: DateTime(2026),
        endedAt: DateTime(2026, 1, 1, 0, 1),
        deviceName: 'ear',
        steps: 42,
      ),
    );
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: c,
        child: MaterialApp(
          theme: AppTheme.lightTheme(),
          home: const ActivityTrackerPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('View sessions'));
    await tester.pumpAndSettle();
    expect(find.textContaining('42 steps'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    c.dispose();
    await tester.pump();
  });
  Future<void> preview(WidgetTester tester, String name, GlobalKey key) async {
    final output = Platform.environment['ACTIVITY_PREVIEW_DIRECTORY'];
    if (output == null) return;
    await tester.runAsync(() async {
      final image = await (key.currentContext!.findRenderObject()
              as RenderRepaintBoundary)
          .toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await File('$output/$name.png').writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  for (final width in [320.0, 390.0]) {
    testWidgets('readiness, workout and session navigation at $width px',
        (tester) async {
      tester.view.physicalSize = Size(width, width == 320 ? 568 : 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final font = Platform.environment['ACTIVITY_PREVIEW_FONT'];
      if (font != null) {
        await tester.runAsync(() async {
          final loader = FontLoader('Roboto')
            ..addFont(File(font).readAsBytes().then(ByteData.sublistView));
          await loader.load();
          final icons = Platform.environment['ACTIVITY_PREVIEW_MATERIAL_ICONS'];
          if (icons != null) {
            await (FontLoader('MaterialIcons')
                  ..addFont(
                    File(icons).readAsBytes().then(ByteData.sublistView),
                  ))
                .load();
          }
        });
      }
      final hostTheme = AppTheme.lightTheme();
      final theme = font == null
          ? hostTheme
          : hostTheme.copyWith(
              textTheme: hostTheme.textTheme.apply(fontFamily: 'Roboto'),
              elevatedButtonTheme: ElevatedButtonThemeData(
                style: hostTheme.elevatedButtonTheme.style!.copyWith(
                  textStyle: WidgetStatePropertyAll(
                    hostTheme.elevatedButtonTheme.style!.textStyle!
                        .resolve({})!.copyWith(fontFamily: 'Roboto'),
                  ),
                ),
              ),
              outlinedButtonTheme: OutlinedButtonThemeData(
                style: hostTheme.outlinedButtonTheme.style!.copyWith(
                  textStyle: WidgetStatePropertyAll(
                    hostTheme.outlinedButtonTheme.style!.textStyle!
                        .resolve({})!.copyWith(fontFamily: 'Roboto'),
                  ),
                ),
              ),
            );
      final source = ReplayActivitySource();
      final c = ActivityTrackerController(
        source: source,
        storage: MemoryActivityStorage(),
        observeLifecycle: false,
      );
      final key = GlobalKey();
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: c,
          child: RepaintBoundary(
            key: key,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: theme,
              home: ActivityTrackerPage(wearable: TestActivityWearable()),
            ),
          ),
        ),
      );
      await tester.pump();
      source.still();
      await tester.tap(find.byType(Checkbox).first);
      await tester.pumpAndSettle();
      expect(find.text('Ready to move?'), findsOneWidget);
      await preview(tester, 'ready-$width', key);
      await tester.tap(find.text('Start tracking'));
      await tester.pumpAndSettle();
      expect(find.text('TODAY’S STEPS'), findsOneWidget);
      expect(find.text('Study mode'), findsOneWidget);
      await preview(tester, 'overview-$width', key);
      await tester.tap(find.text('Squats').first);
      await tester.pumpAndSettle();
      expect(find.textContaining('Counting repetitions'), findsOneWidget);
      await preview(tester, 'squats-$width', key);
      await tester.tap(find.text('Pause'));
      await tester.pumpAndSettle();
      expect(find.text('Take your time'), findsOneWidget);
      await tester.tap(find.text('Resume'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Finish set'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('View sessions'));
      await tester.pumpAndSettle();
      expect(find.text('Sessions'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      c.dispose();
      await tester.pump();
    });
  }
  testWidgets(
      'English study inputs save an actual comparison and render in dark mode',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final c = ActivityTrackerController(
      source: ReplayActivitySource(),
      storage: MemoryActivityStorage(),
      observeLifecycle: false,
    );
    await c.ready;
    final session = ActivitySession(
      id: 'test',
      startedAt: DateTime(2026),
      deviceName: 'ear',
      steps: 99,
    );
    c.sessions.add(session);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: c,
        child: MaterialApp(
          theme: AppTheme.darkTheme(),
          home: ActivityStudyPage(session: session),
        ),
      ),
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Participant ID'),
      'P01',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Movement pattern / trial'),
      'Slow walking',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Reference count'),
      '100',
    );
    await tester.scrollUntilVisible(
      find.text('Save reference trial'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Save reference trial'));
    await tester.pumpAndSettle();
    expect(session.trials.single.countError, -1);
    expect(session.trials.single.participant, 'P01');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    c.dispose();
    await tester.pump();
  });
}
