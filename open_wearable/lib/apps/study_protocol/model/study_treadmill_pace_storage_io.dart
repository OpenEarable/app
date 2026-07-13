import 'dart:io';

import 'package:open_wearable/apps/study_protocol/model/study_protocol_storage.dart';

/// Stores the treadmill walking pace (in km/h) as a CSV in the study directory.
///
/// Written before the treadmill timer starts. Repeating the treadmill unit
/// creates a new numbered file instead of overwriting the previous pace.
Future<String> saveTreadmillWalkingPace({
  required String directory,
  required String probandId,
  required double walkingPaceKmh,
  DateTime? recordedAt,
}) async {
  final timestamp = recordedAt ?? DateTime.now();
  final filename = '${sanitizeProbandId(probandId)}_treadmill_pace.csv';
  final file = File(await uniqueStudyFilePath(directory, filename));
  await file.parent.create(recursive: true);
  final buffer = StringBuffer()
    ..writeln('proband_id,walking_pace_kmh,recorded_at')
    ..writeln('$probandId,$walkingPaceKmh,${timestamp.toIso8601String()}');
  await file.writeAsString(buffer.toString(), flush: true);
  return file.path;
}
