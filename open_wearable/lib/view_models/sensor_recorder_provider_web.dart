import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart' hide logger;
import 'package:record/record.dart';

import 'package:open_wearable/widgets/sensors/local_recorder/local_recorder_models.dart';
import 'package:open_wearable/widgets/sensors/local_recorder/local_recorder_storage_web.dart';

import '../models/audio_input_source.dart';
import '../models/logger.dart';
import '../models/sensor_streams.dart';
import 'audio_input_controller.dart';

class SensorRecorderProvider with ChangeNotifier {
  final Map<String, Wearable> _wearablesById = {};
  final Map<String, StreamSubscription<SensorValue>> _sensorSubscriptions = {};
  final Map<String, _WebRecordingSession> _sessions = {};
  late final AudioInputController _audioInput = AudioInputController(
    platform: _WebAudioInputPlatform(),
  )..addListener(_notifyListenersIfActive);
  bool _isRecording = false;
  bool _hasSensorsConnected = false;
  bool _disposed = false;
  String? _currentDirectory;
  DateTime? _recordingStart;

  bool get isRecording => _isRecording;
  bool get hasSensorsConnected => _hasSensorsConnected;
  String? get currentDirectory => _currentDirectory;
  DateTime? get recordingStart => _recordingStart;
  List<AudioInputSource> get audioInputSources => _audioInput.sources;
  AudioInputSource? get selectedAudioInputSource => _audioInput.selectedSource;
  AudioInputSource? get appliedAudioInputSource => _audioInput.appliedSource;
  bool get isAudioInputEnabled => _audioInput.isEnabled;
  bool get isAudioMonitoringActive => _audioInput.isMonitoringActive;
  bool get isAudioInputSelectionPending => _audioInput.hasPendingSelection;
  List<double> get waveformData => _audioInput.waveformData;

  int _microphoneConfigurationRevision = 0;
  int get microphoneConfigurationRevision => _microphoneConfigurationRevision;

  void notifyMicrophoneConfigurationChanged() {
    _microphoneConfigurationRevision++;
    _notifyListenersIfActive();
  }

  Future<void> refreshAudioInputSources() async {
    await _audioInput.refreshSources();
  }

  void startAudioInputSourceRefresh() {
    _audioInput.startSourceRefresh();
  }

  void stopAudioInputSourceRefresh() {
    _audioInput.stopSourceRefresh();
  }

  Future<void> selectAudioInputSource(AudioInputSource? source) async {
    await _audioInput.selectSource(source);
  }

  Future<void> setAudioInputEnabled(bool enabled) async {
    await _audioInput.setEnabled(enabled);
  }

  Future<bool> startAudioMonitoring() async {
    return _audioInput.startMonitoring();
  }

  Future<void> stopAudioMonitoring() async {
    await _audioInput.stopMonitoring();
  }

  Future<bool> applySelectedAudioInputSource() async {
    return _audioInput.applySelectedSource();
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

    await _audioInput.startRecording(dirname);

    _notifyListenersIfActive();
  }

  /// Stops active web recording sessions and persists their buffered data.
  Future<void> stopRecording(bool turnOffMic) async {
    if (!_isRecording) {
      return;
    }

    _isRecording = false;
    _recordingStart = null;

    final folderPath = _currentDirectory;
    final sessions = _sessions.values.toList(growable: false);
    _sessions.clear();
    await _cancelSensorSubscriptions(_sensorSubscriptions.keys);

    for (final session in sessions) {
      await session.dispose();
    }

    final audioDraftFiles = await _audioInput.stopRecording(
      turnOffMic: turnOffMic,
    );

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
      draftFiles.addAll(audioDraftFiles);

      if (draftFiles.isEmpty) {
        await deleteRecordingFolder(folderPath);
      } else {
        await persistRecordingFolderFiles(folderPath, draftFiles);
      }
    }

    _currentDirectory = null;

