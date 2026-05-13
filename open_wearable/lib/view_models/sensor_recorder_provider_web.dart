import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart' hide logger;

import 'package:open_wearable/widgets/sensors/local_recorder/local_recorder_models.dart';
import 'package:open_wearable/widgets/sensors/local_recorder/local_recorder_storage_web.dart';

import '../models/logger.dart';
import '../models/sensor_streams.dart';

class SensorRecorderProvider with ChangeNotifier {
  final Map<String, Wearable> _wearablesById = {};
  final Map<String, StreamSubscription<SensorValue>> _sensorSubscriptions = {};
  final Map<String, _WebRecordingSession> _sessions = {};
  bool _isRecording = false;
  bool _hasSensorsConnected = false;
  String? _currentDirectory;
  DateTime? _recordingStart;

  bool get isRecording => _isRecording;
  bool get hasSensorsConnected => _hasSensorsConnected;
  String? get currentDirectory => _currentDirectory;
  DateTime? get recordingStart => _recordingStart;

  final List<double> _waveformData = [];
  List<double> get waveformData => List.unmodifiable(_waveformData);

  bool _isBLEMicrophoneStreamingEnabled = false;
  bool get isBLEMicrophoneStreamingEnabled => _isBLEMicrophoneStreamingEnabled;

  Future<bool> startBLEMicrophoneStream() async {
    logger.w('BLE microphone streaming is not supported on web.');
    return false;
  }

  Future<void> stopBLEMicrophoneStream() async {
    _isBLEMicrophoneStreamingEnabled = false;
    _waveformData.clear();
    notifyListeners();
  }

  Future<void> startRecording(String dirname) async {
    if (_isRecording) {
      return;
    }

    _isRecording = true;
    _currentDirectory = dirname;
    _recordingStart = DateTime.now();
    _sessions.clear();

    for (final wearable in _wearablesById.values) {
      await _startRecordingForWearable(wearable, dirname);
    }

    final initialDrafts = _sessions.values.map((session) {
      return LocalRecorderDraftFile(
        name: session.fileName,
        content: session.content.toString(), // Contains the header
      );
    }).toList();

    if (initialDrafts.isNotEmpty) {
      await persistRecordingFolderFiles(dirname, initialDrafts);
    }

    notifyListeners();
  }

  void stopRecording(bool turnOffMic) async {
    if (!_isRecording) {
      return;
    }

    _isRecording = false;
    _recordingStart = null;

    final folderPath = _currentDirectory;
    final sessions = _sessions.values.toList(growable: false);
    _sessions.clear();

    for (final session in sessions) {
      await session.dispose();
    }

    if (folderPath != null) {
      final draftFiles = sessions
          .where((session) => session.content.isNotEmpty)
          .map(
            (session) => LocalRecorderDraftFile(
              name: session.fileName,
              content: session.content.toString(),
            ),
          )
          .toList();

      if (draftFiles.isEmpty) {
        await deleteRecordingFolder(folderPath);
      } else {
        await persistRecordingFolderFiles(folderPath, draftFiles);
      }
    }

    _currentDirectory = null;

    if (!turnOffMic && _isBLEMicrophoneStreamingEnabled) {
      unawaited(startBLEMicrophoneStream());
    }

    notifyListeners();
  }

  Future<void> addWearable(Wearable wearable) async {
    _wearablesById[wearable.deviceId] = wearable;

    wearable.addDisconnectListener(() {
      removeWearable(wearable);
    });

    if (_isRecording && _currentDirectory != null) {
      await _startRecordingForWearable(wearable, _currentDirectory!);
    }

    _updateConnected();
  }

  void synchronizeConnectedWearables(Iterable<Wearable> wearables) {
    final desiredById = <String, Wearable>{
      for (final wearable in wearables) wearable.deviceId: wearable,
    };

    final existingIds = _wearablesById.keys.toList(growable: false);
    for (final deviceId in existingIds) {
      if (!desiredById.containsKey(deviceId)) {
        removeWearable(_wearablesById[deviceId]!);
      }
    }

    for (final entry in desiredById.entries) {
      final existing = _wearablesById[entry.key];
      if (existing == null || !identical(existing, entry.value)) {
        unawaited(addWearable(entry.value));
      }
    }
  }

