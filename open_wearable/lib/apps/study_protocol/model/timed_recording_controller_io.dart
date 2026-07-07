import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:open_wearable/models/logger.dart';

import 'study_device_recorder.dart';
import 'study_devices.dart';
import 'study_recording_status.dart';

/// Controls one fixed-duration recording phase (baseline, treadmill).
///
/// Delegates the physiological recording (OpenEarable SD + RespiBAN CSV) to a
/// [StudyDeviceRecorder] and adds the countdown that stops recording
/// automatically when [duration] elapses. File naming is scoped to the phase via
/// [respibanFileLabel] / [earablePrefixSuffix] so every phase in a session has
/// its own recording inside the shared session directory.
class TimedRecordingController extends ChangeNotifier {
  /// Length of the phase.
  final Duration duration;

  /// RespiBAN CSV file label for this phase (e.g. `baseline`).
  final String respibanFileLabel;

  /// OpenEarable file-prefix suffix for this phase (e.g. `base_`).
  final String earablePrefixSuffix;

  final StudyDeviceRecorder _recorder = StudyDeviceRecorder();

  Timer? _ticker;
  DateTime? _startTime;
  StudyRecordingStatus _status = StudyRecordingStatus.idle;
  int? _respibanFileSizeBytes;
  int? _respibanFileSizeDeltaBytes;
  Future<void>? _respibanFileSizeRefresh;
  bool _disposed = false;

  TimedRecordingController({
    required this.duration,
    this.respibanFileLabel = '',
    this.earablePrefixSuffix = '',
  });

  /// Current lifecycle state of the phase.
  StudyRecordingStatus get status => _status;

  /// Non-fatal warning raised while configuring devices, if any.
  String? get warning => _recorder.warning;

  /// Latest actual phone-side RespiBAN CSV size, refreshed while recording.
  int? get respibanFileSizeBytes => _respibanFileSizeBytes;

  /// File-size growth observed since the previous refresh.
  int? get respibanFileSizeDeltaBytes => _respibanFileSizeDeltaBytes;

  /// Whether the phase is currently recording.
  bool get isRecording => _status == StudyRecordingStatus.recording;

  /// Time remaining in the countdown.
  Duration get remaining {
    final start = _startTime;
    if (start == null || _status != StudyRecordingStatus.recording) {
      return duration;
    }
    final elapsed = DateTime.now().difference(start);
    final left = duration - elapsed;
    return left.isNegative ? Duration.zero : left;
  }

  /// Fraction of the phase that has elapsed, in the range `[0, 1]`.
  double get progress {
    final total = duration.inMilliseconds;
    if (total == 0) {
      return 0;
    }
    final done = duration.inMilliseconds - remaining.inMilliseconds;
    return (done / total).clamp(0.0, 1.0);
  }

  /// Starts recording into [directory] for [probandId] using [deviceSet].
  ///
  /// Throws if a recording is already running.
  Future<void> start({
    required String probandId,
    required StudyDeviceSet deviceSet,
    required String directory,
  }) async {
    if (_status == StudyRecordingStatus.recording) {
      throw StateError('A recording is already in progress');
    }

    _status = StudyRecordingStatus.recording;
    _startTime = null;
    notifyListeners();

    try {
      final firstRespibanSampleAt = await _recorder.start(
        deviceSet: deviceSet,
        directory: directory,
        probandId: probandId,
        respibanFileLabel: respibanFileLabel,
        earablePrefixSuffix: earablePrefixSuffix,
      );

      _startTime = firstRespibanSampleAt;
      await _refreshRespibanFileSize();
      _ticker = Timer.periodic(const Duration(seconds: 1), _onTick);
      notifyListeners();
    } catch (e, st) {
      logger.e('Failed to start recording phase: $e\n$st');
      await _teardown();
      _status = StudyRecordingStatus.idle;
      _startTime = null;
      notifyListeners();
      rethrow;
    }
  }

  void _onTick(Timer timer) {
    if (_disposed) {
      return;
    }
    if (remaining <= Duration.zero) {
      unawaited(stop());
      return;
    }
    unawaited(_refreshRespibanFileSize());
    notifyListeners();
  }

  /// Stops recording on all devices and finalizes the CSV files.
  Future<void> stop() async {
    if (_status != StudyRecordingStatus.recording) {
      return;
    }
    await _teardown();
    await _refreshRespibanFileSize();
    _status = StudyRecordingStatus.completed;
    _startTime = null;
    notifyListeners();
  }

  Future<void> _refreshRespibanFileSize() {
    final activeRefresh = _respibanFileSizeRefresh;
    if (activeRefresh != null) {
      return activeRefresh;
    }
    final refresh = _doRefreshRespibanFileSize().whenComplete(() {
      _respibanFileSizeRefresh = null;
    });
    _respibanFileSizeRefresh = refresh;
    return refresh;
  }

  Future<void> _doRefreshRespibanFileSize() async {
    try {
      final previous = _respibanFileSizeBytes;
      final current = await _recorder.respibanFileSizeBytes();
      if (current == null) {
        return;
      }
      _respibanFileSizeBytes = current;
      _respibanFileSizeDeltaBytes =
          previous == null ? null : current - previous;
      if (!_disposed) {
        notifyListeners();
      }
    } catch (e, st) {
      logger.w('Failed to refresh RespiBAN file size: $e\n$st');
    }
  }

  Future<void> _teardown() async {
    _ticker?.cancel();
    _ticker = null;
    await _respibanFileSizeRefresh;
    await _recorder.stop();
  }

  @override
  void dispose() {
    _disposed = true;
    if (_status == StudyRecordingStatus.recording) {
      unawaited(_teardown());
    } else {
      _ticker?.cancel();
    }
    super.dispose();
  }
}