    _notifyListenersIfActive();
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
    }
    unawaited(_cancelSensorSubscriptions(sessionKeys));
    _updateConnected();
  }

  void _updateConnected() {
    _hasSensorsConnected = _wearablesById.isNotEmpty;
    logger.i('Has sensors connected: $_hasSensorsConnected');
    _notifyListenersIfActive();
  }

  void _notifyListenersIfActive() {
    if (!_disposed) {
      notifyListeners();
    }
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

      _sensorSubscriptions[key] = SensorStreams.shared(
        wearable: wearable,
        sensor: sensor,
      ).listen(session.append);
    }
  }

  Future<void> _cancelSensorSubscriptions(Iterable<String> keys) async {
    final subscriptions = <StreamSubscription<SensorValue>>[];
    for (final key in keys.toList(growable: false)) {
      final subscription = _sensorSubscriptions.remove(key);
      if (subscription != null) {
        subscriptions.add(subscription);
      }
    }

    await Future.wait<void>(
      subscriptions.map((subscription) => subscription.cancel()),
    );
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
    _disposed = true;
    _audioInput.removeListener(_notifyListenersIfActive);
    _audioInput.dispose();
    unawaited(_cancelSensorSubscriptions(_sensorSubscriptions.keys));
    for (final session in _sessions.values) {
      unawaited(session.dispose());
    }
    _sessions.clear();
    _wearablesById.clear();
    super.dispose();
  }
}

class _WebAudioInputPlatform implements AudioInputPlatform {
  static const int _sampleRate = 48000;
  static const int _numChannels = 1;

  final AudioRecorder _audioRecorder = AudioRecorder();
  StreamSubscription<Amplitude>? _amplitudeSub;
  StreamSubscription<Uint8List>? _audioStreamSub;
  BytesBuilder? _audioRecordingBytes;
  List<InputDevice> _availableInputDevices = const [];
  bool _isStreamingActive = false;
  bool _isRecordingActive = false;

  @override
  Future<List<AudioInputSource>> listAudioInputSources() async {
    await _audioRecorder.hasPermission();
    final devices = await _audioRecorder.listInputDevices();
    final uniqueDevices = <InputDevice>[];
    final seenDeviceIds = <String>{};
    for (final device in devices) {
      if (seenDeviceIds.add(device.id)) {
        uniqueDevices.add(device);
      }
    }
    _availableInputDevices = uniqueDevices;
    return [
      AudioInputSource.systemDefault,
      ...uniqueDevices.map(
        (device) => AudioInputSource(
          id: device.id,
          label: device.label.isEmpty ? 'Microphone' : device.label,
          kind: classifyAudioInputSourceLabel(device.label),
        ),
      ),
    ];
  }

  @override
  Future<bool> startMonitoring(
    AudioInputSource source,
    ValueChanged<double> onLevel,
  ) {
    return _startAudioStream(
      source: source,
      recording: false,
      onLevel: onLevel,
    );
  }

  @override
  Future<void> stopMonitoring() {
    return _stopAudioStream();
  }

  @override
  Future<bool> startRecording(
    AudioInputSource source,
    String recordingFolderPath,
    ValueChanged<double> onLevel,
  ) {
    return _startAudioStream(
      source: source,
      recording: true,
      onLevel: onLevel,
    );
  }

  @override
  Future<List<LocalRecorderDraftFile>> stopRecording() async {
    if (!_isRecordingActive) {
      return const [];
    }
    final audioBytes = _audioRecordingBytes;
    await _stopAudioStream(clearRecordingBytes: false);
    final pcmBytes = audioBytes?.toBytes();
    _audioRecordingBytes = null;
    if (pcmBytes == null || pcmBytes.isEmpty) {
      return const [];
    }
    final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
    return [
      LocalRecorderDraftFile(
        name: 'audio_$timestamp.wav',
        mimeType: 'audio/wav',
        bytes: _buildWavBytes(
          pcmBytes: pcmBytes,
          sampleRate: _sampleRate,
          numChannels: _numChannels,
        ),
      ),
    ];
  }

