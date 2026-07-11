import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'package:open_wearable/models/logger.dart';

import 'study_device_recorder.dart';
import 'study_devices.dart';
import 'study_protocol_storage.dart';
import 'study_session.dart';
import 'ymca_models.dart';

/// Drives the modified YMCA ergometer test.
///
/// Runs a fixed 1-minute measurement clock (the next timer starts in the
/// background the moment one elapses, independent of data entry), tracks stage
/// progression and computes the wattage to set for each new stage. Physiological
/// recording (OpenEarable SD + RespiBAN CSV) runs continuously via a
/// [StudyDeviceRecorder]; the manual heart-rate/wattage measurements are logged
/// to a separate CSV.
///
/// Ending the test does not stop recording: it transitions into a fixed-length
/// recovery phase (see [ymcaRecoveryDuration]) that keeps every device
/// recording into the same files. Only the start of the recovery is labelled in
/// the log. When the recovery countdown elapses (or is finished/skipped by the
/// experimenter) recording is stopped and the test reaches [ErgoStatus.ended].
class YmcaErgometerController extends ChangeNotifier {
  /// Interval between measurement prompts.
  static const Duration defaultMeasurementInterval = Duration(minutes: 1);

  /// Length of the recovery phase that runs after the test ends.
  static const Duration defaultRecoveryDuration = ymcaRecoveryDuration;

  final StudySession session;
  final StudyDeviceSet deviceSet;
  final String directory;

  final StudyDeviceRecorder _recorder = StudyDeviceRecorder();
  IOSink? _logSink;

  final List<ErgoMeasurement> _measurements = [];
  final Queue<int> _dueMeasurements = Queue<int>();
  final List<_ErgoSnapshot> _undoStack = [];

  Timer? _ticker;
  DateTime? _startTime;
  DateTime? _nextDueTime;
  int _measurementCounter = 0;

  Timer? _recoveryTicker;
  DateTime? _recoveryStartTime;
  bool _recoveryFinished = false;
  bool _recoveryEndLogged = false;

  int? _respibanFileSizeBytes;
  int? _respibanFileSizeDeltaBytes;
  Future<void>? _respibanFileSizeRefresh;
  Future<void>? _stopRecorderFuture;

  ErgoStatus _status = ErgoStatus.idle;
  int _currentStage = 0;
  int? _currentTargetWatt;
  int _measurementsInStage = 0;
  bool _firstStabilizationDone = false;
  String? _pendingStageMessage;
  bool _endSuggested = false;
  bool _recorderStopped = false;
  String? _stopError;
  bool _disposed = false;

  YmcaErgometerController({
    required this.session,
    required this.deviceSet,
    required this.directory,
  });

  /// Current lifecycle state.
  ErgoStatus get status => _status;

  /// 85% submaximal target heart rate (the abort target), always shown.
  int get submaxHeartRate => session.submaxHeartRate;

  /// Age-predicted maximum heart rate.
  int get maxHeartRate => session.maxHeartRate;

  /// Current stage index (0 = warm-up).
  int get currentStage => _currentStage;

  /// App-suggested wattage for the current stage (null during the warm-up).
  int? get currentTargetWatt => _currentTargetWatt;

  /// Chronological list of recorded measurements.
  List<ErgoMeasurement> get measurements =>
      List<ErgoMeasurement>.unmodifiable(_measurements);

  /// Whether a measurement is due and waiting for the experimenter to enter it.
  bool get isMeasurementDue => _dueMeasurements.isNotEmpty;

  /// Whether the last measurement or manual stage change can be undone.
  bool get canUndo => _status == ErgoStatus.running && _undoStack.isNotEmpty;

  /// Minute index of the measurement currently awaiting entry, if any.
  int? get dueMeasurementMinute =>
      _dueMeasurements.isEmpty ? null : _dueMeasurements.first;

  Duration get measurementInterval => session.timerTestMode
      ? StudySession.testModeTimerDuration
      : defaultMeasurementInterval;

  Duration get recoveryDuration => session.timerTestMode
      ? StudySession.testModeTimerDuration
      : defaultRecoveryDuration;

