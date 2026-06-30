import 'dart:async';
import 'dart:collection';
import 'dart:io';

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

  _RespibanCsvWriter? _respibanWriter;
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

      // Start order: OpenEarable SD recording first, then the RESPIRABAN.
      await _startEarableSdRecording(deviceSet.earables, probandId);
      await _startRespibanRecording(deviceSet.respiban, directory, probandId);

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

    final beltSensor =
        sensors.whereType<RespibanRespirationSensor>().firstOrNull;
    final accelerometerSensor =
        sensors.whereType<RespibanAccelerometerSensor>().firstOrNull;
    final gyroscopeSensor =
        sensors.whereType<RespibanGyroscopeSensor>().firstOrNull;

    if (beltSensor == null) {
      _addWarning('RESPIRABAN respiration belt sensor not found.');
    } else {
      // Start the merged CSV writer before switching the device on so no
      // samples are lost once data starts flowing. Belt, accelerometer and
      // gyroscope share the same sample timestamps and are written into a
      // single file.
      final writer = _RespibanCsvWriter();
      await writer.start(
        filepath: '$directory/${token}_RESPIRABAN.csv',
        beltStream:
            SensorStreams.shared(wearable: respiban, sensor: beltSensor),
        accelerometerStream: accelerometerSensor == null
            ? null
            : SensorStreams.shared(
                wearable: respiban,
                sensor: accelerometerSensor,
              ),
        gyroscopeStream: gyroscopeSensor == null
            ? null
            : SensorStreams.shared(
                wearable: respiban,
                sensor: gyroscopeSensor,
              ),
      );
      _respibanWriter = writer;
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
    // Trailing underscore separates the prefix from the device-generated file
    // name suffix, e.g. `left_p000_`.
    await _configureEarable(earables.left, 'left_${token}_');
    await _configureEarable(earables.right, 'right_${token}_');
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
  ///
  /// Stop order is the reverse of [start]: the RESPIRABAN is fully stopped
  /// first, then the OpenEarable pair.
  Future<void> _teardown() async {
    _ticker?.cancel();
    _ticker = null;

    // 1) RESPIRABAN: switch acquisition off, then finalize the merged CSV.
    final respibanConfiguration = _respibanConfiguration;
    if (respibanConfiguration != null) {
      final offValue = respibanConfiguration.offValue;
      if (offValue != null) {
        respibanConfiguration.setConfiguration(offValue);
      }
    }
    _respibanConfiguration = null;

    await _respibanWriter?.stop();
    _respibanWriter = null;

    // 2) OpenEarable pair: switch the SD-card recording configurations off.
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

/// Writes the RESPIRABAN respiration belt, accelerometer and gyroscope streams
/// into a single CSV file.
///
/// All three RESPIRABAN sensors are decoded from the same device sample and
/// therefore share identical timestamps. Rows are keyed by timestamp and
/// written once every expected component for that timestamp has arrived, so a
/// row contains the belt value alongside its matching IMU values.
class _RespibanCsvWriter {
  IOSink? _sink;
  final List<StreamSubscription<SensorValue>> _subscriptions = [];
  final SplayTreeMap<int, _RespibanRow> _pending =
      SplayTreeMap<int, _RespibanRow>();
  bool _expectsAccelerometer = false;
  bool _expectsGyroscope = false;

  static const List<String> _emptyTriplet = ['', '', ''];

  /// Opens [filepath] and starts buffering samples from the provided streams.
  Future<void> start({
    required String filepath,
    required Stream<SensorValue> beltStream,
    Stream<SensorValue>? accelerometerStream,
    Stream<SensorValue>? gyroscopeStream,
  }) async {
    final file = File(filepath);
    await file.parent.create(recursive: true);
    _sink = file.openWrite();
    _expectsAccelerometer = accelerometerStream != null;
    _expectsGyroscope = gyroscopeStream != null;

    _sink!.writeln(
      'timestamp,Belt,Acc_X,Acc_Y,Acc_Z,Gyro_X,Gyro_Y,Gyro_Z',
    );

    _subscriptions.add(beltStream.listen(_onBelt));
    if (accelerometerStream != null) {
      _subscriptions.add(accelerometerStream.listen(_onAccelerometer));
    }
    if (gyroscopeStream != null) {
      _subscriptions.add(gyroscopeStream.listen(_onGyroscope));
    }
  }

  _RespibanRow _rowFor(int timestamp) =>
      _pending.putIfAbsent(timestamp, _RespibanRow.new);

  void _onBelt(SensorValue value) {
    final strings = value.valueStrings;
    _rowFor(value.timestamp).belt = strings.isEmpty ? '' : strings.first;
    _flushIfComplete(value.timestamp);
  }

  void _onAccelerometer(SensorValue value) {
    _rowFor(value.timestamp).accelerometer = value.valueStrings;
    _flushIfComplete(value.timestamp);
  }

  void _onGyroscope(SensorValue value) {
    _rowFor(value.timestamp).gyroscope = value.valueStrings;
    _flushIfComplete(value.timestamp);
  }

  void _flushIfComplete(int timestamp) {
    final row = _pending[timestamp];
    if (row == null) {
      return;
    }
    final hasBelt = row.belt != null;
    final hasAccelerometer =
        !_expectsAccelerometer || row.accelerometer != null;
    final hasGyroscope = !_expectsGyroscope || row.gyroscope != null;
    if (hasBelt && hasAccelerometer && hasGyroscope) {
      _writeRow(timestamp, row);
      _pending.remove(timestamp);
    }
  }

  void _writeRow(int timestamp, _RespibanRow row) {
    final sink = _sink;
    if (sink == null) {
      return;
    }
    final accelerometer = row.accelerometer ?? _emptyTriplet;
    final gyroscope = row.gyroscope ?? _emptyTriplet;
    sink.writeln(
      '$timestamp,${row.belt ?? ''},'
      '${_at(accelerometer, 0)},${_at(accelerometer, 1)},${_at(accelerometer, 2)},'
      '${_at(gyroscope, 0)},${_at(gyroscope, 1)},${_at(gyroscope, 2)}',
    );
  }

  String _at(List<String> values, int index) =>
      index < values.length ? values[index] : '';

  /// Stops buffering and flushes any remaining rows before closing the file.
  Future<void> stop() async {
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    _subscriptions.clear();

    // Flush any rows still waiting for a missing component, in timestamp order.
    for (final entry in _pending.entries) {
      _writeRow(entry.key, entry.value);
    }
    _pending.clear();

    await _sink?.flush();
    await _sink?.close();
    _sink = null;
  }
}

/// Partial CSV row accumulating the belt and IMU values for one timestamp.
class _RespibanRow {
  String? belt;
  List<String>? accelerometer;
  List<String>? gyroscope;
}
