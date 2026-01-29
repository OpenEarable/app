import 'dart:async';
import 'package:audioplayers/audioplayers.dart';

class SoundPlayer {
  final AudioPlayer _audioPlayer = AudioPlayer();
  Timer? _timer;
  bool _isPlaying = false;
  String soundAsset;

  SoundPlayer({String? soundAsset}) : soundAsset = soundAsset ?? 'lib/apps/sound_pulse/assets/beep.mp3';

  void start(double intervalMs) {
    if (_isPlaying) stop();
    _isPlaying = true;
    _timer = Timer.periodic(Duration(milliseconds: intervalMs.toInt()), (timer) {
      _playSound();
    });
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _isPlaying = false;
  }

  void updateInterval(double intervalMs) {
    if (_isPlaying) {
      stop();
      start(intervalMs);
    }
  }

  Future<void> playOnce(String asset) async {
    try {
      await _audioPlayer.play(AssetSource(asset));
    } catch (e) {
      // Ignore if asset not found or invalid
    }
  }

  Future<void> _playSound() async {
    try {
      await _audioPlayer.play(AssetSource(soundAsset));
    } catch (e) {
      // Ignore if asset not found or invalid
    }
  }

  bool get isPlaying => _isPlaying;

  void dispose() {
    _audioPlayer.dispose();
    _timer?.cancel();
  }

  void changeSound(String newSound) {
    soundAsset = 'lib/apps/sound_pulse/assets/$newSound';
  }
}