  /// Total time elapsed since the test started.
  Duration get elapsed {
    final start = _startTime;
    if (start == null) {
      return Duration.zero;
    }
    return DateTime.now().difference(start);
  }

  Duration _elapsedAt(DateTime timestamp) {
    final start = _startTime;
    if (start == null) {
      return Duration.zero;
    }
    final elapsed = timestamp.difference(start);
    return elapsed.isNegative ? Duration.zero : elapsed;
  }

  /// Time until the next scheduled measurement prompt.
  Duration get timeToNextMeasurement {
    final next = _nextDueTime;
    if (next == null || _status != ErgoStatus.running) {
      return measurementInterval;
    }
    final left = next.difference(DateTime.now());
    return left.isNegative ? Duration.zero : left;
  }

  /// Message describing a newly reached stage and its wattage, if pending.
  String? get pendingStageMessage => _pendingStageMessage;

  /// Whether the last entered heart rate reached the submaximal target.
  bool get endSuggested => _endSuggested;

  /// Time remaining in the recovery countdown.
  Duration get recoveryRemaining {
    final start = _recoveryStartTime;
    if (start == null || _status != ErgoStatus.recovering) {
      return recoveryDuration;
    }
    final left = recoveryDuration - DateTime.now().difference(start);
    return left.isNegative ? Duration.zero : left;
  }

  /// Fraction of the recovery phase that has elapsed, in the range `[0, 1]`.
  double get recoveryProgress {
    final total = recoveryDuration.inMilliseconds;
    if (total == 0) {
      return 0;
    }
    final done =
        recoveryDuration.inMilliseconds - recoveryRemaining.inMilliseconds;
    return (done / total).clamp(0.0, 1.0);
  }

  /// Whether the recovery countdown has elapsed and recording has stopped, so
  /// the experimenter can continue to the next phase.
  bool get isRecoveryFinished => _recoveryFinished;

  /// Non-fatal recording warning, if any.
  String? get warning {
    final messages = [
      if (_recorder.warning != null) _recorder.warning!,
      if (_stopError != null) _stopError!,
    ];
    return messages.isEmpty ? null : messages.join('\n');
  }

  /// Latest actual phone-side RespiBAN CSV size, refreshed while recording.
  int? get respibanFileSizeBytes => _respibanFileSizeBytes;

  /// File-size growth observed since the previous refresh.
  int? get respibanFileSizeDeltaBytes => _respibanFileSizeDeltaBytes;

  /// Starts recording and the measurement clock.
  Future<void> start() async {
    if (_status != ErgoStatus.idle) {
      return;
    }
    _stopError = null;
    _status = ErgoStatus.running;
    notifyListeners();

    try {
      final firstRespibanSampleAt = await _recorder.start(
        deviceSet: deviceSet,
        directory: directory,
        probandId: session.probandId,
        respibanFileLabel: 'ergometer',
        earablePrefixSuffix: 'ergo_',
      );
      await _openLog();

      _startTime = firstRespibanSampleAt;
      _nextDueTime = _startTime!.add(measurementInterval);
      await _refreshRespibanFileSize();
      _ticker = Timer.periodic(const Duration(seconds: 1), _onTick);
      notifyListeners();
    } catch (e, st) {
      logger.e('Failed to start ergometer test: $e\n$st');
      await _teardown();
      _status = ErgoStatus.idle;
      notifyListeners();
      rethrow;
    }
  }

  void _onTick(Timer timer) {
    if (_disposed || _status != ErgoStatus.running) {
      return;
    }
    final now = DateTime.now();
    // Schedule every elapsed minute boundary, so the next timer always runs in
    // the background regardless of how long data entry takes.
    var scheduledNew = false;
    while (_nextDueTime != null && !now.isBefore(_nextDueTime!)) {
      _measurementCounter += 1;
      _dueMeasurements.add(_measurementCounter);
      _nextDueTime = _nextDueTime!.add(measurementInterval);
      scheduledNew = true;
    }
    if (scheduledNew) {
      logger.d('Ergometer measurement due: minute $_measurementCounter');
    }
    unawaited(_refreshRespibanFileSize());
    notifyListeners();
  }

