import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_wearable/view_models/label_provider.dart';
import 'package:open_wearable/view_models/sensor_recorder_provider_facade.dart';
import 'package:open_wearable/widgets/sensors/local_recorder/local_recorder_recording_card.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('uses the full available card width', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LocalRecorderRecordingCard(
            isRecording: false,
            hasSensorsConnected: true,
            canStartRecording: true,
            isHandlingStopAction: false,
            elapsedRecordingLabel: '00:00:00',
            onStartRecording: () {},
            onStopRecording: () {},
          ),
        ),
      ),
    );

    final card = tester.widget<Card>(find.byType(Card));

    expect(card.margin, EdgeInsets.zero);
  });

  testWidgets('uses an unchecked sensor shutdown option while recording',
      (tester) async {
    var turnOffSensors = false;
    final recorderProvider = SensorRecorderProvider();
    final labelProvider = LabelProvider(null);
    addTearDown(recorderProvider.dispose);
    addTearDown(labelProvider.dispose);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SensorRecorderProvider>.value(
            value: recorderProvider,
          ),
          ChangeNotifierProvider<LabelProvider>.value(value: labelProvider),
        ],
        child: StatefulBuilder(
          builder: (context, setState) => MaterialApp(
            home: Scaffold(
              body: LocalRecorderRecordingCard(
                isRecording: true,
                hasSensorsConnected: true,
                canStartRecording: false,
                isHandlingStopAction: false,
                turnOffSensorsWhenStopping: turnOffSensors,
                elapsedRecordingLabel: '00:00:12',
                onStartRecording: () {},
                onTurnOffSensorsWhenStoppingChanged: (value) {
                  setState(() => turnOffSensors = value);
                },
                onStopRecording: () {},
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Stop + Off'), findsNothing);
    expect(find.text('Turn off sensors after stopping'), findsOneWidget);
    expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isFalse);

    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();

    expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isTrue);
  });
}
