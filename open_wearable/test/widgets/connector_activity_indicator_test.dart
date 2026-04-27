import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_wearable/models/connector_settings.dart';
import 'package:open_wearable/widgets/connector_activity_indicator.dart';
import 'package:open_wearable/widgets/connector_branding.dart';

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
    expect(find.byIcon(ConnectorBranding.icon), findsNothing);

    statusNotifier.value = const ConnectorRuntimeStatus.starting();
    await tester.pump();
    expect(find.text('Connector'), findsNothing);
    expect(find.byIcon(ConnectorBranding.icon), findsOneWidget);

    statusNotifier.value = const ConnectorRuntimeStatus.running();
    await tester.pump();
    expect(find.text('Connector'), findsNothing);
    expect(find.byIcon(ConnectorBranding.icon), findsOneWidget);

    statusNotifier.value = const ConnectorRuntimeStatus.error('failed');
    await tester.pump();
    expect(find.text('Connector'), findsNothing);
    expect(find.byIcon(ConnectorBranding.icon), findsNothing);
  });

  testWidgets('uses red styling when connector lacks Wi-Fi', (tester) async {
    final statusNotifier = ValueNotifier<ConnectorRuntimeStatus>(
      const ConnectorRuntimeStatus.running(hasReachableNetworkAddress: false),
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

    final icon = tester.widget<Icon>(find.byIcon(ConnectorBranding.icon));
    expect(icon.color, ThemeData().colorScheme.error);
  });

  testWidgets('describes missing Wi-Fi in tooltip semantics', (tester) async {
    final statusNotifier = ValueNotifier<ConnectorRuntimeStatus>(
      const ConnectorRuntimeStatus.running(hasReachableNetworkAddress: false),
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

    expect(
      find.byTooltip('Connector active, Wi-Fi unavailable'),
      findsOneWidget,
    );
  });

  testWidgets('opens connector settings on tap', (tester) async {
    var settingsOpenCount = 0;
    final statusNotifier = ValueNotifier<ConnectorRuntimeStatus>(
      const ConnectorRuntimeStatus.running(),
    );
    addTearDown(statusNotifier.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ConnectorActivityIndicator(
            statusListenable: statusNotifier,
            onOpenSettings: () => settingsOpenCount += 1,
          ),
        ),
      ),
    );

    await tester.tap(find.byIcon(ConnectorBranding.icon));
    await tester.pump();

    expect(settingsOpenCount, 1);
  });
}
