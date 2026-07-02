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
/// recording (OpenEarable SD + RESPIRABAN CSV) runs continuously via a
/// [StudyDeviceRecorder]; the manual heart-rate/wattage measurements are logged
/// to a separate CSV.
class YmcaErgometerController extends ChangeNotifier {
  /// Interval between measurement prompts.
  static const Duration measurementInterval = Duration(minutes: 1);

  final StudySession session;
  final StudyDeviceSet deviceSet;
  final String directory;

  final StudyDeviceRecorder _recorder = StudyDeviceRecorder();
  IOSink? _logSink;

  final List<ErgoMeasurement> _measurements = [];
  final Queue<int> _dueMeasurements = Queue<int>();

  Timer? _ticker;
  DateTime? _startTime;
  DateTime? _nextDueTime;
  int _measurementCounter = 0;

  ErgoStatus _status = ErgoStatus.idle;
  int _currentStage = 0;
  int? _currentTargetWatt;
  int _measurementsInStage = 0;
  bool _firstStabilizationDone = false;
  String? _pendingStageMessage;
  bool _endSuggested = false;
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

  /// Minute index of the measurement currently awaiting entry, if any.
  int? get dueMeasurementMinute =>
      _dueMeasurements.isEmpty ? null : _dueMeasurements.first;

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

  /// Non-fatal recording warning, if any.
  String? get warning => _recorder.warning;

  /// Starts recording and the measurement clock.
  Future<void> start() async {
    if (_status != ErgoStatus.idle) {
      return;
    }
    _status = ErgoStatus.running;
    notifyListeners();

    try {
      await _recorder.start(
        deviceSet: deviceSet,
        directory: directory,
        probandId: session.probandId,
        respibanFileLabel: 'ergometer',
        earablePrefixSuffix: 'ergo_',
      );
      await _openLog();

      _startTime = DateTime.now();
      _nextDueTime = _startTime!.add(measurementInterval);
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
    final latestHeartRate =
        _measurements.isEmpty ? null : _measurements.last.heartRate;
    _advanceStage(latestHeartRate);
    notifyListeners();
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

  /// Ends the test, records the [endHeartRate] and stops recording.
  Future<void> end({required int endHeartRate}) async {
    if (_status == ErgoStatus.ended) {
      return;
    }
    _writeLog('end,,$_currentStage,,,$endHeartRate');
    await _teardown();
    _status = ErgoStatus.ended;
    notifyListeners();
  }

  /// Skips the test without an end heart rate and stops recording.
  Future<void> skip() async {
    if (_status == ErgoStatus.ended) {
      return;
    }
    _writeLog('skipped,,$_currentStage,,,');
    await _teardown();
    _status = ErgoStatus.ended;
    notifyListeners();
  }

  Future<void> _openLog() async {
    final token = sanitizeProbandId(session.probandId);
    final file = File('$directory/${token}_ergometer.csv');
    await file.parent.create(recursive: true);
    final sink = file.openWrite();
    sink.writeln(
      '# proband=${session.probandId}, age=${session.age}, '
      'hr_max=$maxHeartRate, hr_submax=$submaxHeartRate',
    );
    sink.writeln('event,elapsed_min,stage,target_watt,actual_watt,heart_rate');
    _logSink = sink;
  }

  void _writeLog(String row) {
    _logSink?.writeln(row);
  }

  Future<void> _teardown() async {
    _ticker?.cancel();
    _ticker = null;
    _dueMeasurements.clear();

    await _logSink?.flush();
    await _logSink?.close();
    _logSink = null;

    await _recorder.stop();
  }

  @override
  void dispose() {
    _disposed = true;
    if (_status == ErgoStatus.running) {
      unawaited(_teardown());
    } else {
      _ticker?.cancel();
    }
    super.dispose();
  }
}
