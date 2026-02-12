import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart';
import 'package:open_wearable/view_models/sensor_recorder_provider.dart';
import 'package:open_wearable/view_models/wearables_provider.dart';
import 'package:open_wearable/widgets/home_page.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('Home shell shows top-level navigation', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => WearablesProvider()),
          ChangeNotifierProvider(create: (_) => SensorRecorderProvider()),
          ChangeNotifierProvider(
            create: (_) => FirmwareUpdateRequestProvider(),
          ),
        ],
        child: const MaterialApp(
          home: HomePage(),
        ),
      ),
    );

    expect(find.text('Overview'), findsWidgets);
    expect(find.text('Devices'), findsWidgets);
    expect(find.text('Sensors'), findsWidgets);
    expect(find.text('Apps'), findsWidgets);
    expect(find.text('Utilities'), findsWidgets);
  });
}
