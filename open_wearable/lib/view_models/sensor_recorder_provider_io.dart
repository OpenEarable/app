import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart' hide logger;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../models/audio_input_source.dart';
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
  static const Duration _microphoneConfigurationSettleDelay =
      Duration(milliseconds: 300);

  final Map<Wearable, Map<Sensor, Recorder>> _recorders = {};
  final Map<String, String> _recordingFilepathsBySensorIdentity = {};
  Future<void> _pendingSynchronization = Future<void>.value();
  bool _disposed = false;

  bool _isRecording = false;
  bool _hasSensorsConnected = false;
  String? _currentDirectory;
  DateTime? _recordingStart;
  final AudioRecorder _audioRecorder = AudioRecorder();
  static const Duration _audioInputRefreshInterval = Duration(seconds: 3);
  bool _isAudioRecording = false;
  String? _currentAudioPath;
  StreamSubscription<Amplitude>? _amplitudeSub;
  Timer? _audioInputRefreshTimer;
  List<InputDevice> _availableInputDevices = const [];
  List<AudioInputSource> _audioInputSources = const [
    AudioInputSource.systemDefault,
  ];
  AudioInputSource? _selectedAudioInputSource;
  AudioInputSource? _appliedAudioInputSource;

  bool get isRecording => _isRecording;
  bool get hasSensorsConnected => _hasSensorsConnected;
  String? get currentDirectory => _currentDirectory;
  DateTime? get recordingStart => _recordingStart;
  List<AudioInputSource> get audioInputSources =>
      List.unmodifiable(_audioInputSources);
  AudioInputSource? get selectedAudioInputSource => _selectedAudioInputSource;
  AudioInputSource? get appliedAudioInputSource => _appliedAudioInputSource;
  bool get isAudioInputEnabled =>
      _appliedAudioInputSource != null ||
      _isStreamingActive ||
      _isAudioRecording;
  bool get isAudioMonitoringActive => _isStreamingActive;
  bool get isAudioInputSelectionPending => !_sameAudioInputSource(
        _selectedAudioInputSource,
        _appliedAudioInputSource,
      );

  final List<double> _waveformData = [];
  List<double> get waveformData => List.unmodifiable(_waveformData);

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

  // Path for temporary streaming file
  String? _streamingPath;
  bool _isStreamingActive = false;

  /// Starts periodic microphone discovery while microphone settings UI exists.
  void startAudioInputSourceRefresh() {
    if (_audioInputRefreshTimer != null) {
      return;
    }
    unawaited(refreshAudioInputSources());
    _audioInputRefreshTimer = Timer.periodic(
      _audioInputRefreshInterval,
      (_) => unawaited(refreshAudioInputSources()),
    );
  }

  /// Stops periodic microphone discovery when no UI needs it.
  void stopAudioInputSourceRefresh() {
    _audioInputRefreshTimer?.cancel();
    _audioInputRefreshTimer = null;
  }

  /// Refreshes the platform microphone list used by the virtual microphone row.
  Future<void> refreshAudioInputSources() async {
    try {
      final devices = await _audioRecorder.listInputDevices();
      final uniqueDevices = <InputDevice>[];
      final seenDeviceIds = <String>{};
      for (final device in devices) {
        if (seenDeviceIds.add(device.id)) {
          uniqueDevices.add(device);
        }
      }
      final nextSources = [
        AudioInputSource.systemDefault,
        ...uniqueDevices.map(
          (device) => AudioInputSource(
            id: device.id,
            label: device.label,
            kind: classifyAudioInputSourceLabel(device.label),
          ),
        ),
      ];
      if (!_sameInputDevices(_availableInputDevices, uniqueDevices) ||
          !_sameAudioInputSources(_audioInputSources, nextSources)) {
        _availableInputDevices = uniqueDevices;
        _audioInputSources = nextSources;
        _notifyListenersIfActive();
      }
    } catch (e) {
      logger.e("Error listing audio input devices: $e");
    }
  }

  /// Selects the app-local microphone source used by local recordings.
  ///
  /// Passing `null` turns audio capture off while leaving wearable sensor
  /// configuration untouched.
  Future<void> selectAudioInputSource(AudioInputSource? source) async {
    if (_isAudioRecording) {
      logger.w("Cannot change audio input while recording is active");
      return;
    }

    if (_sameAudioInputSource(_selectedAudioInputSource, source)) {
      return;
    }

    _selectedAudioInputSource = source;
    _notifyListenersIfActive();
  }

  /// Enables or disables audio capture without changing the remembered source.
  Future<void> setAudioInputEnabled(bool enabled) async {
    if (enabled) {
      _selectedAudioInputSource ??= AudioInputSource.systemDefault;
      await refreshAudioInputSources();
    } else {
      await selectAudioInputSource(null);
    }
    _notifyListenersIfActive();
  }

  InputDevice? _inputDeviceForSource(AudioInputSource source) {
    if (source.isSystemDefault) {
      return null;
    }
    for (final device in _availableInputDevices) {
      if (device.id == source.id) {
        return device;
      }
    }
    return null;
  }

  bool _sameAudioInputSource(
    AudioInputSource? left,
    AudioInputSource? right,
  ) {
    if (left == null || right == null) {
      return left == null && right == null;
    }
    return left.id == right.id;
  }

  bool _sameInputDevices(List<InputDevice> left, List<InputDevice> right) {
    if (left.length != right.length) {
      return false;
    }
    for (var i = 0; i < left.length; i++) {
      if (left[i].id != right[i].id || left[i].label != right[i].label) {
        return false;
      }
    }
    return true;
  }

  bool _sameAudioInputSources(
    List<AudioInputSource> left,
    List<AudioInputSource> right,
  ) {
    if (left.length != right.length) {
      return false;
    }
    for (var i = 0; i < left.length; i++) {
      if (left[i] != right[i]) {
        return false;
      }
    }
    return true;
  }

  Future<bool> startAudioMonitoring() async {
    return _startAudioMonitoring();
  }

  Future<void> stopAudioMonitoring() async {
    await _stopAudioMonitoring();
  }

  /// Applies the pending microphone selection to the live monitoring stream.
  ///
  /// Selecting a source in the sensor configuration tab only changes local
  /// pending state. Calling this method mirrors the wearable profile apply
  /// flow by starting or stopping the actual microphone stream.
  Future<bool> applySelectedAudioInputSource() async {
    if (_isAudioRecording) {
      logger.w("Cannot apply audio input while recording is active");
      return false;
    }
    if (!isAudioInputSelectionPending) {
      return false;
    }

    final selectedSource = _selectedAudioInputSource;
    if (selectedSource == null) {
      await _stopAudioMonitoring();
      _appliedAudioInputSource = null;
      _waveformData.clear();
      _notifyListenersIfActive();
      return true;
    }

    if (_isStreamingActive) {
      await _stopAudioMonitoring(clearWaveform: false);
    }
    _appliedAudioInputSource = selectedSource;
    final started = await startAudioMonitoring();
    if (started) {
      _notifyListenersIfActive();
    } else {
      _appliedAudioInputSource = null;
      _notifyListenersIfActive();
    }
    return started;
  }

  Future<bool> _startAudioMonitoring() async {
    if (_isStreamingActive) {
      logger.i("Audio input monitoring already active");
      return true;
    }

    try {
      final source = _appliedAudioInputSource;
      if (source == null) {
        logger.w("No audio input selected for monitoring");
        return false;
      }
      if (!await _audioRecorder.hasPermission()) {
        logger.w("No microphone permission for monitoring");
        return false;
      }

      await refreshAudioInputSources();
      final selectedDevice = _inputDeviceForSource(source);
      if (!source.isSystemDefault && selectedDevice == null) {
        logger.w("Selected audio input is unavailable: ${source.label}");
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
        device: selectedDevice,
      );

      await _audioRecorder.start(config, path: _streamingPath!);
      _isStreamingActive = true;

      // Set up amplitude monitoring for waveform display
      _amplitudeSub?.cancel();
      _amplitudeSub = _audioRecorder
          .onAmplitudeChanged(const Duration(milliseconds: 100))
          .listen((amp) {
        final normalized = (amp.current + 50) / 50;
        _waveformData.add(normalized.clamp(0.0, 1.0));

        if (_waveformData.length > 100) {
          _waveformData.removeAt(0);
        }

        _notifyListenersIfActive();
      });

      logger.i(
        "Audio monitoring started with input: ${source.label}",
      );
      _notifyListenersIfActive();
      return true;
    } catch (e) {
      logger.e("Failed to start audio monitoring: $e");
      _isStreamingActive = false;
      _streamingPath = null;
      _notifyListenersIfActive();
      return false;
    }
  }

  /// Stops the temporary monitoring session without changing the applied source.
  Future<void> _stopAudioMonitoring({
    bool clearWaveform = true,
    bool notify = true,
  }) async {
    if (!_isStreamingActive) {
      return;
    }

    try {
      await _audioRecorder.stop();
      _amplitudeSub?.cancel();
      _amplitudeSub = null;
      _isStreamingActive = false;
      if (clearWaveform) {
        _waveformData.clear();
      }
      await _deleteStreamingFile();

      logger.i("Audio monitoring stopped");
      if (notify) {
        _notifyListenersIfActive();
      }
    } catch (e) {
      logger.e("Error stopping audio monitoring: $e");
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

    await _startAudioRecording(dirname);

    _notifyListenersIfActive();
  }

  Future<void> _startAudioRecording(String recordingFolderPath) async {
    final source = _appliedAudioInputSource;
    if (source == null) {
      return;
    }

    final shouldRestoreMonitoring = _isStreamingActive;
    if (shouldRestoreMonitoring) {
      await _stopAudioMonitoring(clearWaveform: false, notify: false);
    }

    try {
      if (!await _audioRecorder.hasPermission()) {
        logger.w("No microphone permission for recording");
        await _restoreAudioMonitoringIfNeeded(shouldRestoreMonitoring);
        return;
      }

      await refreshAudioInputSources();
      final selectedDevice = _inputDeviceForSource(source);
      if (!source.isSystemDefault && selectedDevice == null) {
        logger.w(
          "Selected audio input is unavailable, skipping audio recording: ${source.label}",
        );
        await _restoreAudioMonitoringIfNeeded(shouldRestoreMonitoring);
        return;
      }

      const encoder = AudioEncoder.wav;
      if (!await _audioRecorder.isEncoderSupported(encoder)) {
        logger.w("WAV encoder not supported");
        await _restoreAudioMonitoringIfNeeded(shouldRestoreMonitoring);
        return;
      }

      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
      final audioPath = '$recordingFolderPath/audio_$timestamp.wav';

      final config = RecordConfig(
        encoder: encoder,
        sampleRate: 48000, // Set to 48kHz for BLE audio quality
        bitRate: 768000, // 16-bit * 48kHz * 1 channel = 768 kbps
        numChannels: 1,
        device: selectedDevice,
      );

      await _audioRecorder.start(config, path: audioPath);
      _currentAudioPath = audioPath;
      _isAudioRecording = true;

      logger.i(
        "Audio recording started: $_currentAudioPath with input: ${source.label}",
      );

      _amplitudeSub = _audioRecorder
          .onAmplitudeChanged(const Duration(milliseconds: 100))
          .listen((amp) {
        final normalized = (amp.current + 50) / 50;
        _waveformData.add(normalized.clamp(0.0, 1.0));

        if (_waveformData.length > 100) {
          _waveformData.removeAt(0);
        }

        _notifyListenersIfActive();
      });
    } catch (e) {
      logger.e("Failed to start audio recording: $e");
      _isAudioRecording = false;
      await _restoreAudioMonitoringIfNeeded(shouldRestoreMonitoring);
    }
  }

  /// Stops active wearable and audio recording streams and finalizes files.
  Future<void> stopRecording(bool turnOffMic) async {
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

    if (turnOffMic) {
      await selectAudioInputSource(null);
      await _stopAudioMonitoring();
      _appliedAudioInputSource = null;
      _waveformData.clear();
      _notifyListenersIfActive();
    } else if (_appliedAudioInputSource != null) {
      await startAudioMonitoring();
    }

    _notifyListenersIfActive();
  }

  /// Restarts monitoring when recording could not take over the audio input.
  Future<void> _restoreAudioMonitoringIfNeeded(bool shouldRestore) async {
    if (!shouldRestore || _disposed || _appliedAudioInputSource == null) {
      return;
    }
    await _startAudioMonitoring();
  }

  /// Deletes the temporary file used by the live monitoring recorder session.
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
    stopAudioInputSourceRefresh();
    _amplitudeSub?.cancel();
    _amplitudeSub = null;
    _isStreamingActive = false;
    _isAudioRecording = false;
    _waveformData.clear();
    unawaited(() async {
      try {
        await _audioRecorder.stop();
        await _deleteStreamingFile();
      } catch (e) {
        logger.e("Error stopping audio in dispose: $e");
      } finally {
        await _audioRecorder.dispose();
      }
    }());
    for (final wearable in _recorders.keys.toList()) {
      _disposeWearable(wearable);
    }
    _recordingFilepathsBySensorIdentity.clear();
    _recorders.clear();
    super.dispose();
  }
}
