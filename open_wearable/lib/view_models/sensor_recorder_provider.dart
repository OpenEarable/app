import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart' hide logger;
import 'package:record/record.dart';

import '../models/logger.dart';

class SensorRecorderProvider with ChangeNotifier {
  final Map<Wearable, Map<Sensor, Recorder>> _recorders = {};

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

  void startRecording(String dirname) async {
    _isRecording = true;
    _currentDirectory = dirname;
    _recordingStart = DateTime.now();

    for (Wearable wearable in _recorders.keys) {
      await _startRecorderForWearable(wearable, dirname);
    }

    await _startAudioRecording(
      dirname,
    );

    notifyListeners();
  }

  Future<void> _startAudioRecording(String recordingFolderPath) async {
    if (_selectedBLEDevice == null) {
      logger.w("No BLE headset detected, skipping audio recording");
      return;
    }
    if (!Platform.isAndroid) return;
    try {
      if (!await _audioRecorder.hasPermission()) {
        logger.w("No microphone permission for recording");
        return;
      }

      await _selectBLEDevice();

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
          "Audio recording started: $_currentAudioPath with device: ${_selectedBLEDevice?.label ?? 'default'}");

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

  void stopRecording() async {
    _isRecording = false;
    _recordingStart = null;
    for (Wearable wearable in _recorders.keys) {
      for (Sensor sensor in _recorders[wearable]!.keys) {
        Recorder? recorder = _recorders[wearable]?[sensor];
        if (recorder != null) {
          recorder.stop();
          logger.i(
            'Stopped recording for ${wearable.name} - ${sensor.sensorName}',
          );
        }
      }
    }
    try {
      if (_isAudioRecording) {
        final path = await _audioRecorder.stop();
        _amplitudeSub?.cancel();
        _amplitudeSub = null;
        _isAudioRecording = false;
        _waveformData.clear();

        logger.i("Audio recording saved to: $path");
        _currentAudioPath = null;
      }
    } catch (e) {
      logger.e("Error stopping audio recording: $e");
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
      if (recorder == null) continue;

      String base = '${wearable.name}_${sensor.sensorName}';
      String name = base;
      int counter = 1;

      while (await File('$dirname/$name.csv').exists()) {
        name = '${base}_$counter';
        counter++;
      }

      final filepath = '$dirname/$name.csv';

      File file = await recorder.start(
        filepath: filepath,
        inputStream: sensor.sensorStream,
      );

      logger.i(
        '${resumed ? 'Resumed' : 'Started'} recording for '
        '${wearable.name} - ${sensor.sensorName} to ${file.path}',
      );
    }
  }

  @override
  void dispose() {
    _audioRecorder.stop().then((_) {
      _audioRecorder.dispose();
    }).catchError((e) {
      logger.e("Error stopping audio in dispose: $e");
    });

    _amplitudeSub?.cancel();
    _waveformData.clear();

    for (final wearable in _recorders.keys) {
      _disposeWearable(wearable);
    }
    _recorders.clear();

    super.dispose();
  }
}
