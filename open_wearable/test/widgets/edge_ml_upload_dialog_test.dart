import 'dart:async';

import 'package:edge_ml_dart/edge_ml_dart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_wearable/services/edge_ml/recording_importer.dart';
import 'package:open_wearable/widgets/sensors/local_recorder/edge_ml_upload_dialog.dart';
import 'package:open_wearable/widgets/sensors/local_recorder/local_recorder_models.dart';

final folder = LocalRecorderRecordingFolder(
  path: 'session',
  name: 'session',
  updatedAt: DateTime(2026),
  files: [],
);

Future<void> openDialog(
  WidgetTester tester, {
  required Future<String> Function(DatasetRecording, String) upload,
  Future<EdgeMlRecordingImport> Function(LocalRecorderRecordingFolder)? prepare,
}) async {
  final recording = DatasetRecording('session');
  recording.add('left_X', 1, timestamp: 1793989737000);
  recording.addLabel(
    const DatasetLabel(
      'MyLabel',
      'Label1',
      start: 1793989737000,
      end: 1793989737000,
    ),
  );
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => showEdgeMlUploadDialog(
              context,
              folder,
              prepare:
                  prepare ??
                  (_) async => EdgeMlRecordingImport(
                    recording: recording,
                    channelNames: ['left_X'],
                    warnings: [],
                    firstTimestampMs: 1793989737000,
                    lastTimestampMs: 1793989737000,
                  ),
              upload: upload,
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'requires key, uploads only on request and prevents duplicate submissions',
    (tester) async {
      final completed = Completer<String>();
      var uploads = 0;
      await openDialog(
        tester,
        upload: (recording, key) {
          uploads++;
          expect(recording.name, 'Renamed');
          expect(recording.labels.single.label, 'Label1');
          expect(key, 'write-key');
          return completed.future;
        },
      );
      expect(uploads, 0);
      await tester.tap(find.widgetWithText(FilledButton, 'Upload to Edge ML'));
      await tester.pump();
      expect(find.text('Enter the project’s write key.'), findsOneWidget);
      expect(uploads, 0);
      await tester.enterText(find.byType(TextFormField).first, 'Renamed');
      await tester.enterText(find.byType(TextFormField).last, 'write-key');
      await tester.tap(find.widgetWithText(FilledButton, 'Upload to Edge ML'));
      await tester.pump();
      expect(uploads, 1);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      expect(
        tester
            .widget<TextButton>(find.widgetWithText(TextButton, 'Close'))
            .onPressed,
        isNull,
      );
      completed.complete('dataset-123');
      await tester.pumpAndSettle();
      expect(find.text('Dataset ID: dataset-123'), findsOneWidget);
      expect(find.text('Done'), findsOneWidget);
      expect(find.byType(TextFormField), findsNothing);
    },
  );

  testWidgets('does not expose API keys through HTTP error text', (
    tester,
  ) async {
    await openDialog(
      tester,
      upload: (_, key) async => throw Exception('URL/$key'),
    );
    await tester.enterText(find.byType(TextFormField).last, 'secret-key');
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('partial dataset may have been created'),
      findsOneWidget,
    );
    expect(find.text('URL/secret-key'), findsNothing);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNotNull,
    );
  });

  testWidgets('conversion errors prevent upload', (tester) async {
    await openDialog(
      tester,
      upload: (_, _) async => throw StateError('must not upload'),
      prepare: (_) async => throw const FormatException('No sensor samples.'),
    );
    expect(find.text('No sensor samples.'), findsOneWidget);
    expect(find.byType(FilledButton), findsNothing);
    expect(find.text('Close'), findsOneWidget);
  });
}
