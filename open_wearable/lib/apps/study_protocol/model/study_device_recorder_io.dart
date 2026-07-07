import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:open_earable_flutter/open_earable_flutter.dart' hide logger;
import 'package:wakelock_plus/wakelock_plus.dart';

import 'package:open_wearable/models/logger.dart';
import 'package:open_wearable/models/sensor_streams.dart';

import 'study_devices.dart';
import 'study_protocol_storage.dart';

/// Starts and stops the physiological recording used by every study phase.
///
/// Does:
/// - Configures the OpenEarable pair to record microphone (8000 Hz) and IMU
///   (100 Hz) to each earable's own SD card, without streaming.
/// - Starts the RespiBAN in Belt + IMU mode and writes its belt, accelerometer
///   and gyroscope streams into a single phone-side CSV.
/// - Holds a wakelock while recording.
///
/// File naming is phase-scoped so a session directory can hold both the baseline
/// and the ergometer recordings without collisions.
class StudyDeviceRecorder {
  /// Target microphone sample rate for OpenEarable SD-card recording.
  static const int microphoneFrequencyHz = 8000;

  /// Target IMU sample rate for OpenEarable SD-card recording.
  static const int imuFrequencyHz = 100;

  /// Allows the start acknowledgement and one watchdog recovery before a
  /// missing first RespiBAN sample is treated as a failed phase start.
  static const Duration firstRespibanSampleTimeout = Duration(seconds: 10);

  _RespibanCsvWriter? _respibanWriter;
  String? _respibanFilePath;
  final List<SensorConfiguration> _appliedEarableConfigs = [];
  RespibanSensorConfiguration? _respibanConfiguration;
  String? _warning;

  /// Non-fatal warnings raised while configuring devices, if any.
  String? get warning => _warning;

  /// Flushes pending CSV writes and returns the current RespiBAN CSV size.
  ///
  /// This reads the actual phone-side file instead of estimating written rows,
  /// so the UI can reveal when data reception and disk output diverge during a
  /// phase.
  Future<int?> respibanFileSizeBytes() async {
    final writer = _respibanWriter;
    if (writer != null) {
      return writer.flushAndMeasureSize();
    }
    final path = _respibanFilePath;
    if (path == null) {
      return null;
    }
    final file = File(path);
    if (!await file.exists()) {
      return null;
    }
    return file.length();
  }

  /// Starts recording on the OpenEarable pair and the RespiBAN.
  ///
  /// [respibanFileLabel] and [earablePrefixSuffix] scope the output names to the
  /// phase (for example `ergometer` / `ergo_`); pass empty strings to keep the
  /// unlabeled baseline naming.
  /// Returns the app-side arrival time of the first RespiBAN sample.
  Future<DateTime> start({
    required StudyDeviceSet deviceSet,
    required String directory,
    required String probandId,
    String respibanFileLabel = '',
    String earablePrefixSuffix = '',
  }) async {
    // Start order: OpenEarable SD recording first, then the RespiBAN.
    await _startEarableSdRecording(
      deviceSet.earables,
      probandId,
      earablePrefixSuffix,
    );
    final firstRespibanSampleAt = await _startRespibanRecording(
      deviceSet.respiban,
      directory,
      probandId,
      respibanFileLabel,
    );

    await WakelockPlus.enable();
    return firstRespibanSampleAt;
  }

  /// Stops recording and returns every device to its off state.
  ///
  /// Stop order is the reverse of [start]: the RespiBAN is fully stopped
  /// first, then the OpenEarable pair.
  Future<void> stop() async {
    final respibanConfiguration = _respibanConfiguration;
    if (respibanConfiguration != null) {
      final offValue = respibanConfiguration.offValue;
      if (offValue != null) {
        await respibanConfiguration.setMode(offValue.mode);
      }
    }
    _respibanConfiguration = null;

    await _respibanWriter?.stop();
    _respibanWriter = null;

    for (final configuration in _appliedEarableConfigs) {
      final offValue = configuration.offValue;
      if (offValue != null) {
        configuration.setConfiguration(offValue);
      }
    }
    _appliedEarableConfigs.clear();

    try {
      await WakelockPlus.disable();
    } catch (e) {
      logger.w('Failed to release wakelock: $e');
    }
  }

  Future<void> _startEarableSdRecording(
    EarablePair earables,
    String probandId,
    String prefixSuffix,
  ) async {
    final token = sanitizeProbandId(probandId);
    // Trailing underscore separates the prefix from the device-generated file
    // name suffix, e.g. `left_p000_` or `left_p000_ergo_`.
    await _configureEarable(earables.left, 'left_${token}_$prefixSuffix');
    await _configureEarable(earables.right, 'right_${token}_$prefixSuffix');
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
    _appliedEarableConfigs.add(configuration);
  }