  /// Records the measurement currently due with the entered [heartRate] and
  /// [actualWatt], then evaluates stage advancement and the abort target.
  Future<void> submitMeasurement({
    required int heartRate,
    required int actualWatt,
  }) async {
    if (_status != ErgoStatus.running || _dueMeasurements.isEmpty) {
      return;
    }
    final minute = _dueMeasurements.removeFirst();
    final previous = _measurements.isEmpty ? null : _measurements.last;

    // Snapshot pre-measurement state so this step can be undone.
    _pushUndoSnapshot(dueMinute: minute, removedMeasurement: true);

    final measurement = ErgoMeasurement(
      minute: minute,
      stage: _currentStage,
      targetWatt: _currentTargetWatt,
      actualWatt: actualWatt,
      heartRate: heartRate,
    );
    _measurements.add(measurement);
    _measurementsInStage += 1;
    _writeLog(
      'measurement,$minute,$_currentStage,${_currentTargetWatt ?? ''},'
      '$actualWatt,$heartRate',
    );

    // Advance when the stage has run at least three minutes and the heart rate
    // is steady versus the previous minute (<= 5 BPM change).
    if (_measurementsInStage >= ymcaMinMeasurementsPerStage &&
        previous != null &&
        (heartRate - previous.heartRate).abs() <= ymcaSteadyStateBpmTolerance) {
      _advanceStage(heartRate);
    }

    // Abort target reached: suggest ending the measurement.
    if (heartRate >= submaxHeartRate) {
      _endSuggested = true;
    }

    notifyListeners();
  }

  /// Advances to the next stage manually (experimenter override).
  void manualNextStage() {
    if (_status != ErgoStatus.running) {
      return;
    }
    // Snapshot pre-change state so the manual advance can be undone.
    _pushUndoSnapshot(dueMinute: null, removedMeasurement: false);
    final latestHeartRate =
        _measurements.isEmpty ? null : _measurements.last.heartRate;
    _advanceStage(latestHeartRate);
    notifyListeners();
  }

  /// Undoes the last measurement or manual stage change.
  ///
  /// Reverts stage/target/counter state and, when a measurement was undone,
  /// re-queues that minute so its value can be re-entered — for example to
  /// repeat a stage. The correction is also logged for the record.
  void undoLastMeasurement() {
    if (_status != ErgoStatus.running || _undoStack.isEmpty) {
      return;
    }
    final snapshot = _undoStack.removeLast();
    if (snapshot.removedMeasurement && _measurements.isNotEmpty) {
      _measurements.removeLast();
    }
    _currentStage = snapshot.stage;
    _currentTargetWatt = snapshot.targetWatt;
    _measurementsInStage = snapshot.measurementsInStage;
    _firstStabilizationDone = snapshot.firstStabilizationDone;
    _pendingStageMessage = snapshot.pendingStageMessage;
    _endSuggested = snapshot.endSuggested;
    if (snapshot.dueMinute != null) {
      _dueMeasurements.addFirst(snapshot.dueMinute!);
    }
    _writeLog('undo,${snapshot.dueMinute ?? ''},$_currentStage,,,');
    notifyListeners();
  }

  void _pushUndoSnapshot({
    required int? dueMinute,
    required bool removedMeasurement,
  }) {
    _undoStack.add(
      _ErgoSnapshot(
        dueMinute: dueMinute,
        removedMeasurement: removedMeasurement,
        stage: _currentStage,
        targetWatt: _currentTargetWatt,
        measurementsInStage: _measurementsInStage,
        firstStabilizationDone: _firstStabilizationDone,
        pendingStageMessage: _pendingStageMessage,
        endSuggested: _endSuggested,
      ),
    );
  }