  Future<bool> _startAudioStream({
    required AudioInputSource source,
    required bool recording,
    required ValueChanged<double> onLevel,
  }) async {
    if (_isStreamingActive || _isRecordingActive) {
      return true;
    }
    try {
      if (!await _audioRecorder.hasPermission()) {
        logger.w("No microphone permission for web audio recording");
        return false;
      }
      final selectedDevice = await _inputDeviceForSource(source);
      if (selectedDevice == _UnavailableInputDevice.instance) {
        logger.w("Selected web audio input is unavailable: ${source.label}");
        return false;
      }
      final stream = await _audioRecorder.startStream(
        RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: _sampleRate,
          numChannels: _numChannels,
          device: selectedDevice,
        ),
      );
      _audioRecordingBytes = recording ? BytesBuilder(copy: false) : null;
      _audioStreamSub = stream.listen((chunk) {
        _audioRecordingBytes?.add(chunk);
      });
      _isRecordingActive = recording;
      _isStreamingActive = !recording;
      unawaited(_amplitudeSub?.cancel());
      _amplitudeSub = _audioRecorder
          .onAmplitudeChanged(const Duration(milliseconds: 100))
          .listen((amp) => onLevel(_normalizeAmplitude(amp)));
      return true;
    } catch (e) {
      logger.e("Failed to start web audio stream: $e");
      _isRecordingActive = false;
      _isStreamingActive = false;
      _audioRecordingBytes = null;
      return false;
    }
  }

  Future<void> _stopAudioStream({bool clearRecordingBytes = true}) async {
    if (!_isStreamingActive && !_isRecordingActive) {
      return;
    }
    try {
      await _audioRecorder.stop();
      await _audioStreamSub?.cancel();
      _audioStreamSub = null;
      await _amplitudeSub?.cancel();
      _amplitudeSub = null;
      _isStreamingActive = false;
      _isRecordingActive = false;
      if (clearRecordingBytes) {
        _audioRecordingBytes = null;
      }
    } catch (e) {
      logger.e("Error stopping web audio stream: $e");
    }
  }

  Future<InputDevice?> _inputDeviceForSource(AudioInputSource source) async {
    if (source.isSystemDefault) {
      return null;
    }
    if (_availableInputDevices.isEmpty) {
      await listAudioInputSources();
    }
    for (final device in _availableInputDevices) {
      if (device.id == source.id) {
        return device;
      }
    }
    return _UnavailableInputDevice.instance;
  }

  double _normalizeAmplitude(Amplitude amplitude) {
    return ((amplitude.current + 50) / 50).clamp(0.0, 1.0);
  }

  Uint8List _buildWavBytes({
    required Uint8List pcmBytes,
    required int sampleRate,
    required int numChannels,
  }) {
    const headerSize = 44;
    const bitsPerSample = 16;
    final bytesPerSample = bitsPerSample ~/ 8;
    final byteRate = sampleRate * numChannels * bytesPerSample;
    final blockAlign = numChannels * bytesPerSample;
    final data = Uint8List(headerSize + pcmBytes.length);
    final view = ByteData.view(data.buffer);
    _writeAscii(view, 0, 'RIFF');
    view.setUint32(4, data.length - 8, Endian.little);
    _writeAscii(view, 8, 'WAVE');
    _writeAscii(view, 12, 'fmt ');
    view.setUint32(16, 16, Endian.little);
    view.setUint16(20, 1, Endian.little);
    view.setUint16(22, numChannels, Endian.little);
    view.setUint32(24, sampleRate, Endian.little);
    view.setUint32(28, byteRate, Endian.little);
    view.setUint16(32, blockAlign, Endian.little);
    view.setUint16(34, bitsPerSample, Endian.little);
    _writeAscii(view, 36, 'data');
    view.setUint32(40, pcmBytes.length, Endian.little);
    data.setRange(headerSize, data.length, pcmBytes);
    return data;
  }

  void _writeAscii(ByteData view, int offset, String value) {
    for (var i = 0; i < value.length; i++) {
      view.setUint8(offset + i, value.codeUnitAt(i));
    }
  }

  @override
  Future<void> dispose() async {
    await _stopAudioStream();
    await _audioRecorder.dispose();
  }
}

class _UnavailableInputDevice extends InputDevice {
  static const _UnavailableInputDevice instance = _UnavailableInputDevice._();

  const _UnavailableInputDevice._()
      : super(id: '__unavailable_input_device__', label: 'Unavailable');
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
