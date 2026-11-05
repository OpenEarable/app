import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

typedef HrHrvDiagnosticSink = void Function(Map<String, Object?> event);

/// Explicitly opt in with --dart-define=MEDITATION_HR_HRV_TRACE=true on a
/// debug build. Release/profile builds never write physiological traces.
abstract final class HrHrvDiagnosticSettings {
  static const bool requested = bool.fromEnvironment('MEDITATION_HR_HRV_TRACE');
  static const bool summaryRequested =
      bool.fromEnvironment('MEDITATION_HR_HRV_SUMMARY_LOG');
  static const bool detectorComparisonRequested =
      bool.fromEnvironment('MEDITATION_DETECTOR_COMPARE_LOG');
  static const bool beatQualityRequested =
      bool.fromEnvironment('MEDITATION_BEAT_QUALITY_LOG');

  /// Records the actual PPG/IMU waveform so a session can be replayed offline.
  ///
  /// This writes considerably more than the decision-only trace, and the raw
  /// optical waveform is the most sensitive thing this app can persist. It is
  /// opt-in, debug-only, never uploaded, and implies [requested].
  static const bool signalCaptureRequested =
      bool.fromEnvironment('MEDITATION_CAPTURE_SIGNAL');

  static bool get enabled =>
      kDebugMode && (requested || signalCaptureRequested);
  static bool get summaryEnabled => kDebugMode && summaryRequested;
  static bool get detectorComparisonEnabled =>
      kDebugMode && detectorComparisonRequested;
  static bool get beatQualityEnabled => kDebugMode && beatQualityRequested;
  static bool get signalCaptureEnabled => kDebugMode && signalCaptureRequested;

  /// A decision-only trace stays small; a waveform capture needs room for a
  /// full session, so the limit is raised only when capture is on.
  static int get traceByteLimit =>
      signalCaptureEnabled ? 256 * 1024 * 1024 : 5 * 1024 * 1024;

  static void logSummary(String message) {
    if (summaryEnabled) debugPrint(message);
  }

  static void logDetectorComparison(String message) {
    if (detectorComparisonEnabled) debugPrint(message);
  }

  static void logBeatQuality(String message) {
    if (beatQualityEnabled) debugPrint(message);
  }
}

/// Buffers a sampled signal and emits one diagnostic event per block.
///
/// One JSONL line per sample at 200 Hz is neither readable nor compact enough
/// to survive a session, so samples are grouped and timestamps are stored as
/// offsets from the block's base. Values may be rounded, because the last
/// digits of a conditioned waveform carry no diagnostic information but do
/// multiply the file size.
class HrHrvSignalCapture {
  final String event;
  final List<String> channelNames;
  final int blockSize;
  final int? fractionDigits;

  final HrHrvDiagnosticSink _sink;
  final List<int> _timestamps = [];
  final List<List<double>> _channels;
  Map<String, Object?> _blockContext = const {};

  HrHrvSignalCapture({
    required this.event,
    required this.channelNames,
    required HrHrvDiagnosticSink sink,
    this.blockSize = 200,
    this.fractionDigits,
  })  : _sink = sink,
        _channels = List<List<double>>.generate(
          channelNames.length,
          (_) => <double>[],
          growable: false,
        );

  void add(
    int timestamp,
    List<double> values, {
    Map<String, Object?> context = const {},
  }) {
    _timestamps.add(timestamp);
    final digits = fractionDigits;
    for (var index = 0; index < _channels.length; index++) {
      final value = index < values.length ? values[index] : double.nan;
      _channels[index].add(
        digits == null || !value.isFinite
            ? value
            : double.parse(value.toStringAsFixed(digits)),
      );
    }
    if (context.isNotEmpty) _blockContext = context;
    if (_timestamps.length >= blockSize) flush();
  }

