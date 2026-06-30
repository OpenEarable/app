import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart' hide logger;
import 'package:wakelock_plus/wakelock_plus.dart';

import 'package:open_wearable/models/logger.dart';
import 'package:open_wearable/models/sensor_streams.dart';

import 'study_devices.dart';
import 'study_protocol_storage.dart';
import 'study_recording_status.dart';

/// Orchestrates a single guided 5-minute baseline recording.
///
/// Needs:
/// - A resolved [StudyDeviceSet] (OpenEarable pair + RESPIRABAN).
/// - A writable session directory for the phone-side RESPIRABAN CSV files.
///
/// Does:
/// - Starts the RESPIRABAN in Belt + IMU mode and records its sensor streams to
///   CSV on the phone, in the same format as the Local Recorder.
/// - Configures the OpenEarable pair to record microphone (8000 Hz) and IMU
///   (100 Hz) to each earable's own SD card, without streaming, prefixed with
///   `left_<id>` / `right_<id>`.
/// - Runs a 5-minute countdown and stops both devices automatically when it
///   elapses.
///
/// Provides:
/// - Recording status and remaining time for the baseline UI.
class StudyRecordingController extends ChangeNotifier {
  /// Duration of the guided baseline step.
  static const Duration baselineDuration = Duration(minutes: 5);

  /// Target microphone sample rate for OpenEarable SD-card recording.
  static const int microphoneFrequencyHz = 8000;

  /// Target IMU sample rate for OpenEarable SD-card recording.
  static const int imuFrequencyHz = 100;

  final Map<Sensor, Recorder> _respibanRecorders = {};
  final List<_AppliedEarableConfig> _appliedEarableConfigs = [];

  SensorConfiguration? _respibanConfiguration;

  Timer? _ticker;
  DateTime? _startTime;
  StudyRecordingStatus _status = StudyRecordingStatus.idle;
  String? _probandId;
  String? _sessionDirectory;
  String? _warning;
  bool _disposed = false;

  /// Current lifecycle state of the baseline recording.
  StudyRecordingStatus get status => _status;

  /// Proband id associated with the active session.
  String? get probandId => _probandId;

  /// Directory holding the phone-side RESPIRABAN CSV files for the session.
  String? get sessionDirectory => _sessionDirectory;

  /// Non-fatal warning raised while configuring devices, if any.
  String? get warning => _warning;

  /// Whether a baseline recording is currently running.
  bool get isRecording => _status == StudyRecordingStatus.recording;

  /// Time remaining in the baseline countdown.
  Duration get remaining {
    final start = _startTime;
    if (start == null || _status != StudyRecordingStatus.recording) {
      return baselineDuration;
    }
    final elapsed = DateTime.now().difference(start);
    final left = baselineDuration - elapsed;
    return left.isNegative ? Duration.zero : left;
  }

  /// Fraction of the baseline that has elapsed, in the range `[0, 1]`.
  double get progress {
    final total = baselineDuration.inMilliseconds;
    if (total == 0) {
      return 0;
    }
    final done = baselineDuration.inMilliseconds - remaining.inMilliseconds;
    return (done / total).clamp(0.0, 1.0);
  }

