import 'dart:io';

import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:path_provider/path_provider.dart';

class LogFileManager with ChangeNotifier {
  final Logger logger;
  final AdvancedFileOutput _fileOutput;
  final String logDirectoryPath;

  LogFileManager._({
    required this.logger,
    required AdvancedFileOutput fileOutput,
    required this.logDirectoryPath,
  }) : _fileOutput = fileOutput;

  /// Async factory – call this once at startup.
  static Future<LogFileManager> create({LogFilter? filter}) async {
    final cacheDir = await getApplicationDocumentsDirectory();
    final logDirPath = '${cacheDir.path}/logs';
    final logDir = Directory(logDirPath);

    if (!await logDir.exists()) {
      await logDir.create(recursive: true);
    }

    final fileOutput = AdvancedFileOutput(
      path: logDirPath,
      maxFileSizeKB: 1024,        // ~1 MB per file
      maxRotatedFilesCount: 5,    // keep last 5 (tune as needed)
    );

    final logger = Logger(
      filter: filter,
      printer: PrettyPrinter(),
      output: MultiOutput([
        ConsoleOutput(),
        fileOutput,
      ]),
    );

    return LogFileManager._(
      logger: logger,
      fileOutput: fileOutput,
      logDirectoryPath: logDirPath,
    );
  }

  /// Returns all `.log` files in the log directory (newest first).
  Future<List<File>> get logFiles async {
    final logDir = Directory(logDirectoryPath);
    if (!await logDir.exists()) return [];

    final entities = await logDir
        .list()
        .where((e) => e is File && e.path.endsWith('.log'))
        .toList();

    final files = entities.cast<File>();

    files.sort(
      (a, b) => b.statSync().modified.compareTo(a.statSync().modified),
    );

    return files;
  }

  Future<void> deleteLogFile(File file) async {
    if (await file.exists()) {
      await file.delete();
      notifyListeners();
    }
  }

  Future<void> clearAllLogs() async {
    final files = await logFiles;
    for (final file in files) {
      if (await file.exists()) {
        await file.delete();
      }
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _fileOutput.destroy(); // flush & close
    super.dispose();
  }
}
