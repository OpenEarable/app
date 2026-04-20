import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart' hide logger;

import '../models/logger.dart';
import '../models/sensor_streams.dart';

/// Runtime recorder state for connected wearables and sensors.
///
/// Needs:
/// - Connected wearables (optionally with `SensorManager` capability).
/// - Writable target directory for CSV output.
///
/// Does:
/// - Builds/owns per-wearable recorder maps.
/// - Starts/stops all active recorder streams.
/// - Keeps recording behavior consistent across wearable reconnects.
/// - Synchronizes recorder registration with the connected wearable set.
///
/// Provides:
/// - Recording status (`isRecording`, `recordingStart`, etc.).
/// - Recorder access used by recorder UI pages.
class SensorRecorderProvider with ChangeNotifier {
  final Map<Wearable, Map<Sensor, Recorder>> _recorders = {};
  final Map<String, String> _recordingFilepathsBySensorIdentity = {};
  Future<void> _pendingSynchronization = Future<void>.value();
  bool _disposed = false;

  bool _isRecording = false;
  bool _hasSensorsConnected = false;
  String? _currentDirectory;
  DateTime? _recordingStart;

  bool get isRecording => _isRecording;
  bool get hasSensorsConnected => _hasSensorsConnected;
  String? get currentDirectory => _currentDirectory;
  DateTime? get recordingStart => _recordingStart;

  Future<void> startRecording(String dirname) async {
    if (_isRecording) {
      return;
    }

    _recordingFilepathsBySensorIdentity.clear();
    _currentDirectory = dirname;
    _recordingStart = DateTime.now();

    try {
      for (Wearable wearable in _recorders.keys) {
        await _startRecorderForWearable(wearable, dirname);
      }
      _isRecording = true;
      notifyListeners();
    } catch (e, st) {
      logger.e('Failed to start recording: $e\n$st');
      _stopAllRecorderStreams();
      _recordingFilepathsBySensorIdentity.clear();
      _currentDirectory = null;
      _recordingStart = null;
      _isRecording = false;
      notifyListeners();
      rethrow;
    }
  }

  void stopRecording() {
    _isRecording = false;
    _recordingStart = null;
    _recordingFilepathsBySensorIdentity.clear();
    _stopAllRecorderStreams();
    notifyListeners();
  }

  Recorder? getRecorder(Wearable wearable, Sensor sensor) {
    if (!_recorders.containsKey(wearable)) {
      return null;
    }
    return _recorders[wearable]?[sensor];
  }

  Map<Sensor, Recorder> getRecorders(Wearable wearable) {
    return _recorders[wearable] ?? {};
  }

  Future<void> addWearable(Wearable wearable) async {
    final Wearable? existing = _findWearableByDeviceId(wearable.deviceId);

    if (existing != null) {
      _disposeWearable(existing);
      _recorders.remove(existing);
    }

    _recorders[wearable] = {};

    wearable.addDisconnectListener(() {
      removeWearable(wearable);
    });

    if (wearable.hasCapability<SensorManager>()) {
      for (Sensor sensor
          in wearable.requireCapability<SensorManager>().sensors) {
        if (!_recorders[wearable]!.containsKey(sensor)) {
          _recorders[wearable]![sensor] = Recorder(columns: sensor.axisNames);
        }
      }
    }

    if (_isRecording && _currentDirectory != null) {
      unawaited(
        _startRecorderForWearable(
          wearable,
          _currentDirectory!,
          resumed: true,
        ),
      );
    }

    _updateConnected();
  }

  /// Reconciles recorder state with the current connected wearable set.
  ///
  /// This keeps recorder registration derived from the authoritative
  /// [WearablesProvider] connection state instead of relying on each caller to
  /// remember a second side effect.
  void synchronizeConnectedWearables(Iterable<Wearable> wearables) {
    final desiredById = <String, Wearable>{
      for (final wearable in wearables) wearable.deviceId: wearable,
    };

    _pendingSynchronization = _pendingSynchronization.then((_) async {
      if (_disposed) {
        return;
      }

      final existingById = <String, Wearable>{
        for (final wearable in _recorders.keys) wearable.deviceId: wearable,
      };

      for (final entry in existingById.entries) {
        if (!desiredById.containsKey(entry.key)) {
          removeWearable(entry.value);
        }
      }

      for (final entry in desiredById.entries) {
        final existing = existingById[entry.key];
        if (existing == null || !identical(existing, entry.value)) {
          await addWearable(entry.value);
        }
      }
    });
  }