  void _advanceStage(int? heartRate) {
    final int nextWatt;
    if (!_firstStabilizationDone) {
      // First stabilized level: derive the workload from the heart rate.
      nextWatt = heartRate == null
          ? ymcaInitialWattForHeartRate(submaxHeartRate)
          : ymcaInitialWattForHeartRate(heartRate);
      _firstStabilizationDone = true;
    } else {
      nextWatt = (_currentTargetWatt ?? 0) + ymcaStageIncrementWatt;
    }

    _currentStage += 1;
    _currentTargetWatt = nextWatt;
    _measurementsInStage = 0;
    _pendingStageMessage = 'Next stage: set $nextWatt W';
    _writeLog('stage_change,,$_currentStage,$nextWatt,,');
  }

  /// Clears the pending stage message after it has been shown.
  void acknowledgeStageMessage() {
    if (_pendingStageMessage == null) {
      return;
    }
    _pendingStageMessage = null;
    notifyListeners();
  }

  /// Dismisses the end suggestion without ending the test.
  void dismissEndSuggestion() {
    if (!_endSuggested) {
      return;
    }
    _endSuggested = false;
    notifyListeners();
  }

  /// Ends the measurement part of the test, records the [endHeartRate] and
  /// transitions into the recovery phase.
  ///
  /// Recording keeps running on all devices; only the start of the recovery is
  /// labelled. The recovery countdown starts immediately.
  Future<void> end({required int endHeartRate}) async {
    if (_status != ErgoStatus.running) {
      return;
    }
    _writeLog('end,,$_currentStage,,,$endHeartRate');

    // Stop the measurement clock but keep recording: the recovery phase runs on
    // the same devices and files, only its start is labelled.
    _ticker?.cancel();
    _ticker = null;
    _dueMeasurements.clear();
    _undoStack.clear();
    _endSuggested = false;
    _pendingStageMessage = null;

    _status = ErgoStatus.recovering;
    final recoveryStartedAt = DateTime.now();
    final recoveryStartedElapsed = _elapsedAt(recoveryStartedAt);
    _recoveryStartTime = recoveryStartedAt;
    _writeLog(
      'recovery_start,${recoveryStartedElapsed.inMinutes},$_currentStage,,,',
      timestamp: recoveryStartedAt,
      preciseElapsed: recoveryStartedElapsed,
    );
    _recoveryTicker = Timer.periodic(
      const Duration(seconds: 1),
      _onRecoveryTick,
    );
    notifyListeners();
  }

  void _onRecoveryTick(Timer timer) {
    if (_disposed || _status != ErgoStatus.recovering) {
      return;
    }
    if (recoveryRemaining <= Duration.zero) {
      unawaited(_completeRecovery());
      return;
    }
    unawaited(_refreshRespibanFileSize());
    notifyListeners();
  }

  /// Called when the recovery countdown elapses: stops recording at the clean
  /// 15-minute boundary but keeps the [ErgoStatus.recovering] state so the
  /// experimenter still has to confirm before moving on.
  Future<void> _completeRecovery() async {
    if (_recoveryFinished) {
      return;
    }
    _recoveryTicker?.cancel();
    _recoveryTicker = null;
    _writeRecoveryEndOnce();
    try {
      await _stopRecorderOnce();
      _recoveryFinished = true;
      _stopError = null;
      await _refreshRespibanFileSize();
      notifyListeners();
    } catch (e, st) {
      _stopError = 'Failed to stop recording on all devices: $e';
      logger.e('Failed to complete ergometer recovery: $e\n$st');
      notifyListeners();
    }
  }

  /// Finishes the recovery phase (countdown elapsed or skipped early) and stops
  /// recording if it is still running.
  ///
  /// The controller intentionally keeps [ErgoStatus.recovering] with
  /// [_recoveryFinished] set so the UI can show the completed recovery state.
  /// Advancing to the end seal check remains an explicit "Next" action, just
  /// like the fixed-duration phases.
  Future<void> finishRecovery() async {
    if (_status != ErgoStatus.recovering) {
      return;
    }
    if (_recoveryFinished) {
      return;
    }
    _recoveryTicker?.cancel();
    _recoveryTicker = null;
    _writeRecoveryEndOnce();
    try {
      await _teardown();
      await _refreshRespibanFileSize();
      _recoveryFinished = true;
      _stopError = null;
      notifyListeners();
    } catch (e, st) {
      _stopError = 'Failed to stop recording on all devices: $e';
      logger.e('Failed to finish ergometer recovery: $e\n$st');
      notifyListeners();
      rethrow;
    }
  }

