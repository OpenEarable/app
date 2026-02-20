import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';

String localRecorderBasename(String path) => path.split(RegExp(r'[\\/]+')).last;

String localRecorderFormatFileSize(File file) {
  final bytes = file.lengthSync();
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

String localRecorderFormatDateTime(DateTime value) {
  final local = value.toLocal();
  String twoDigits(int n) => n.toString().padLeft(2, '0');
  return '${local.year}-${twoDigits(local.month)}-${twoDigits(local.day)} '
      '${twoDigits(local.hour)}:${twoDigits(local.minute)}';
}

Future<Directory> getIOSDirectory() async {
  final appDocDir = await getApplicationDocumentsDirectory();
  final dirPath = '${appDocDir.path}/Recordings';
  final dir = Directory(dirPath);

  if (!await dir.exists()) {
    await dir.create(recursive: true);
  }

  return dir;
}

Future<Directory?> getRecordingsRootDirectory() async {
  if (kIsWeb) return null;
  if (Platform.isAndroid) {
    return getExternalStorageDirectory();
  }
  if (Platform.isIOS) {
    return getIOSDirectory();
  }
  return null;
}

Future<List<Directory>> listRecordingDirectories() async {
  final recordingsDir = await getRecordingsRootDirectory();
  if (recordingsDir == null || !await recordingsDir.exists()) {
    return <Directory>[];
  }

  final entities = recordingsDir.listSync();
  final recordings = entities
      .whereType<Directory>()
      .where((entity) => entity.path.contains('OpenWearable_Recording'))
      .toList();

  recordings.sort((a, b) => b.statSync().changed.compareTo(a.statSync().changed));
  return recordings;
}

List<File> listFilesInRecordingFolder(Directory folder) {
  try {
    return folder.listSync(recursive: false).whereType<File>().toList()
      ..sort((a, b) => localRecorderBasename(a.path).compareTo(localRecorderBasename(b.path)));
  } catch (_) {
    return <File>[];
  }
}

Future<bool> isDirectoryEmpty(String path) async {
  final dir = Directory(path);
  if (!await dir.exists()) return true;
  return dir.list(followLinks: false).isEmpty;
}

Future<String?> pickRecordingDirectory() async {
  if (kIsWeb) return null;

  if (Platform.isAndroid) {
    final recordingName =
        'OpenWearable_Recording_${DateTime.now().toIso8601String()}';
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
    final recordingName =
        'OpenWearable_Recording_${DateTime.now().toIso8601String()}';
    final dirPath = '${(await getIOSDirectory()).path}/$recordingName';
    final dir = Directory(dirPath);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dirPath;
  }

  return null;
}
