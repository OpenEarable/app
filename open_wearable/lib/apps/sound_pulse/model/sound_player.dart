import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'package:logger/logger.dart';

class SoundPlayer {
  final AudioPlayer _audioPlayer1 = AudioPlayer();
  final AudioPlayer _audioPlayer2 = AudioPlayer();
  Timer? _timer;
  bool _isPlaying = false;
  late String soundAsset;
  final StreamController<bool> _playbackController = StreamController<bool>.broadcast();
  final Logger logger = Logger();
  int _currentPlayerIndex = 0;

  Stream<bool> get playbackStream => _playbackController.stream;

  SoundPlayer({String? soundAsset}) {
    this.soundAsset = soundAsset ?? 'assets/sound_pulse/heart-beat.mp3';
    _audioPlayer1.setVolume(0.0);
    _audioPlayer1.setReleaseMode(ReleaseMode.stop);
    _audioPlayer2.setVolume(0.0);
    _audioPlayer2.setReleaseMode(ReleaseMode.stop);
  }

  AudioPlayer _getCurrentPlayer() {
    return _currentPlayerIndex == 0 ? _audioPlayer1 : _audioPlayer2;
  }

  void _switchPlayer() {
    _currentPlayerIndex = 1 - _currentPlayerIndex;
  }

  void start(double intervalMs) {
    if (_isPlaying) stop();
    _isPlaying = true;
    logger.d("Starting sound player with interval $intervalMs ms");
    _playbackController.add(true);
    _timer = Timer.periodic(Duration(milliseconds: intervalMs.toInt()), (timer) {
      _playSound();
    });
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _isPlaying = false;
    logger.d("Stopping sound player");
    _audioPlayer1.stop();
    _audioPlayer2.stop();
    _playbackController.add(false);
  }

  void updateInterval(double intervalMs) {
    if (_isPlaying) {
      stop();
      start(intervalMs);
    }
  }

  Future<void> playOnce(String asset) async {
    try {
      logger.d("Playing once: $asset");
      final bytes = await rootBundle.load(asset);
      await _audioPlayer1.stop();
      await _audioPlayer1.setVolume(0.0);
      await _audioPlayer1.play(BytesSource(bytes.buffer.asUint8List(), mimeType: _getMimeType(asset)));
      _fadeIn(_audioPlayer1);
    } catch (e) {
      logger.e("Error playing once: $e");
    }
  }

  Future<void> playCurrentOnce() async {
    try {
      final bytes = await rootBundle.load(soundAsset);
      await _audioPlayer1.stop();
      await _audioPlayer1.setVolume(0.0);
      await _audioPlayer1.play(BytesSource(bytes.buffer.asUint8List(), mimeType: _getMimeType(soundAsset)));
      _fadeIn(_audioPlayer1);
    } catch (e) {
      logger.e("Error playing current: $e");
    }
  }

  Future<void> _playSound() async {
    try {
      logger.d("Playing sound: $soundAsset");
      final bytes = await rootBundle.load(soundAsset);
      AudioPlayer player = _getCurrentPlayer();
      _switchPlayer();
      await player.stop();
      await player.setVolume(0.0);
      await player.play(BytesSource(bytes.buffer.asUint8List(), mimeType: _getMimeType(soundAsset)));
      _fadeIn(player);
      // Get duration and schedule fade out
      Duration? duration = await player.getDuration();
      if (duration != null) {
        int fadeOutStartMs = (duration.inMilliseconds - 100).clamp(0, duration.inMilliseconds);
        Timer(Duration(milliseconds: fadeOutStartMs), () {
          _fadeOut(player);
        });
      }
      _playbackController.add(true);
      // Reset after 200ms
      Future.delayed(Duration(milliseconds: 200), () {
        _playbackController.add(false);
      });
    } catch (e) {
      logger.e("Error playing sound: $e");
    }
  }

  void _fadeIn(AudioPlayer player) {
    _fadeVolume(player, 0.0, 1.0, 100);
  }

  void _fadeOut(AudioPlayer player) {
    _fadeVolume(player, 1.0, 0.0, 100);
  }

  void _fadeVolume(AudioPlayer player, double from, double to, int durationMs) {
    const int steps = 10;
    double step = (to - from) / steps;
    int stepDuration = durationMs ~/ steps;
    double current = from;
    int count = 0;
    Timer.periodic(Duration(milliseconds: stepDuration), (timer) {
      current += step;
      player.setVolume(current.clamp(0.0, 1.0));
      count++;
      if (count >= steps) {
        timer.cancel();
      }
    });
  }

  bool get isPlaying => _isPlaying;

  void dispose() {
    _audioPlayer1.dispose();
    _audioPlayer2.dispose();
    _timer?.cancel();
    _playbackController.close();
  }

  void changeSound(String newSound) {
    soundAsset = 'assets/sound_pulse/$newSound';
  }

  String _getMimeType(String asset) {
    if (asset.endsWith('.mp3')) return 'audio/mpeg';
    if (asset.endsWith('.wav')) return 'audio/wav';
    return 'audio/mpeg'; // default
  }
}
