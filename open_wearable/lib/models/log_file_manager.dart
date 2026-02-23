import 'dart:io'
    show Directory, File; // still fine as long as we don't use it on web

import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import 'package:path_provider/path_provider.dart';

class _CustomLogFilter extends LogFilter {
  _CustomLogFilter(this._minLevel);

  final Level _minLevel;

  @override
  bool shouldLog(LogEvent event) {
    if (event.level.index < _minLevel.index) return false;

    final msg = event.message.toString();

    return !(msg.contains('componentData') ||
        msg.contains('SensorData') ||
        msg.contains('Battery') ||
        msg.contains('Mantissa') ||
        (msg.toLowerCase().contains('sensor data') &&
            event.level == Level.trace) ||
        (msg.toLowerCase().contains('parsed') && event.level == Level.trace));
  }
}

/// Central logging service for app/runtime logs and persisted log files.
///
/// Needs:
/// - Logger package and (on non-web) writable app documents directory.
///
/// Does:
/// - Creates app/lib loggers with a shared output pipeline.
/// - Rotates and exposes log files.
/// - Notifies listeners when log file inventory changes.
///
/// Provides:
/// - `logger` and `libLogger` for runtime logging.
/// - File management APIs used by log viewer pages.
class LogFileManager with ChangeNotifier {
  final Logger _logger;
  final Logger _libLogger;

  // On web this will be null and never used.
  final LogOutput? _fileOutput;
  final String logDirectoryPath;

  Logger get logger => _logger;
  Logger get libLogger => _libLogger;

  LogFileManager._({
    required Logger logger,
    required Logger libLogger,
    required LogOutput? fileOutput,
    required this.logDirectoryPath,
  })  : _logger = logger,
        _libLogger = libLogger,
        _fileOutput = fileOutput;

  /// Async factory – call this once at startup.
  static Future<LogFileManager> create() async {
    // ------------------------
    // 1) Decide levels/printer
    // ------------------------
    late final Level level;
    LogPrinter printer;

    if (kDebugMode) {
      level = Level.trace;
      printer = PrettyPrinter();
    } else {
      level = Level.debug;
      printer = LogfmtPrinter();
    }

    final libFilter = _CustomLogFilter(level);
    LogOutput? fileOutput;
    String logDirPath = '';

    // ------------------------
    // 2) Configure outputs
    // ------------------------
    final List<LogOutput> outputs = [ConsoleOutput()];

    if (!kIsWeb) {
      // Only use file output on non-web platforms
      final cacheDir = await getApplicationDocumentsDirectory();
      logDirPath = '${cacheDir.path}/logs';
      final logDir = Directory(logDirPath);

      if (!await logDir.exists()) {
        await logDir.create(recursive: true);
      }

      final advanced = AdvancedFileOutput(
        path: logDirPath,
        maxFileSizeKB: 1024, // ~1 MB per file
        maxRotatedFilesCount: 5,
      );

      fileOutput = advanced;
      outputs.add(advanced);
    }

    final sharedOutput =
        outputs.length == 1 ? outputs.first : MultiOutput(outputs);

    // ------------------------
    // 3) Create loggers
    // ------------------------
    final logger = Logger(
      level: level,
      printer: PrefixPrinter(
        printer,
        trace: '[APP] TRACE',
        debug: '[APP] DEBUG',
        info: '[APP] INFO',
        warning: '[APP] WARN',
        error: '[APP] ERR',
        fatal: '[APP] FAT',
      ),
      output: sharedOutput,
    );

    final libLogger = Logger(
      level: level,
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
      output: sharedOutput,
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
    if (kIsWeb) {
      // No file system on web → no log files.
      return [];
    }

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
    if (kIsWeb) return;

    if (await file.exists()) {
      await file.delete();
      notifyListeners();
    }
  }

  Future<void> clearAllLogs() async {
    if (kIsWeb) return;

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
    // Only AdvancedFileOutput has destroy(); LogOutput in general doesn't.
    final fo = _fileOutput;
    if (fo is AdvancedFileOutput) {
      fo.destroy();
    }
    super.dispose();
  }
}
