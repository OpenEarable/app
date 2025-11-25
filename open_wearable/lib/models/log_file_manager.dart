import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import 'package:path_provider/path_provider.dart';

class _CustomLogFilter extends LogFilter {
  @override
  bool shouldLog(LogEvent event) {
    return !(event.message.contains('componentData') ||
        event.message.contains('SensorData') ||
        event.message.contains('Battery') ||
        event.message.contains('Mantissa'));
  }
}

class LogFileManager with ChangeNotifier {
  final Logger _logger;
  final Logger _libLogger;
  final AdvancedFileOutput _fileOutput;
  final String logDirectoryPath;

  Logger get logger => _logger;
  Logger get libLogger => _libLogger;

  LogFileManager._({
    required Logger logger,
    required Logger libLogger,
    required AdvancedFileOutput fileOutput,
    required this.logDirectoryPath,
  })  : _logger = logger,
        _libLogger = libLogger,
        _fileOutput = fileOutput;

  /// Async factory – call this once at startup.
  static Future<LogFileManager> create() async {
    final cacheDir = await getApplicationDocumentsDirectory();
    final logDirPath = '${cacheDir.path}/logs';
    final logDir = Directory(logDirPath);

    if (!await logDir.exists()) {
      await logDir.create(recursive: true);
    }

    final fileOutput = AdvancedFileOutput(
      path: logDirPath,
      maxFileSizeKB: 1024, // ~1 MB per file
      maxRotatedFilesCount: 5, // keep last 5 (tune as needed)
    );

    LogFilter? filter;
    LogFilter? libFilter;

    LogPrinter printer = PrettyPrinter();

    if (kDebugMode) {
      libFilter = _CustomLogFilter();
    } else {
      filter = ProductionFilter();
      libFilter = ProductionFilter();
      printer = LogfmtPrinter();
    }

    final logger = Logger(
      filter: filter,
      printer: PrefixPrinter(
        printer,
        trace: '[APP] TRACE',
        debug: '[APP] DEBUG',
        info: '[APP] INFO',
        warning: '[APP] WARN',
        error: '[APP] ERR',
        fatal: '[APP] FAT',
      ),
      output: MultiOutput([
        ConsoleOutput(),
        fileOutput,
      ]),
    );

    final libLogger = Logger(
      filter: libFilter,
      printer: PrefixPrinter(
        printer,
        trace: '[LIB] TRACE',
        debug: '[LIB] DEBUG',
        info: '[LIB] INFO',
        warning: '[LIB] WARN',
        error: '[LIB] ERR',
        fatal: '[LIB] FAT',
      ),
      output: MultiOutput([
        ConsoleOutput(),
        fileOutput,
      ]),
    );

    return LogFileManager._(
      logger: logger,
      libLogger: libLogger,
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
