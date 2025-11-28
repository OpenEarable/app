import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart' hide logger;

import '../models/logger.dart';

class SensorRecorderProvider with ChangeNotifier {
  final Map<Wearable, Map<Sensor, Recorder>> _recorders = {};

  bool _isRecording = false;
  bool _hasSensorsConnected = false;
  String? _currentDirectory;
  DateTime? _recordingStart;

  bool get isRecording => _isRecording;
  bool get hasSensorsConnected => _hasSensorsConnected;
  String? get currentDirectory => _currentDirectory;
  DateTime? get recordingStart => _recordingStart;

  void startRecording(String dirname) async {
    _isRecording = true;
    _currentDirectory = dirname;
    _recordingStart = DateTime.now();

    for (Wearable wearable in _recorders.keys) {
      await _startRecorderForWearable(wearable, dirname);
    }

    notifyListeners();
  }

  void stopRecording() {
    _isRecording = false;
    _recordingStart = null;
    for (Wearable wearable in _recorders.keys) {
      for (Sensor sensor in _recorders[wearable]!.keys) {
        Recorder? recorder = _recorders[wearable]?[sensor];
        if (recorder != null) {
          recorder.stop();
          logger.i(
              'Stopped recording for ${wearable.name} - ${sensor.sensorName}');
        }
      }
    }
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
      notifyListeners();
    });

    if (wearable is SensorManager) {
      for (Sensor sensor in (wearable as SensorManager).sensors) {
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
      if (recorder != null) {
        File file = await recorder.start(
          filepath: '$dirname/${wearable.name}_${sensor.sensorName}.csv',
          inputStream: sensor.sensorStream,
        );
        logger.i(
          '${resumed ? 'Resumed' : 'Started'} recording for ${wearable.name} - ${sensor.sensorName} to ${file.path}',
        );
      }
    }
  }
}
