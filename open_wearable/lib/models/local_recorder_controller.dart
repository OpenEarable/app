import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_archive/flutter_archive.dart';
import 'package:logger/logger.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class LocalRecorderController {
  LocalRecorderController({
    required this.platformChannel,
    required this.logger,
  });

  final MethodChannel platformChannel;
  final Logger logger;

  Future<List<FileSystemEntity>> listRecordings() async {
    final recordingsDir = await _getRecordingsRootDirectory();
    if (recordingsDir == null) return [];

    if (!await recordingsDir.exists()) return [];

    final entities = recordingsDir.listSync();

    final recordings = entities
        .where((entity) => entity is Directory && entity.path.contains('OpenWearable_Recording'))
        .toList();

    recordings.sort((a, b) => b.statSync().changed.compareTo(a.statSync().changed));
    return recordings;
  }

  List<File> getFilesInFolder(Directory folder) {
    try {
      return folder.listSync(recursive: false).whereType<File>().toList()
        ..sort((a, b) => a.path.split('/').last.compareTo(b.path.split('/').last));
    } catch (e) {
      logger.e('Error listing files in folder: $e');
      return [];
    }
  }

  Future<void> deleteEntity(FileSystemEntity entity) async {
    if (!entity.existsSync()) return;
    if (entity is Directory) {
      await entity.delete(recursive: true);
    } else {
      await entity.delete();
    }
  }

  Future<void> shareFile(File file, {required Future<void> Function(String) onError}) async {
    try {
      final result = await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          subject: 'OpenWearable Recording File',
        ),
      );

      if (result.status == ShareResultStatus.success) {
        logger.i('File shared successfully');
      }
    } catch (e) {
      logger.e('Error sharing file: $e');
      await onError('Failed to share file: $e');
    }
  }

  Future<void> shareFolder(Directory folder, {required Future<void> Function(String) onError}) async {
    try {
      logger.i('Creating zip file for ${folder.path}...');

      final tempDir = await getTemporaryDirectory();
      final zipPath = '${tempDir.path}/${folder.path.split('/').last}.zip';
      final zipFile = File(zipPath);

      await ZipFile.createFromDirectory(
        sourceDir: folder,
        zipFile: zipFile,
        recurseSubDirs: true,
      );

      final result = await SharePlus.instance.share(
        ShareParams(
          files: [XFile(zipFile.path)],
          subject: 'OpenWearable Recording',
        ),
      );

      if (result.status == ShareResultStatus.success) {
        logger.i('Folder shared successfully');
      }

      if (await zipFile.exists()) {
        await zipFile.delete();
      }
    } catch (e) {
      logger.e('Error sharing folder: $e');
      await onError('Failed to share folder: $e');
    }
  }

  Future<void> openFolder(String path) async {
    try {
      if (Platform.isIOS) {
        await platformChannel.invokeMethod('openFolder', {'path': 'shareddocuments://$path'});
      } else if (Platform.isAndroid) {
        await platformChannel.invokeMethod('openFolder', {'path': path});
      }
    } on PlatformException catch (e) {
      logger.e("Failed to open folder: '${e.message}'.");
    }
  }

  Future<Directory?> _getRecordingsRootDirectory() async {
    if (Platform.isAndroid) {
      return await getExternalStorageDirectory();
    }
    if (Platform.isIOS) {
      return await getIOSDirectory();
    }
    return null;
  }
}

Future<Directory> getIOSDirectory() async {
  Directory appDocDir = await getApplicationDocumentsDirectory();
  final dirPath = '${appDocDir.path}/Recordings';
  final dir = Directory(dirPath);

  if (!await dir.exists()) {
    await dir.create(recursive: true);
  }

  return dir;
}
