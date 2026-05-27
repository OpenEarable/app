import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart' hide logger;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../models/audio_input_source.dart';
import '../models/logger.dart';
import '../models/sensor_streams.dart';
import '../widgets/sensors/local_recorder/local_recorder_models.dart';
import 'audio_input_controller.dart';

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
  static const Duration _microphoneConfigurationSettleDelay =
      Duration(milliseconds: 300);

  final Map<Wearable, Map<Sensor, Recorder>> _recorders = {};
  final Map<String, String> _recordingFilepathsBySensorIdentity = {};
  Future<void> _pendingSynchronization = Future<void>.value();
  bool _disposed = false;
  AudioInputController? _audioInput;

  bool _isRecording = false;
  bool _hasSensorsConnected = false;
  String? _currentDirectory;
  DateTime? _recordingStart;

  bool get isRecording => _isRecording;
  bool get hasSensorsConnected => _hasSensorsConnected;
  String? get currentDirectory => _currentDirectory;
  DateTime? get recordingStart => _recordingStart;
  List<AudioInputSource> get audioInputSources =>
      _supportedAudioInput?.sources ?? const [];
  AudioInputSource? get selectedAudioInputSource =>
      _supportedAudioInput?.selectedSource;
  AudioInputSource? get appliedAudioInputSource =>
      _supportedAudioInput?.appliedSource;
  bool get isAudioInputEnabled => _supportedAudioInput?.isEnabled ?? false;
  bool get isAudioMonitoringActive =>
      _supportedAudioInput?.isMonitoringActive ?? false;
  bool get isAudioInputSelectionPending =>
      _supportedAudioInput?.hasPendingSelection ?? false;
  List<double> get waveformData =>
      _supportedAudioInput?.waveformData ?? const [];

  bool get _isAudioInputSupported => !Platform.isMacOS;

  AudioInputController? get _supportedAudioInput {
    if (!_isAudioInputSupported) {
      return null;
    }
    return _audioInput ??= AudioInputController(
      platform: _IoAudioInputPlatform(),
    )..addListener(_notifyListenersIfActive);
  }

  int _microphoneConfigurationRevision = 0;
  int get microphoneConfigurationRevision => _microphoneConfigurationRevision;

  void notifyMicrophoneConfigurationChanged() {
    _bumpMicrophoneConfigurationRevision();
    Future<void>.delayed(_microphoneConfigurationSettleDelay, () {
      if (_disposed) {
        return;
      }
      _bumpMicrophoneConfigurationRevision();
    });
  }

  void _bumpMicrophoneConfigurationRevision() {
    _microphoneConfigurationRevision++;
    _notifyListenersIfActive();
  }

  /// Starts periodic microphone discovery while microphone settings UI exists.
  void startAudioInputSourceRefresh() {
    _supportedAudioInput?.startSourceRefresh();
  }

  /// Stops periodic microphone discovery when no UI needs it.
  void stopAudioInputSourceRefresh() {
    _audioInput?.stopSourceRefresh();
  }

  /// Refreshes the platform microphone list used by the virtual microphone row.
  Future<void> refreshAudioInputSources() async {
    await _supportedAudioInput?.refreshSources();
  }

  /// Selects the app-local microphone source used by local recordings.
  ///
  /// Passing `null` turns audio capture off while leaving wearable sensor
  /// configuration untouched.
  Future<void> selectAudioInputSource(AudioInputSource? source) async {
    await _supportedAudioInput?.selectSource(source);
  }

  /// Enables or disables audio capture without changing the remembered source.
  Future<void> setAudioInputEnabled(bool enabled) async {
    await _supportedAudioInput?.setEnabled(enabled);
  }

  Future<bool> startAudioMonitoring() async {
    return _supportedAudioInput?.startMonitoring() ?? false;
  }

  Future<void> stopAudioMonitoring() async {
    await _audioInput?.stopMonitoring();
  }

  /// Applies the pending microphone selection to the live monitoring stream.
  ///
  /// Selecting a source in the sensor configuration tab only changes local
  /// pending state. Calling this method mirrors the wearable profile apply
  /// flow by starting or stopping the actual microphone stream.
  Future<bool> applySelectedAudioInputSource() async {
    return _supportedAudioInput?.applySelectedSource() ?? false;
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
      _notifyListenersIfActive();
    } catch (e, st) {
      logger.e('Failed to start recording: $e\n$st');
      _stopAllRecorderStreams();
      _recordingFilepathsBySensorIdentity.clear();
      _currentDirectory = null;
      _recordingStart = null;
      _isRecording = false;
      _notifyListenersIfActive();
      rethrow;
    }

    await _supportedAudioInput?.startRecording(dirname);

    _notifyListenersIfActive();
  }

  /// Stops active wearable and audio recording streams and finalizes files.
  Future<void> stopRecording(bool turnOffMic) async {
    _isRecording = false;
    _recordingStart = null;
    _recordingFilepathsBySensorIdentity.clear();
    _stopAllRecorderStreams();
    await _audioInput?.stopRecording(turnOffMic: turnOffMic);

    _notifyListenersIfActive();
  }

  /// Notifies listeners only while this provider is still mounted.
  void _notifyListenersIfActive() {
    if (!_disposed) {
      notifyListeners();
    }
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
    _audioInput?.removeListener(_notifyListenersIfActive);
    _audioInput?.dispose();
    for (final wearable in _recorders.keys.toList()) {
      _disposeWearable(wearable);
    }
    _recordingFilepathsBySensorIdentity.clear();
    _recorders.clear();
    super.dispose();
  }
}