  void removeWearable(Wearable wearable) {
    _wearablesById.remove(wearable.deviceId);
    final sessionKeys = _sessions.keys
        .where((key) => key.startsWith('${wearable.deviceId}|'))
        .toList(growable: false);
    for (final key in sessionKeys) {
      unawaited(_sessions.remove(key)?.dispose());
      _sensorSubscriptions.remove(key)?.cancel();
    }
    _updateConnected();
  }

  void _updateConnected() {
    _hasSensorsConnected = _wearablesById.isNotEmpty;
    logger.i('Has sensors connected: $_hasSensorsConnected');
    notifyListeners();
  }

  Future<void> _startRecordingForWearable(
    Wearable wearable,
    String dirname,
  ) async {
    if (!wearable.hasCapability<SensorManager>()) {
      return;
    }

    for (final sensor in wearable.requireCapability<SensorManager>().sensors) {
      final key = _sensorRecordingKey(wearable: wearable, sensor: sensor);
      if (_sessions.containsKey(key)) {
        continue;
      }

      final session = _WebRecordingSession(
        fileName:
            '${await _recordingFilenameStem(wearable: wearable, sensor: sensor)}.csv',
        sensor: sensor,
      );
      _sessions[key] = session;

      final subscription = SensorStreams.shared(
        wearable: wearable,
        sensor: sensor,
      ).listen((sensorValue) {
        session.append(sensorValue);
      });
      _sensorSubscriptions[key] = subscription;
    }
  }

  String _sensorRecordingKey({
    required Wearable wearable,
    required Sensor sensor,
  }) {
    final axisNames = sensor.axisNames.join(',');
    final axisUnits = sensor.axisUnits.join(',');
    return '${wearable.deviceId}|${sensor.runtimeType}|${sensor.sensorName}|$axisNames|$axisUnits';
  }

  Future<String> _recordingFilenameStem({
    required Wearable wearable,
    required Sensor sensor,
  }) async {
    if (!wearable.hasCapability<StereoDevice>()) {
      return '${wearable.name}_${sensor.sensorName}';
    }
    final stereoPositionLabel = await _stereoPositionLabel(
      wearable.requireCapability<StereoDevice>(),
    );
    if (stereoPositionLabel != null) {
      return '${wearable.name}-$stereoPositionLabel-${sensor.sensorName}';
    }
    return '${wearable.name}_${sensor.sensorName}';
  }

  Future<String?> _stereoPositionLabel(StereoDevice wearable) async {
    final position = await wearable.position;
    return switch (position) {
      DevicePosition.left => 'L',
      DevicePosition.right => 'R',
      _ => null,
    };
  }

  @override
  void dispose() {
    for (final subscription in _sensorSubscriptions.values) {
      subscription.cancel();
    }
    _sensorSubscriptions.clear();
    for (final session in _sessions.values) {
      unawaited(session.dispose());
    }
    _sessions.clear();
    _wearablesById.clear();
    _waveformData.clear();
    super.dispose();
  }
}

class _WebRecordingSession {
  final String fileName;
  final Sensor sensor;
  final StringBuffer content = StringBuffer();

  _WebRecordingSession({required this.fileName, required this.sensor}) {
    content.writeln(_buildHeader());
  }

  void append(SensorValue value) {
    if (value is SensorDoubleValue) {
      content.writeln(
        [value.timestamp, ...value.values].join(','),
      );
    } else if (value is SensorIntValue) {
      content.writeln(
        [value.timestamp, ...value.values].join(','),
      );
    }
  }

  String _buildHeader() {
    final axisNames = sensor.axisNames.join(',');
    return axisNames.isEmpty ? 'timestamp' : 'timestamp,$axisNames';
  }

  Future<void> dispose() async {}
}
