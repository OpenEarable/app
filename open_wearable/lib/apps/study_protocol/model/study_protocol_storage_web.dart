import 'package:open_wearable/widgets/sensors/local_recorder/local_recorder_models.dart';

/// Folder name prefix that identifies a study protocol recording.
const String studyRecordingPrefix = 'Study_Recording';

/// Returns the base name of a file or directory across platforms.
String studyBasename(String path) => path.split(RegExp(r'[\\/]+')).last;

/// Sanitizes a proband id into a filename-safe token.
String sanitizeProbandId(String probandId) {
  final trimmed = probandId.trim();
  final sanitized = trimmed.replaceAll(RegExp(r'[^A-Za-z0-9_\-]+'), '_');
  return sanitized.isEmpty ? 'unknown' : sanitized;
}

/// Study recordings require local file storage, which is unavailable on web.
Future<String> createStudySessionDirectory(String probandId) async {
  throw UnsupportedError('Study recordings are not supported on web');
}

/// No study recordings are available on web.
Future<List<LocalRecorderRecordingFolder>> listStudyRecordingFolders() async {
  return <LocalRecorderRecordingFolder>[];
}

/// No-op on web.
Future<void> deleteStudyRecordingFolder(String path) async {}
