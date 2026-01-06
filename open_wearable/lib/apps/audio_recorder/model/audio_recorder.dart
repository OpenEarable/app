import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:playback_capture/data/playback_capture_result.dart';
import 'package:playback_capture/playback_capture.dart';
import 'package:permission_handler/permission_handler.dart';

class AudioRecorder extends ChangeNotifier {
  final PlaybackCapture _playbackCapture = PlaybackCapture();

  bool _isRecording = false;
  String _errorMessage = '';
  List<Uint8List> _audioBuffers = [];

  bool get isRecording => _isRecording;
  String get errorMessage => _errorMessage;
  List<Uint8List> get audioBuffers => _audioBuffers;

  /// Start capturing system audio
  Future<bool> startRecording() async {
    _errorMessage = '';
    notifyListeners();

    final PlaybackCaptureResult result = await _playbackCapture.listenAudio(
      audioDataCallback: (Uint8List data) {
        _audioBuffers.add(data);
        notifyListeners();
      },
    );

    if (result != PlaybackCaptureResult.recording) {
      if (result == PlaybackCaptureResult.missingAudioRecordPermission) {
        // Request microphone permission
        final status = await Permission.microphone.request();
        if (status.isGranted) {
          // Retry after permission granted
          return await startRecording();
        } else {
          _errorMessage = 'Microphone permission denied';
          notifyListeners();
          return false;
        }
      } else if (result == PlaybackCaptureResult.recordRequestDenied) {
        _errorMessage = 'Audio capture request denied by user';
        notifyListeners();
        return false;
      } else {
        _errorMessage = 'Failed to start recording: $result';
        notifyListeners();
        return false;
      }
    }

    // Recording successfully started
    _isRecording = true;
    notifyListeners();
    return true;
  }

  /// Stop capturing audio
  Future<void> stopRecording() async {
    //await _playbackCapture.stopCapture();
    _isRecording = false;
    notifyListeners();
  }

  /// Clear recorded audio buffers
  void clearBuffers() {
    _audioBuffers.clear();
    notifyListeners();
  }

  /// Get total recorded data size in bytes
  int get totalRecordedBytes {
    return _audioBuffers.fold(0, (sum, buffer) => sum + buffer.length);
  }

  @override
  void dispose() {
    //_playbackCapture.stopCapture();
    super.dispose();
  }
}