  /// Skips the test without an end heart rate and stops recording.
  ///
  /// Works both while the measurements are running and during recovery.
  Future<void> skip() async {
    if (_status == ErgoStatus.ended) {
      return;
    }
    _writeLog('skipped,,$_currentStage,,,');
    try {
      await _teardown();
      await _refreshRespibanFileSize();
      _stopError = null;
      _status = ErgoStatus.ended;
      notifyListeners();
    } catch (e, st) {
      _stopError = 'Failed to stop recording on all devices: $e';
      logger.e('Failed to skip ergometer test: $e\n$st');
      notifyListeners();
      rethrow;
    }
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

  Future<void> _openLog() async {
    final token = sanitizeProbandId(session.probandId);
    final path = await uniqueStudyFilePath(directory, '${token}_ergometer.csv');
    final file = File(path);
    await file.parent.create(recursive: true);
    final sink = file.openWrite();
    sink.writeln(
      '# proband=${session.probandId}, age=${session.age}, '
      'hr_max=$maxHeartRate, hr_submax=$submaxHeartRate, '
      'timer_test_mode=${session.timerTestMode}',
    );
    sink.writeln(
      'event,elapsed_min,stage,target_watt,actual_watt,heart_rate,'
      'elapsed_ms,timestamp_iso',
    );
    _logSink = sink;
  }

  void _writeLog(
    String row, {
    DateTime? timestamp,
    Duration? preciseElapsed,
  }) {
    final logTimestamp = timestamp ?? DateTime.now();
    final logElapsed = preciseElapsed ?? _elapsedAt(logTimestamp);
    _logSink?.writeln(
      '$row,${logElapsed.inMilliseconds},${logTimestamp.toIso8601String()}',
    );
  }

  void _writeRecoveryEndOnce() {
    if (_recoveryEndLogged) {
      return;
    }
    _writeLog('recovery_end,${elapsed.inMinutes},$_currentStage,,,');
    _recoveryEndLogged = true;
  }

  Future<void> _teardown() async {
    _ticker?.cancel();
    _ticker = null;
    _recoveryTicker?.cancel();
    _recoveryTicker = null;
    _dueMeasurements.clear();
    _undoStack.clear();
    await _respibanFileSizeRefresh;
    await _stopRecorderOnce();
  }

  /// Closes the log file and stops all device recording, at most once.
  Future<void> _stopRecorderOnce() async {
    if (_recorderStopped) {
      return;
    }
    final activeStop = _stopRecorderFuture;
    if (activeStop != null) {
      return activeStop;
    }

    final stop = _doStopRecorderOnce().whenComplete(() {
      _stopRecorderFuture = null;
    });
    _stopRecorderFuture = stop;
    return stop;
  }

  Future<void> _doStopRecorderOnce() async {
    await _logSink?.flush();
    await _logSink?.close();
    _logSink = null;

    await _recorder.stop();
    _recorderStopped = true;
  }

  @override
  void dispose() {
    _disposed = true;
    if (_status == ErgoStatus.running || _status == ErgoStatus.recovering) {
      unawaited(_teardown());
    } else {
      _ticker?.cancel();
      _recoveryTicker?.cancel();
    }
    super.dispose();
  }
}

/// Captured controller state used to undo a measurement or manual stage change.
class _ErgoSnapshot {
  final int? dueMinute;
  final bool removedMeasurement;
  final int stage;
  final int? targetWatt;
  final int measurementsInStage;
  final bool firstStabilizationDone;
  final String? pendingStageMessage;
  final bool endSuggested;

  const _ErgoSnapshot({
    required this.dueMinute,
    required this.removedMeasurement,
    required this.stage,
    required this.targetWatt,
    required this.measurementsInStage,
    required this.firstStabilizationDone,
    required this.pendingStageMessage,
    required this.endSuggested,
  });
}
