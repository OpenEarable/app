import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart';
import 'package:open_wearable/widgets/sensors/configuration/edge_recorder_prefix_row.dart';

void main() {
  testWidgets('sets filename prefix on both paired edge recorder managers',
      (tester) async {
    final primaryManager = _FakeEdgeRecorderManager('');
    final pairedManager = _FakeEdgeRecorderManager('');

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EdgeRecorderPrefixRow(
            manager: primaryManager,
            pairedManager: pairedManager,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('On-Device Filename Prefix'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'session_01');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(primaryManager.prefix, 'session_01');
    expect(pairedManager.prefix, 'session_01');
  });
  for (final prefix in ['', 'x' * 64, 'é' * 32, 'folder/name', 'bad*name']) {
    testWidgets('rejects invalid prefix ${prefix.length}: $prefix',
        (tester) async {
      final manager = _FakeEdgeRecorderManager('original_');
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(body: EdgeRecorderPrefixRow(manager: manager)),),);
      await tester.pumpAndSettle();
      await tester.tap(find.text('On-Device Filename Prefix'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), prefix);
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(manager.writes, 0);
      expect(manager.prefix, 'original_');
      expect(find.text('Prefix not saved'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('accepts 63 characters after trimming', (tester) async {
    final manager = _FakeEdgeRecorderManager('old_');
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: EdgeRecorderPrefixRow(manager: manager)),),);
    await tester.pumpAndSettle();
    await tester.tap(find.text('On-Device Filename Prefix'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), ' ${'x' * 63} ');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(manager.prefix, 'x' * 63);
    expect(manager.writes, 1);
  });

  testWidgets('reports a paired write failure and reloads the successful side',
      (tester) async {
    final primary = _FakeEdgeRecorderManager('old_');
    final paired = _FakeEdgeRecorderManager('old_')..fail = true;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: EdgeRecorderPrefixRow(
                manager: primary, pairedManager: paired,),),),);
    await tester.pumpAndSettle();
    await tester.tap(find.text('On-Device Filename Prefix'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'new_');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(primary.prefix, 'new_');
    expect(paired.prefix, 'old_');
    expect(
        find.textContaining('Could not update paired device'), findsOneWidget,);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.text('new_'), findsOneWidget);
  });
}

class _FakeEdgeRecorderManager implements EdgeRecorderManager {
  _FakeEdgeRecorderManager(this.prefix);

  String prefix;
  int writes = 0;
  bool fail = false;

  @override
  Future<String> get filePrefix async => prefix;

  @override
  Future<void> setFilePrefix(String prefix) async {
    writes++;
    if (fail) throw StateError("disconnected");
    this.prefix = prefix;
  }
}