  Future<DateTime> _startRespibanRecording(
    Wearable respiban,
    String directory,
    String probandId,
    String fileLabel,
  ) async {
    final token = sanitizeProbandId(probandId);
    final sensors = respiban.requireCapability<SensorManager>().sensors;

    final beltSensor = sensors
        .whereType<RespibanRespirationSensor>()
        .firstOrNull;
    final accelerometerSensor = sensors
        .whereType<RespibanAccelerometerSensor>()
        .firstOrNull;
    final gyroscopeSensor = sensors
        .whereType<RespibanGyroscopeSensor>()
        .firstOrNull;

    if (beltSensor == null) {
      throw StateError('RespiBAN respiration belt sensor not found.');
    }

    final label = fileLabel.isEmpty ? '' : '_$fileLabel';
    // Start the merged CSV writer before switching the device on so no
    // samples are lost once data starts flowing. Belt, accelerometer and
    // gyroscope share the same sample timestamps and are written into a
    // single file.
    final writer = _RespibanCsvWriter();
    final filepath = '$directory/$token${label}_RespiBAN.csv';
    _respibanFilePath = filepath;
    await writer.start(
      filepath: filepath,
      beltStream: SensorStreams.shared(wearable: respiban, sensor: beltSensor),
      accelerometerStream: accelerometerSensor == null
          ? null
          : SensorStreams.shared(
              wearable: respiban,
              sensor: accelerometerSensor,
            ),
      gyroscopeStream: gyroscopeSensor == null
          ? null
          : SensorStreams.shared(wearable: respiban, sensor: gyroscopeSensor),
    );
    _respibanWriter = writer;

    final configuration = findRespibanConfiguration(respiban);
    if (configuration == null) {
      throw StateError('RespiBAN acquisition configuration not found.');
    }
    _respibanConfiguration = configuration;

    final beltAndImuValue = configuration.values
        .whereType<RespibanSensorConfigurationValue>()
        .where((value) => value.mode == RespibanAcquisitionMode.beltAndImu)
        .cast<RespibanSensorConfigurationValue?>()
        .firstWhere((value) => value != null, orElse: () => null);

    if (beltAndImuValue == null) {
      throw StateError('RespiBAN Belt + IMU mode is unavailable.');
    }
    await configuration.setMode(beltAndImuValue.mode);
    try {
      return await writer.firstSampleArrival.timeout(
        firstRespibanSampleTimeout,
      );
    } on TimeoutException {
      throw TimeoutException(
        'No RespiBAN sample arrived after the start acknowledgement.',
        firstRespibanSampleTimeout,
      );
    }
  }

  void _addWarning(String message) {
    logger.w('Study recording: $message');
    _warning = _warning == null ? message : '$_warning\n$message';
  }
}

/// Writes the RespiBAN respiration belt, accelerometer and gyroscope streams
/// into a single CSV file.
///
/// All three RespiBAN sensors are decoded from the same device sample and
/// therefore share identical timestamps. Rows are keyed by timestamp and
/// written once every expected component for that timestamp has arrived, so a
/// row contains the belt value alongside its matching IMU values.
class _RespibanCsvWriter {
  IOSink? _sink;
  File? _file;
  final Completer<DateTime> _firstSampleArrival = Completer<DateTime>();
  final List<StreamSubscription<SensorValue>> _subscriptions = [];
  final SplayTreeMap<int, _RespibanRow> _pending =
      SplayTreeMap<int, _RespibanRow>();
  bool _expectsAccelerometer = false;
  bool _expectsGyroscope = false;

  static const List<String> _emptyTriplet = ['', '', ''];

  Future<DateTime> get firstSampleArrival => _firstSampleArrival.future;

  /// Opens [filepath] and starts buffering samples from the provided streams.
  Future<void> start({
    required String filepath,
    required Stream<SensorValue> beltStream,
    Stream<SensorValue>? accelerometerStream,
    Stream<SensorValue>? gyroscopeStream,
  }) async {
    final file = File(filepath);
    await file.parent.create(recursive: true);
    _file = file;
    _sink = file.openWrite();
    _expectsAccelerometer = accelerometerStream != null;
    _expectsGyroscope = gyroscopeStream != null;

    _sink!.writeln('timestamp,Belt,Acc_X,Acc_Y,Acc_Z,Gyro_X,Gyro_Y,Gyro_Z');

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
    if (!_firstSampleArrival.isCompleted) {
      _firstSampleArrival.complete(DateTime.now());
    }
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

  /// Flushes buffered sink data and returns the actual file size on disk.
  Future<int?> flushAndMeasureSize() async {
    final file = _file;
    if (file == null) {
      return null;
    }
    try {
      await _sink?.flush();
      if (!await file.exists()) {
        return null;
      }
      return file.length();
    } catch (e) {
      logger.w('Failed to read RespiBAN CSV size: $e');
      return null;
    }
  }

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
