import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:open_wearable/models/audio_input_source.dart';
import 'package:open_wearable/models/logger.dart';
import 'package:open_wearable/widgets/sensors/local_recorder/local_recorder_models.dart';

/// Platform-specific audio recorder operations used by [AudioInputController].
///
/// Implementations own the underlying recorder plugin/session details. The
/// controller owns user-facing selection state, apply semantics, monitoring
/// lifecycle, and waveform buffering.
abstract class AudioInputPlatform {
  /// Lists available microphone inputs, including any synthetic default source.
  Future<List<AudioInputSource>> listAudioInputSources();

  /// Starts live monitoring for [source].
  Future<bool> startMonitoring(
    AudioInputSource source,
    ValueChanged<double> onLevel,
  );

  /// Stops live monitoring without changing selected or applied source state.
  Future<void> stopMonitoring();

  /// Starts recording [source] into [recordingFolderPath].
  Future<bool> startRecording(
    AudioInputSource source,
    String recordingFolderPath,
    ValueChanged<double> onLevel,
  );

  /// Stops audio recording and returns any files that must be persisted by the
  /// caller. IO platforms usually return an empty list because files are already
  /// written directly to disk; web returns in-memory files.
  Future<List<LocalRecorderDraftFile>> stopRecording();

  /// Releases platform resources.
  Future<void> dispose();
}

/// Owns cross-platform microphone input state and lifecycle transitions.
///
/// This class intentionally contains no `dart:io` or browser APIs. It keeps the
/// virtual microphone row, Apply Profiles behavior, live chart waveform, and
/// recording/monitoring handoff identical across platforms.
class AudioInputController extends ChangeNotifier {
  static const Duration _sourceRefreshInterval = Duration(seconds: 3);
  static const int _maxWaveformSamples = 100;

  final AudioInputPlatform _platform;

  Timer? _sourceRefreshTimer;
  List<AudioInputSource> _sources = const [AudioInputSource.systemDefault];
  AudioInputSource? _selectedSource;
  AudioInputSource? _appliedSource;
  bool _isMonitoringActive = false;
  bool _isRecordingActive = false;
  bool _disposed = false;

  final List<double> _waveformData = [];

  AudioInputController({required AudioInputPlatform platform})
      : _platform = platform;

  /// Available input sources shown in the microphone configuration dropdown.
  List<AudioInputSource> get sources => List.unmodifiable(_sources);

  /// Pending microphone input selected in the configuration UI.
  AudioInputSource? get selectedSource => _selectedSource;

  /// Microphone input currently applied to monitoring/recording.
  AudioInputSource? get appliedSource => _appliedSource;

  /// Whether any audio input is applied or actively using the recorder.
  bool get isEnabled =>
      _appliedSource != null || _isMonitoringActive || _isRecordingActive;

  /// Whether live monitoring is currently active.
  bool get isMonitoringActive => _isMonitoringActive;

  /// Whether microphone recording is currently active.
  bool get isRecordingActive => _isRecordingActive;

  /// Whether the selected source differs from the applied source.
  bool get hasPendingSelection => !_sameSource(_selectedSource, _appliedSource);

  /// Recent normalized audio levels for waveform display.
  List<double> get waveformData => List.unmodifiable(_waveformData);

  /// Starts periodic source discovery while the configuration UI is mounted.
  void startSourceRefresh() {
    if (_sourceRefreshTimer != null) {
      return;
    }
    unawaited(refreshSources());
    _sourceRefreshTimer = Timer.periodic(
      _sourceRefreshInterval,
      (_) => unawaited(refreshSources()),
    );
  }

  /// Stops periodic source discovery.
  void stopSourceRefresh() {
    _sourceRefreshTimer?.cancel();
    _sourceRefreshTimer = null;
  }

  /// Refreshes the platform microphone source list.
  Future<void> refreshSources() async {
    try {
      final nextSources = await _platform.listAudioInputSources();
      if (!_sameSourceList(_sources, nextSources)) {
        _sources = nextSources;
        _notifyListenersIfActive();
      }
    } catch (e) {
      logger.e("Error listing audio input sources: $e");
    }
  }

  /// Selects the pending source used on the next Apply Profiles action.
  Future<void> selectSource(AudioInputSource? source) async {
    if (_isRecordingActive) {
      logger.w("Cannot change audio input while recording is active");
      return;
    }
    if (_sameSource(_selectedSource, source)) {
      return;
    }
    _selectedSource = source;
    _notifyListenersIfActive();
  }

