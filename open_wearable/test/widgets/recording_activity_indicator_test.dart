import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_wearable/models/labels/label.dart';
import 'package:open_wearable/models/labels/label_group.dart';
import 'package:open_wearable/view_models/label_provider.dart';
import 'package:open_wearable/view_models/sensor_recorder_provider_facade.dart';
import 'package:open_wearable/widgets/recording_activity_indicator.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('draws active label color around recording indicator',
      (tester) async {
    final labelGroup = LabelGroup(
      name: 'Activities',
      labels: [
        Label(name: 'Walking', color: Colors.green),
      ],
    );
    final labelProvider = LabelProvider(labelGroup)
      ..setActiveLabel(labelGroup.labels.first);
    final recorderProvider = _RecordingSensorRecorderProvider();
    addTearDown(labelProvider.dispose);
    addTearDown(recorderProvider.dispose);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SensorRecorderProvider>.value(
            value: recorderProvider,
          ),
          ChangeNotifierProvider<LabelProvider>.value(value: labelProvider),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: RecordingActivityIndicator(
              size: 20,
              showIdleOutline: false,
              padding: EdgeInsets.zero,
            ),
          ),
        ),
      ),
    );

    final borderBox = find.byKey(const ValueKey('recording-label-border'));
    expect(borderBox, findsOneWidget);

    final decoration = tester
        .widget<DecoratedBox>(
          find.descendant(
            of: borderBox,
            matching: find.byType(DecoratedBox),
          ),
        )
        .decoration as BoxDecoration;
    expect(decoration.border, isNotNull);
  });
}

class _RecordingSensorRecorderProvider extends SensorRecorderProvider {
  @override
  bool get isRecording => true;

  @override
  DateTime? get recordingStart => DateTime(2026, 7, 16, 12);
}
