import 'dart:convert';
import 'dart:io';

import 'package:open_wearable/apps/study_protocol/model/study_protocol_storage.dart';

/// Stores one DecoupEar seal-check result in the current study directory.
///
/// Repeating a check intentionally replaces its previous file, leaving exactly
/// one `start` and one `end` result per phase.
Future<String> saveStudySealCheckResult({
  required String directory,
  required String probandId,
  required String phase,
  required String position,
  required Map<String, dynamic> result,
  DateTime? measuredAt,
}) async {
  final timestamp = measuredAt ?? DateTime.now();
  final safePhase = _sanitizeFilenamePart(phase);
  final safePosition = _sanitizeFilenamePart(position);
  final filename =
      '${sanitizeProbandId(probandId)}_${safePhase}_seal_check_$safePosition.json';
  final file = File('$directory/$filename');
  await file.parent.create(recursive: true);
  await file.writeAsString(
    const JsonEncoder.withIndent('  ').convert({
      'protocol': 'DecoupEar',
      'proband_id': probandId,
      'phase': phase,
      'position': position,
      'measured_at': timestamp.toIso8601String(),
      ...result,
    }),
    flush: true,
  );
  return file.path;
}

String _sanitizeFilenamePart(String value) {
  final sanitized =
      value.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9_-]+'), '_');
  return sanitized.isEmpty ? 'unknown' : sanitized;
}
