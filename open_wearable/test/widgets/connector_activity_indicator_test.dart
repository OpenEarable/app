import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_wearable/models/connector_settings.dart';
import 'package:open_wearable/widgets/connector_activity_indicator.dart';

void main() {
  testWidgets('shows only while connector runtime is active', (tester) async {
    final statusNotifier = ValueNotifier<ConnectorRuntimeStatus>(
      const ConnectorRuntimeStatus.disabled(),
    );
    addTearDown(statusNotifier.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ConnectorActivityIndicator(
            statusListenable: statusNotifier,
          ),
        ),
      ),
    );

    expect(find.text('Connector'), findsNothing);

    statusNotifier.value = const ConnectorRuntimeStatus.starting();
    await tester.pump();
    expect(find.text('Connector'), findsOneWidget);

    statusNotifier.value = const ConnectorRuntimeStatus.running();
    await tester.pump();
    expect(find.text('Connector'), findsOneWidget);
    expect(
      tester.getCenter(find.text('Connector')).dx,
      closeTo(tester.getSize(find.byType(MaterialApp)).width / 2, 60),
    );

    statusNotifier.value = const ConnectorRuntimeStatus.error('failed');
    await tester.pump();
    expect(find.text('Connector'), findsNothing);
  });
}
