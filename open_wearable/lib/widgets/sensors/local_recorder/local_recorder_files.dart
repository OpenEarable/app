import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

class Files {
  static Future<String?> pickDirectory() async {
    if (!Platform.isIOS && !kIsWeb) {
      final recordingName =
          'OpenWearable_Recording_${DateTime.now().toIso8601String()}';
      Directory? appDir = await getExternalStorageDirectory();
      if (appDir == null) return null;

      String dirPath = '${appDir.path}/$recordingName';
      Directory dir = Directory(dirPath);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      return dirPath;
    }

    if (Platform.isIOS) {
      final recordingName =
          'OpenWearable_Recording_${DateTime.now().toIso8601String()}';
      String dirPath = '${(await getIOSDirectory()).path}/$recordingName';
      Directory dir = Directory(dirPath);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      return dirPath;
    }

    return null;
  }

  static Future<Directory> getIOSDirectory() async {
    Directory appDocDir = await getApplicationDocumentsDirectory();
    final dirPath = '${appDocDir.path}/Recordings';
    final dir = Directory(dirPath);

    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    return dir;
  }

  static Future<bool> isDirectoryEmpty(String path) async {
    final dir = Directory(path);
    if (!await dir.exists()) return true;
    return await dir.list(followLinks: false).isEmpty;
  }
}
