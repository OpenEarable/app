import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';

import 'local_recorder_models.dart';

Future<Directory> _ensureIOSDirectory() async {
  final appDocDir = await getApplicationDocumentsDirectory();
  final dirPath = '${appDocDir.path}/Recordings';
  final dir = Directory(dirPath);

  if (!await dir.exists()) {
    await dir.create(recursive: true);
  }

  return dir;
}

Future<String?> pickRecordingDirectory() async {
  if (kIsWeb) return null;

  final recordingName =
      'OpenWearable_Recording_${DateTime.now().toIso8601String()}';

  if (Platform.isAndroid) {
    final appDir = await getExternalStorageDirectory();
    if (appDir == null) return null;

    final dirPath = '${appDir.path}/$recordingName';
    final dir = Directory(dirPath);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dirPath;
  }

  if (Platform.isIOS) {
    final dirPath = '${(await _ensureIOSDirectory()).path}/$recordingName';
    final dir = Directory(dirPath);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dirPath;
  }

  return null;
}

Future<List<LocalRecorderRecordingFolder>> listRecordingFolders() async {
  final root = await _getRecordingsRootDirectory();
  if (root == null || !await root.exists()) {
    return <LocalRecorderRecordingFolder>[];
  }

  final folders = root
      .listSync()
      .whereType<Directory>()
      .where((entity) => entity.path.contains('OpenWearable_Recording'))
      .map(_directoryToFolder)
      .toList()
    ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

  return folders;
}

Future<bool> isRecordingDirectoryEmpty(String path) async {
  final dir = Directory(path);
  if (!await dir.exists()) return true;
  return dir.list(followLinks: false).isEmpty;
}

Future<void> deleteRecordingFolder(String path) async {
  final dir = Directory(path);
  if (await dir.exists()) {
    await dir.delete(recursive: true);
  }
}

Future<Uint8List> readRecordingFileBytes(LocalRecorderRecordingFile file) {
  return File(file.path).readAsBytes();
}

Future<String> readRecordingFileText(LocalRecorderRecordingFile file) {
  return File(file.path).readAsString();
}

Future<Directory?> _getRecordingsRootDirectory() async {
  if (kIsWeb) return null;
  if (Platform.isAndroid) {
    return getExternalStorageDirectory();
  }
  if (Platform.isIOS) {
    return _ensureIOSDirectory();
  }
  return null;
}

LocalRecorderRecordingFolder _directoryToFolder(Directory directory) {
  final files = directory
      .listSync(recursive: false)
      .whereType<File>()
      .map(
        (file) => LocalRecorderRecordingFile(
          path: file.path,
          name: localRecorderBasename(file.path),
          sizeBytes: file.lengthSync(),
          updatedAt: file.statSync().modified,
        ),
      )
      .toList()
    ..sort((a, b) => a.name.compareTo(b.name));

  return LocalRecorderRecordingFolder(
    path: directory.path,
    name: localRecorderBasename(directory.path),
    updatedAt: directory.statSync().changed,
    files: files,
  );
}