  void flush() {
    if (_timestamps.isEmpty) return;
    final base = _timestamps.first;
    _sink({
      'event': event,
      'base_timestamp_ticks': base,
      'timestamp_offsets_ticks': [
        for (final timestamp in _timestamps) timestamp - base,
      ],
      'sample_count': _timestamps.length,
      for (var index = 0; index < channelNames.length; index++)
        channelNames[index]: List<double>.of(_channels[index]),
      ..._blockContext,
    });
    _timestamps.clear();
    for (final channel in _channels) {
      channel.clear();
    }
  }
}

/// Writes processor decisions and, when signal capture is enabled, the sampled
/// waveform, to a local app-private JSONL file. Recording failures must never
/// interrupt a meditation or alter its values.
class HrHrvDiagnosticsRecorder {
  static const int _maximumPendingLines = 512;

  final int _maximumBytes;
  final Future<Directory> Function() _directoryProvider;
  final DateTime _startedAt;
  final List<String> _pendingLines = [];

  IOSink? _sink;
  Future<void>? _opening;
  String? _path;
  int _bytes = 0;
  bool _closed = false;
  bool _limitReached = false;

  HrHrvDiagnosticsRecorder({
    Future<Directory> Function()? directoryProvider,
    DateTime? startedAt,
    int? maximumBytes,
  })  : _directoryProvider =
            directoryProvider ?? getApplicationSupportDirectory,
        _startedAt = startedAt ?? DateTime.now(),
        _maximumBytes = maximumBytes ?? HrHrvDiagnosticSettings.traceByteLimit {
    _opening = _open();
  }

  String? get path => _path;

  void record(Map<String, Object?> event) {
    if (_closed || _limitReached) return;
    try {
      final line = jsonEncode({
        'schema': 1,
        'recorded_at': DateTime.now().toUtc().toIso8601String(),
        ...event.map((key, value) => MapEntry(key, _jsonSafe(value))),
      });
      final length = utf8.encode(line).length + 1;
      if (_bytes + length > _maximumBytes) {
        _limitReached = true;
        _writeLine(
          jsonEncode({
            'schema': 1,
            'event': 'trace_limit_reached',
            'maximum_bytes': _maximumBytes,
          }),
        );
        return;
      }
      _bytes += length;
      _writeLine(line);
    } catch (error) {
      // Diagnostics are observational; JSON or file errors cannot affect DSP.
      debugPrint('HR/HRV trace event could not be recorded: $error');
    }
  }

  Object? _jsonSafe(Object? value) {
    if (value is double && !value.isFinite) return value.toString();
    if (value is Iterable) return value.map(_jsonSafe).toList();
    if (value is Map) {
      return value
          .map((key, item) => MapEntry(key.toString(), _jsonSafe(item)));
    }
    return value;
  }

  void _writeLine(String line) {
    final sink = _sink;
    if (sink != null) {
      sink.writeln(line);
    } else if (_pendingLines.length < _maximumPendingLines) {
      _pendingLines.add(line);
    }
  }

  Future<void> _open() async {
    try {
      final support = await _directoryProvider();
      final directory = Directory('${support.path}/meditation_hr_hrv_traces');
      await directory.create(recursive: true);
      final stamp =
          _startedAt.toUtc().toIso8601String().replaceAll(RegExp(r'[:.]'), '-');
      final file = File('${directory.path}/hr_hrv_$stamp.jsonl');
      _sink = file.openWrite();
      // Handle asynchronous write errors immediately, not only when the
      // session eventually closes the sink.
      unawaited(
        _sink!.done.then<void>(
          (_) {},
          onError: (Object error, StackTrace stackTrace) {
            debugPrint('HR/HRV trace write failed: $error');
          },
        ),
      );
      _path = file.path;
      for (final line in _pendingLines) {
        _sink!.writeln(line);
      }
      _pendingLines.clear();
      debugPrint('HR/HRV diagnostic trace: $_path');
    } catch (error) {
      _pendingLines.clear();
      debugPrint('HR/HRV trace could not be opened: $error');
    }
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    try {
      await _opening;
      await _sink?.flush();
      await _sink?.close();
    } catch (error) {
      debugPrint('HR/HRV trace could not be closed: $error');
    }
    _pendingLines.clear();
  }
}
