import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart' hide logger;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

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
  final AudioRecorder _audioRecorder = AudioRecorder();
  bool _isAudioRecording = false;
  String? _currentAudioPath;
  StreamSubscription<Amplitude>? _amplitudeSub;

  bool get isRecording => _isRecording;
  bool get hasSensorsConnected => _hasSensorsConnected;
  String? get currentDirectory => _currentDirectory;
  DateTime? get recordingStart => _recordingStart;

  final List<double> _waveformData = [];
  List<double> get waveformData => List.unmodifiable(_waveformData);

  InputDevice? _selectedBLEDevice;

  bool _isBLEMicrophoneStreamingEnabled = false;
  bool get isBLEMicrophoneStreamingEnabled => _isBLEMicrophoneStreamingEnabled;

  // Path for temporary streaming file
  String? _streamingPath;
  bool _isStreamingActive = false;

  Future<void> _selectBLEDevice() async {
    try {
      final devices = await _audioRecorder.listInputDevices();

      try {
        _selectedBLEDevice = devices.firstWhere(
          (device) =>
              device.label.toLowerCase().contains('bluetooth') ||
              device.label.toLowerCase().contains('ble') ||
              device.label.toLowerCase().contains('headset') ||
              device.label.toLowerCase().contains('openearable'),
        );
        logger.i("Selected audio input device: ${_selectedBLEDevice!.label}");
      } catch (e) {
        _selectedBLEDevice = null;
        logger.w("No BLE headset found");
      }
    } catch (e) {
      logger.e("Error selecting BLE device: $e");
      _selectedBLEDevice = null;
    }
  }

  Future<bool> startBLEMicrophoneStream() async {
    if (!kIsWeb && !Platform.isAndroid) {
      logger.w("BLE microphone streaming only supported on Android");
      return false;
    }

    if (_isStreamingActive) {
      logger.i("BLE microphone streaming already active");
      return true;
    }

    try {
      if (!await _audioRecorder.hasPermission()) {
        logger.w("No microphone permission for streaming");
        return false;
      }

      await _selectBLEDevice();

      if (_selectedBLEDevice == null) {
        logger.w("No BLE headset detected, cannot start streaming");
        return false;
      }

      const encoder = AudioEncoder.wav;
      if (!await _audioRecorder.isEncoderSupported(encoder)) {
        logger.w("WAV encoder not supported");
        return false;
      }

      final tempDir = await getTemporaryDirectory();
      _streamingPath =
          '${tempDir.path}/ble_stream_${DateTime.now().millisecondsSinceEpoch}.wav';

      final config = RecordConfig(
        encoder: encoder,
        sampleRate: 48000,
        bitRate: 768000,
        numChannels: 1,
        device: _selectedBLEDevice,
      );

      await _audioRecorder.start(config, path: _streamingPath!);
      _isStreamingActive = true;
      _isBLEMicrophoneStreamingEnabled = true;

      // Set up amplitude monitoring for waveform display
      _amplitudeSub?.cancel();
      _amplitudeSub = _audioRecorder
          .onAmplitudeChanged(const Duration(milliseconds: 100))
          .listen((amp) {
        final normalized = (amp.current + 50) / 50;
        _waveformData.add(normalized.clamp(0.0, 2.0));

        if (_waveformData.length > 100) {
          _waveformData.removeAt(0);
        }

        notifyListeners();
      });

      logger.i(
        "BLE microphone streaming started with device: ${_selectedBLEDevice!.label}",
      );
      notifyListeners();
      return true;
    } catch (e) {
      logger.e("Failed to start BLE microphone streaming: $e");
      _isStreamingActive = false;
      _isBLEMicrophoneStreamingEnabled = false;
      _streamingPath = null;
      notifyListeners();
      return false;
    }
  }

  Future<void> stopBLEMicrophoneStream() async {
    if (!_isStreamingActive) {
      return;
    }

    try {
      await _audioRecorder.stop();
      _amplitudeSub?.cancel();
      _amplitudeSub = null;
      _isStreamingActive = false;
      _isBLEMicrophoneStreamingEnabled = false;
      _waveformData.clear();

      // Clean up temporary streaming file
      if (_streamingPath != null) {
        try {
          final file = File(_streamingPath!);
          if (await file.exists()) {
            await file.delete();
          }
        } catch (e) {
          // Ignore cleanup errors
        }
        _streamingPath = null;
      }

      logger.i("BLE microphone streaming stopped");
      notifyListeners();
    } catch (e) {
      logger.e("Error stopping BLE microphone streaming: $e");
    }
  }

  Future<void> startRecording(String dirname) async {
    if (_isRecording) {
      return;
    }
    _isRecording = true;
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

    await _startAudioRecording(
      dirname,
    );

    notifyListeners();
  }

  Future<void> _startAudioRecording(String recordingFolderPath) async {
    if (!kIsWeb && !Platform.isAndroid) return;

    // Only start recording if BLE microphone streaming is enabled
    if (!_isBLEMicrophoneStreamingEnabled) {
      logger
          .w("BLE microphone streaming not enabled, skipping audio recording");
      return;
    }

    // Stop streaming session before starting actual recording
    if (_isStreamingActive) {
      await _audioRecorder.stop();
      _amplitudeSub?.cancel();
      _amplitudeSub = null;
      _isStreamingActive = false;

      // Clean up temporary streaming file
      if (_streamingPath != null) {
        try {
          final file = File(_streamingPath!);
          if (await file.exists()) {
            await file.delete();
          }
        } catch (e) {
          // Ignore cleanup errors
        }
        _streamingPath = null;
      }
    }

    try {
      if (!await _audioRecorder.hasPermission()) {
        logger.w("No microphone permission for recording");
        return;
      }

      await _selectBLEDevice();

      if (_selectedBLEDevice == null) {
        logger.w("No BLE headset detected, skipping audio recording");
        return;
      }

      const encoder = AudioEncoder.wav;
      if (!await _audioRecorder.isEncoderSupported(encoder)) {
        logger.w("WAV encoder not supported");
        return;
      }

      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
      final audioPath = '$recordingFolderPath/audio_$timestamp.wav';

      final config = RecordConfig(
        encoder: encoder,
        sampleRate: 48000, // Set to 48kHz for BLE audio quality
        bitRate: 768000, // 16-bit * 48kHz * 1 channel = 768 kbps
        numChannels: 1,
        device: _selectedBLEDevice,
      );

      await _audioRecorder.start(config, path: audioPath);
      _currentAudioPath = audioPath;
      _isAudioRecording = true;

      logger.i(
        "Audio recording started: $_currentAudioPath with device: ${_selectedBLEDevice?.label ?? 'default'}",
      );

      _amplitudeSub = _audioRecorder
          .onAmplitudeChanged(const Duration(milliseconds: 100))
          .listen((amp) {
        final normalized = (amp.current + 50) / 50;
        _waveformData.add(normalized.clamp(0.0, 2.0));

        if (_waveformData.length > 100) {
          _waveformData.removeAt(0);
        }

        notifyListeners();
      });
    } catch (e) {
      logger.e("Failed to start audio recording: $e");
      _isAudioRecording = false;
    }
  }

  void stopRecording(bool turnOffMic) async {
    _isRecording = false;
    _recordingStart = null;
    _recordingFilepathsBySensorIdentity.clear();
    _stopAllRecorderStreams();
    try {
      if (_isAudioRecording) {
        final path = await _audioRecorder.stop();
        _amplitudeSub?.cancel();
        _amplitudeSub = null;
        _isAudioRecording = false;

        logger.i("Audio recording saved to: $path");
        _currentAudioPath = null;
      }
    } catch (e) {
      logger.e("Error stopping audio recording: $e");
    }

    // Restart streaming if it was enabled before recording
    if (!turnOffMic &&
        _isBLEMicrophoneStreamingEnabled &&
        !_isStreamingActive) {
      unawaited(startBLEMicrophoneStream());
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
    final base = await _recordingFilenameStem(
      wearable: wearable,
      sensor: sensor,
    );
    var name = base;
    var counter = 1;

    while (await File('$dirname/$name.csv').exists()) {
      name = '${base}_$counter';
      counter++;
    }

    return '$dirname/$name.csv';
  }

  /// Builds the exported filename stem for a wearable sensor recording.
  ///
  /// Stereo-capable devices include their side marker so left/right files stay
  /// distinguishable in shared recording folders.
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

  /// Returns the short stereo side label used in exported filenames.
  Future<String?> _stereoPositionLabel(StereoDevice wearable) async {
    final position = await wearable.position;
    return switch (position) {
      DevicePosition.left => 'L',
      DevicePosition.right => 'R',
      _ => null,
    };
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
    // Stop streaming
    stopBLEMicrophoneStream();

    // Stop recording
    _audioRecorder.stop().then((_) {
      _audioRecorder.dispose();
    }).catchError((e) {
      logger.e("Error stopping audio in dispose: $e");
    });
    _amplitudeSub?.cancel();
    _waveformData.clear();
    for (final wearable in _recorders.keys.toList()) {
      _disposeWearable(wearable);
    }
    _recordingFilepathsBySensorIdentity.clear();
    _recorders.clear();
    super.dispose();
  }
}