  void removeWearable(Wearable wearable) {
    _disposeWearable(wearable);
    _recorders.remove(wearable);
    _updateConnected();
  }

  void _updateConnected() {
    _hasSensorsConnected = !(_recorders.isEmpty ||
        _recorders.values.every((sensors) => sensors.isEmpty));
    logger.i('Has sensors connected: $_hasSensorsConnected');
    notifyListeners();
  }

  Wearable? _findWearableByDeviceId(String deviceId) {
    for (final wearable in _recorders.keys) {
      if (wearable.deviceId == deviceId) {
        return wearable;
      }
    }
    return null;
  }

  void _disposeWearable(Wearable wearable) {
    final recorderMap = _recorders[wearable];
    if (recorderMap == null) return;
    for (final recorder in recorderMap.values) {
      recorder.stop();
    }
  }

  Future<void> _startRecorderForWearable(
    Wearable wearable,
    String dirname, {
    bool resumed = false,
  }) async {
    for (Sensor sensor in _recorders[wearable]!.keys) {
      Recorder? recorder = _recorders[wearable]?[sensor];
      if (recorder == null) continue;

      final sensorIdentity = _sensorRecordingIdentity(
        wearable: wearable,
        sensor: sensor,
      );
      final existingFilepath =
          _recordingFilepathsBySensorIdentity[sensorIdentity];
      final append = resumed && existingFilepath != null;
      final filepath = existingFilepath ??
          await _createRecordingFilepath(
            wearable: wearable,
            sensor: sensor,
            dirname: dirname,
          );
      _recordingFilepathsBySensorIdentity[sensorIdentity] = filepath;

      File file = await recorder.start(
        filepath: filepath,
        inputStream: SensorStreams.shared(
          wearable: wearable,
          sensor: sensor,
        ),
        append: append,
      );

      logger.i(
        '${resumed ? 'Resumed' : 'Started'} recording for '
        '${wearable.name} - ${sensor.sensorName} to ${file.path}',
      );
    }
  }

  /// Builds a stable per-device/per-sensor identity for the current session.
  ///
  /// Reconnects replace the [Wearable] and [Sensor] object instances, so file
  /// reuse must be keyed by semantic sensor identity instead of object
  /// identity.
  String _sensorRecordingIdentity({
    required Wearable wearable,
    required Sensor sensor,
  }) {
    final axisNames = sensor.axisNames.join(',');
    final axisUnits = sensor.axisUnits.join(',');
    return '${wearable.deviceId}|${sensor.runtimeType}|${sensor.sensorName}|$axisNames|$axisUnits';
  }

  /// Resolves a new file path for a sensor without overwriting prior exports.
  Future<String> _createRecordingFilepath({
    required Wearable wearable,
    required Sensor sensor,
    required String dirname,
  }) async {
    final base = '${wearable.name}_${sensor.sensorName}';
    var name = base;
    var counter = 1;

    while (await File('$dirname/$name.csv').exists()) {
      name = '${base}_$counter';
      counter++;
    }

    return '$dirname/$name.csv';
  }

  void _stopAllRecorderStreams() {
    for (Wearable wearable in _recorders.keys) {
      for (Sensor sensor in _recorders[wearable]!.keys) {
        final recorder = _recorders[wearable]?[sensor];
        if (recorder == null) {
          continue;
        }
        recorder.stop();
        logger.i(
          'Stopped recording for ${wearable.name} - ${sensor.sensorName}',
        );
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    for (final wearable in _recorders.keys.toList()) {
      _disposeWearable(wearable);
    }
    _recordingFilepathsBySensorIdentity.clear();
    _recorders.clear();
    super.dispose();
  }
}
