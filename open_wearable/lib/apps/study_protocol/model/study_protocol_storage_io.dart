import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';

import 'package:open_wearable/widgets/sensors/local_recorder/local_recorder_models.dart';

/// Folder name prefix that identifies a study protocol recording.
///
/// Study recordings live alongside Local Recorder folders in the shared
/// recordings root but use a distinct prefix so the two lists stay separate.
const String studyRecordingPrefix = 'Study_Recording';

/// Returns the base name of a file or directory across platforms.
String studyBasename(String path) => path.split(RegExp(r'[\\/]+')).last;

/// Resolves the recordings root used for on-device storage.
///
/// Mirrors the Local Recorder so study CSV files end up in the same shareable
/// location and in the same format.
Future<Directory?> _recordingsRoot() async {
  if (kIsWeb) {
    return null;
  }

  if (Platform.isAndroid) {
    return getExternalStorageDirectory();
  }

  final appDocDir = await getApplicationDocumentsDirectory();
  final dir = Directory('${appDocDir.path}/Recordings');
  if (!await dir.exists()) {
    await dir.create(recursive: true);
  }
  return dir;
}

/// Sanitizes a proband id into a filename-safe token.
String sanitizeProbandId(String probandId) {
  final trimmed = probandId.trim();
  final sanitized = trimmed.replaceAll(RegExp(r'[^A-Za-z0-9_\-]+'), '_');
  return sanitized.isEmpty ? 'unknown' : sanitized;
}

/// Creates a new study session directory for [probandId] and returns its path.
///
/// The directory holds the phone-side RESPIRABAN CSV recordings. The
/// OpenEarable audio/IMU data is stored on each earable's own SD card and is
/// not written here.
Future<String> createStudySessionDirectory(String probandId) async {
  final root = await _recordingsRoot();
  if (root == null) {
    throw UnsupportedError('Recording storage is unavailable on this platform');
  }

  final token = sanitizeProbandId(probandId);
  final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
  final dirPath = '${root.path}/${studyRecordingPrefix}_${token}_$timestamp';
  final dir = Directory(dirPath);
  if (!await dir.exists()) {
    await dir.create(recursive: true);
  }
  return dirPath;
}

/// Lists study recording folders, newest first.
Future<List<LocalRecorderRecordingFolder>> listStudyRecordingFolders() async {
  final root = await _recordingsRoot();
  if (root == null || !await root.exists()) {
    return <LocalRecorderRecordingFolder>[];
  }

  final folders = root
      .listSync()
      .whereType<Directory>()
      .where(
        (entity) => studyBasename(entity.path).startsWith(studyRecordingPrefix),
      )
      .map(_directoryToFolder)
      .toList()
    ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

  return folders;
}

/// Deletes the study recording folder at [path].
Future<void> deleteStudyRecordingFolder(String path) async {
  final dir = Directory(path);
  if (await dir.exists()) {
    await dir.delete(recursive: true);
  }
}

LocalRecorderRecordingFolder _directoryToFolder(Directory directory) {
  final files = directory
      .listSync(recursive: false)
      .whereType<File>()
      .map(
        (file) => LocalRecorderRecordingFile(
          path: file.path,
          name: studyBasename(file.path),
          sizeBytes: file.lengthSync(),
          updatedAt: file.statSync().modified,
          mimeType: _mimeTypeForPath(file.path),
        ),
      )
      .toList()
    ..sort((a, b) => a.name.compareTo(b.name));

  return LocalRecorderRecordingFolder(
    path: directory.path,
    name: studyBasename(directory.path),
    updatedAt: directory.statSync().changed,
    files: files,
  );
}

String _mimeTypeForPath(String path) {
  final lower = path.toLowerCase();
  if (lower.endsWith('.wav')) {
    return 'audio/wav';
  }
  if (lower.endsWith('.csv')) {
    return 'text/csv';
  }
  return 'application/octet-stream';
}