  /// Starts the guided baseline recording for [probandId] using [deviceSet].
  ///
  /// Throws if a recording is already running.
  Future<void> start({
    required String probandId,
    required StudyDeviceSet deviceSet,
  }) async {
    if (_status == StudyRecordingStatus.recording) {
      throw StateError('A recording is already in progress');
    }

    _warning = null;
    _probandId = probandId;
    _status = StudyRecordingStatus.recording;
    _startTime = DateTime.now();
    notifyListeners();

    try {
      final directory = await createStudySessionDirectory(probandId);
      _sessionDirectory = directory;

      await _startRespibanRecording(deviceSet.respiban, directory, probandId);
      await _startEarableSdRecording(deviceSet.earables, probandId);

      await WakelockPlus.enable();

      _ticker = Timer.periodic(const Duration(seconds: 1), _onTick);
      notifyListeners();
    } catch (e, st) {
      logger.e('Failed to start study recording: $e\n$st');
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
    notifyListeners();
  }

  /// Stops the baseline recording on both devices and finalizes the CSV files.
  Future<void> stop() async {
    if (_status != StudyRecordingStatus.recording) {
      return;
    }
    await _teardown();
    _status = StudyRecordingStatus.completed;
    _startTime = null;
    notifyListeners();
  }

  Future<void> _startRespibanRecording(
    Wearable respiban,
    String directory,
    String probandId,
  ) async {
    final token = sanitizeProbandId(probandId);
    final sensors = respiban.requireCapability<SensorManager>().sensors;

    // Start CSV recorders before switching the device on so no samples are lost
    // once data starts flowing.
    for (final sensor in sensors) {
      final recorder = Recorder(columns: sensor.axisNames);
      final filename =
          '${token}_RESPIRABAN_${_sanitizeFilenamePart(sensor.sensorName)}.csv';
      await recorder.start(
        filepath: '$directory/$filename',
        inputStream: SensorStreams.shared(wearable: respiban, sensor: sensor),
      );
      _respibanRecorders[sensor] = recorder;
    }

    final configuration = findRespibanConfiguration(respiban);
    if (configuration == null) {
      _addWarning('RESPIRABAN acquisition configuration not found.');
      return;
    }
    _respibanConfiguration = configuration;

    final beltAndImuValue = configuration.values
        .whereType<RespibanSensorConfigurationValue>()
        .where((value) => value.mode == RespibanAcquisitionMode.beltAndImu)
        .cast<RespibanSensorConfigurationValue?>()
        .firstWhere((value) => value != null, orElse: () => null);

    if (beltAndImuValue == null) {
      _addWarning('RESPIRABAN Belt + IMU mode is unavailable.');
      return;
    }
    configuration.setConfiguration(beltAndImuValue);
  }

  Future<void> _startEarableSdRecording(
    EarablePair earables,
    String probandId,
  ) async {
    final token = sanitizeProbandId(probandId);
    await _configureEarable(earables.left, 'left_$token');
    await _configureEarable(earables.right, 'right_$token');
  }

  Future<void> _configureEarable(Wearable earable, String filePrefix) async {
    try {
      await earable.requireCapability<EdgeRecorderManager>().setFilePrefix(
            filePrefix,
          );
    } catch (e) {
      _addWarning('Could not set file prefix on ${earable.name}: $e');
    }

    _applyEarableRecordConfig(
      earable,
      keywords: const ['imu'],
      targetFrequencyHz: imuFrequencyHz,
      label: 'IMU',
    );
    _applyEarableRecordConfig(
      earable,
      keywords: const ['mic'],
      targetFrequencyHz: microphoneFrequencyHz,
      label: 'microphone',
    );
  }

  void _applyEarableRecordConfig(
    Wearable earable, {
    required List<String> keywords,
    required int targetFrequencyHz,
    required String label,
  }) {
    final configuration = findEarableConfiguration(earable, keywords);
    if (configuration == null) {
      _addWarning('${earable.name}: no $label configuration found.');
      return;
    }

    final value = recordOnlyValueNearest(configuration, targetFrequencyHz);
    if (value == null) {
      _addWarning('${earable.name}: $label cannot record to SD card.');
      return;
    }

    configuration.setConfiguration(value);
    _appliedEarableConfigs.add(_AppliedEarableConfig(configuration));
  }

  /// Stops streams/recorders and returns every device to its off state.
  Future<void> _teardown() async {
    _ticker?.cancel();
    _ticker = null;

    for (final recorder in _respibanRecorders.values) {
      recorder.stop();
    }
    _respibanRecorders.clear();

    final respibanConfiguration = _respibanConfiguration;
    if (respibanConfiguration != null) {
      final offValue = respibanConfiguration.offValue;
      if (offValue != null) {
        respibanConfiguration.setConfiguration(offValue);
      }
    }
    _respibanConfiguration = null;

    for (final applied in _appliedEarableConfigs) {
      final offValue = applied.configuration.offValue;
      if (offValue != null) {
        applied.configuration.setConfiguration(offValue);
      }
    }
    _appliedEarableConfigs.clear();

    try {
      await WakelockPlus.disable();
    } catch (e) {
      logger.w('Failed to release wakelock: $e');
    }
  }

  void _addWarning(String message) {
    logger.w('Study recording: $message');
    _warning = _warning == null ? message : '$_warning\n$message';
  }

  String _sanitizeFilenamePart(String value) {
    final sanitized = value.trim().replaceAll(RegExp(r'[^A-Za-z0-9_\-]+'), '_');
    return sanitized.isEmpty ? 'sensor' : sanitized;
  }

  @override
  void dispose() {
    _disposed = true;
    // Best effort: ensure devices are not left recording if disposed mid-run.
    if (_status == StudyRecordingStatus.recording) {
      unawaited(_teardown());
    } else {
      _ticker?.cancel();
    }
    super.dispose();
  }
}

/// Tracks a sensor configuration that the controller switched into record mode
/// so it can be returned to its off value when the recording stops.
class _AppliedEarableConfig {
  final SensorConfiguration configuration;

  const _AppliedEarableConfig(this.configuration);
}
