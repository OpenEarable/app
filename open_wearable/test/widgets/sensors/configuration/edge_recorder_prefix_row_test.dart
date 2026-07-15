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
}

class _FakeEdgeRecorderManager implements EdgeRecorderManager {
  _FakeEdgeRecorderManager(this.prefix);

  String prefix;

  @override
  Future<String> get filePrefix async => prefix;

  @override
  Future<void> setFilePrefix(String prefix) async {
    this.prefix = prefix;
  }
}