  /// Enables or disables audio input without forgetting the chosen source.
  Future<void> setEnabled(bool enabled) async {
    if (enabled) {
      _selectedSource ??= AudioInputSource.systemDefault;
      await refreshSources();
    } else {
      await selectSource(null);
    }
    _notifyListenersIfActive();
  }

  /// Applies the pending source to live monitoring.
  Future<bool> applySelectedSource() async {
    if (_isRecordingActive) {
      logger.w("Cannot apply audio input while recording is active");
      return false;
    }
    if (!hasPendingSelection) {
      return false;
    }

    final selectedSource = _selectedSource;
    if (selectedSource == null) {
      await _stopMonitoring();
      _appliedSource = null;
      _clearWaveform();
      _notifyListenersIfActive();
      return true;
    }

    if (_isMonitoringActive) {
      await _stopMonitoring(clearWaveform: false);
    }
    _appliedSource = selectedSource;
    final started = await _startMonitoring();
    if (!started) {
      _appliedSource = null;
    }
    _notifyListenersIfActive();
    return started;
  }

  /// Starts live monitoring for the currently applied source.
  Future<bool> startMonitoring() {
    return _startMonitoring();
  }

  /// Stops live monitoring.
  Future<void> stopMonitoring() {
    return _stopMonitoring();
  }

  /// Starts audio recording for the currently applied source.
  Future<void> startRecording(String recordingFolderPath) async {
    final source = _appliedSource;
    if (source == null) {
      return;
    }

    final shouldRestoreMonitoring = _isMonitoringActive;
    if (shouldRestoreMonitoring) {
      await _stopMonitoring(clearWaveform: false, notify: false);
    }

    final started = await _platform.startRecording(
      source,
      recordingFolderPath,
      _appendLevel,
    );
    _isRecordingActive = started;
    if (!started) {
      await _restoreMonitoringIfNeeded(shouldRestoreMonitoring);
    }
    _notifyListenersIfActive();
  }

  /// Stops audio recording and optionally turns the applied microphone off.
  Future<List<LocalRecorderDraftFile>> stopRecording({
    required bool turnOffMic,
  }) async {
    final draftFiles = _isRecordingActive
        ? await _platform.stopRecording()
        : const <LocalRecorderDraftFile>[];
    _isRecordingActive = false;

    if (turnOffMic) {
      await selectSource(null);
      await _stopMonitoring();
      _appliedSource = null;
      _clearWaveform();
      _notifyListenersIfActive();
    } else if (_appliedSource != null) {
      await _startMonitoring();
    }

    _notifyListenersIfActive();
    return draftFiles;
  }

  Future<bool> _startMonitoring() async {
    if (_isMonitoringActive) {
      return true;
    }
    final source = _appliedSource;
    if (source == null) {
      return false;
    }
    final started = await _platform.startMonitoring(source, _appendLevel);
    _isMonitoringActive = started;
    if (!started) {
      _notifyListenersIfActive();
      return false;
    }
    _notifyListenersIfActive();
    return true;
  }

  Future<void> _stopMonitoring({
    bool clearWaveform = true,
    bool notify = true,
  }) async {
    if (!_isMonitoringActive) {
      if (clearWaveform && _waveformData.isNotEmpty) {
        _clearWaveform();
        if (notify) {
          _notifyListenersIfActive();
        }
      }
      return;
    }
    try {
      await _platform.stopMonitoring();
    } catch (e) {
      logger.e("Error stopping audio monitoring: $e");
    } finally {
      _isMonitoringActive = false;
      if (clearWaveform) {
        _clearWaveform();
      }
      if (notify) {
        _notifyListenersIfActive();
      }
    }
  }

  Future<void> _restoreMonitoringIfNeeded(bool shouldRestore) async {
    if (!shouldRestore || _disposed || _appliedSource == null) {
      return;
    }
    await _startMonitoring();
  }

  void _appendLevel(double level) {
    _waveformData.add(level.clamp(0.0, 1.0));
    if (_waveformData.length > _maxWaveformSamples) {
      _waveformData.removeAt(0);
    }
    _notifyListenersIfActive();
  }

  void _clearWaveform() {
    _waveformData.clear();
  }

  bool _sameSource(AudioInputSource? left, AudioInputSource? right) {
    if (left == null || right == null) {
      return left == null && right == null;
    }
    return left.id == right.id;
  }

  bool _sameSourceList(
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

  void _notifyListenersIfActive() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    stopSourceRefresh();
    unawaited(_platform.dispose());
    _waveformData.clear();
    super.dispose();
  }
}
