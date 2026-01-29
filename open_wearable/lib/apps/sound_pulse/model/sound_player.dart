import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'package:logger/logger.dart';

class SoundPlayer {
  final AudioPlayer _audioPlayer = AudioPlayer();
  Timer? _timer;
  bool _isPlaying = false;
  late String soundAsset;
  final StreamController<bool> _playbackController = StreamController<bool>.broadcast();
  final Logger logger = Logger();

  Stream<bool> get playbackStream => _playbackController.stream;

  SoundPlayer({String? soundAsset}) {
    this.soundAsset = soundAsset ?? 'assets/sound_pulse/beep.mp3';
    _audioPlayer.setVolume(1.0);
    _audioPlayer.setReleaseMode(ReleaseMode.stop);
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
      await _audioPlayer.stop();
      await _audioPlayer.play(BytesSource(bytes.buffer.asUint8List(), mimeType: 'audio/mpeg'));
    } catch (e) {
      logger.e("Error playing once: $e");
    }
  }

  Future<void> playCurrentOnce() async {
    try {
      final bytes = await rootBundle.load(soundAsset);
      await _audioPlayer.stop();
      await _audioPlayer.play(BytesSource(bytes.buffer.asUint8List(), mimeType: 'audio/mpeg'));
    } catch (e) {
      logger.e("Error playing current: $e");
    }
  }

  Future<void> _playSound() async {
    try {
      logger.d("Playing sound: $soundAsset");
      final bytes = await rootBundle.load(soundAsset);
      await _audioPlayer.stop();
      await _audioPlayer.play(BytesSource(bytes.buffer.asUint8List(), mimeType: 'audio/mpeg'));
      _playbackController.add(true);
      // Reset after 200ms
      Future.delayed(Duration(milliseconds: 200), () {
        _playbackController.add(false);
      });
    } catch (e) {
      logger.e("Error playing sound: $e");
    }
  }

  bool get isPlaying => _isPlaying;

  void dispose() {
    _audioPlayer.dispose();
    _timer?.cancel();
    _playbackController.close();
  }

  void changeSound(String newSound) {
    soundAsset = 'assets/sound_pulse/$newSound';
  }
}