class _IoAudioInputPlatform implements AudioInputPlatform {
  final AudioRecorder _audioRecorder = AudioRecorder();
  StreamSubscription<Amplitude>? _amplitudeSub;
  List<InputDevice> _availableInputDevices = const [];
  String? _streamingPath;
  String? _currentAudioPath;
  bool _isMonitoringActive = false;
  bool _isRecordingActive = false;

  @override
  Future<List<AudioInputSource>> listAudioInputSources() async {
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
          label: device.label,
          kind: classifyAudioInputSourceLabel(device.label),
        ),
      ),
    ];
  }

  @override
  Future<bool> startMonitoring(
    AudioInputSource source,
    ValueChanged<double> onLevel,
  ) async {
    if (_isMonitoringActive) {
      return true;
    }
    try {
      final selectedDevice = await _inputDeviceForSource(source);
      if (selectedDevice == _UnavailableInputDevice.instance) {
        logger.w("Selected audio input is unavailable: ${source.label}");
        return false;
      }
      if (!await _audioRecorder.hasPermission()) {
        logger.w("No microphone permission for monitoring");
        return false;
      }
      const encoder = AudioEncoder.wav;
      if (!await _audioRecorder.isEncoderSupported(encoder)) {
        logger.w("WAV encoder not supported");
        return false;
      }

      final tempDir = await getTemporaryDirectory();
      _streamingPath =
          '${tempDir.path}/audio_monitor_${DateTime.now().millisecondsSinceEpoch}.wav';
      await _audioRecorder.start(
        RecordConfig(
          encoder: encoder,
          sampleRate: 48000,
          bitRate: 768000,
          numChannels: 1,
          device: selectedDevice,
        ),
        path: _streamingPath!,
      );
      _isMonitoringActive = true;
      _listenToAmplitude(onLevel);
      logger.i("Audio monitoring started with input: ${source.label}");
      return true;
    } catch (e) {
      logger.e("Failed to start audio monitoring: $e");
      _isMonitoringActive = false;
      _streamingPath = null;
      return false;
    }
  }

  @override
  Future<void> stopMonitoring() async {
    if (!_isMonitoringActive) {
      return;
    }
    try {
      await _audioRecorder.stop();
      await _amplitudeSub?.cancel();
      _amplitudeSub = null;
      _isMonitoringActive = false;
      await _deleteStreamingFile();
      logger.i("Audio monitoring stopped");
    } catch (e) {
      logger.e("Error stopping audio monitoring: $e");
    }
  }

  @override
  Future<bool> startRecording(
    AudioInputSource source,
    String recordingFolderPath,
    ValueChanged<double> onLevel,
  ) async {
    try {
      final selectedDevice = await _inputDeviceForSource(source);
      if (selectedDevice == _UnavailableInputDevice.instance) {
        logger.w(
          "Selected audio input is unavailable, skipping audio recording: ${source.label}",
        );
        return false;
      }
      if (!await _audioRecorder.hasPermission()) {
        logger.w("No microphone permission for recording");
        return false;
      }
      const encoder = AudioEncoder.wav;
      if (!await _audioRecorder.isEncoderSupported(encoder)) {
        logger.w("WAV encoder not supported");
        return false;
      }
      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
      final audioPath = '$recordingFolderPath/audio_$timestamp.wav';
      await _audioRecorder.start(
        RecordConfig(
          encoder: encoder,
          sampleRate: 48000,
          bitRate: 768000,
          numChannels: 1,
          device: selectedDevice,
        ),
        path: audioPath,
      );
      _currentAudioPath = audioPath;
      _isRecordingActive = true;
      _listenToAmplitude(onLevel);
      logger.i("Audio recording started: $_currentAudioPath");
      return true;
    } catch (e) {
      logger.e("Failed to start audio recording: $e");
      _isRecordingActive = false;
      return false;
    }
  }

  @override
  Future<List<LocalRecorderDraftFile>> stopRecording() async {
    if (!_isRecordingActive) {
      return const [];
    }
    try {
      final path = await _audioRecorder.stop();
      await _amplitudeSub?.cancel();
      _amplitudeSub = null;
      _isRecordingActive = false;
      logger.i("Audio recording saved to: $path");
      _currentAudioPath = null;
    } catch (e) {
      logger.e("Error stopping audio recording: $e");
    }
    return const [];
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

  void _listenToAmplitude(ValueChanged<double> onLevel) {
    unawaited(_amplitudeSub?.cancel());
    _amplitudeSub = _audioRecorder
        .onAmplitudeChanged(const Duration(milliseconds: 100))
        .listen((amp) => onLevel(_normalizeAmplitude(amp)));
  }

  double _normalizeAmplitude(Amplitude amplitude) {
    return ((amplitude.current + 50) / 50).clamp(0.0, 1.0);
  }

  Future<void> _deleteStreamingFile() async {
    final streamingPath = _streamingPath;
    if (streamingPath == null) {
      return;
    }
    _streamingPath = null;
    try {
      final file = File(streamingPath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      logger.w("Failed to delete temporary audio monitoring file: $e");
    }
  }

  @override
  Future<void> dispose() async {
    await _amplitudeSub?.cancel();
    _amplitudeSub = null;
    try {
      await _audioRecorder.stop();
      await _deleteStreamingFile();
    } catch (e) {
      logger.e("Error stopping audio in dispose: $e");
    } finally {
      await _audioRecorder.dispose();
    }
  }
}

class _UnavailableInputDevice extends InputDevice {
  static const _UnavailableInputDevice instance = _UnavailableInputDevice._();

  const _UnavailableInputDevice._()
      : super(id: '__unavailable_input_device__', label: 'Unavailable');
}
