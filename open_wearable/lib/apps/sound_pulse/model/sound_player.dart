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

  Future<void> _playSound() async {
    // Play a simple beep. For simplicity, use a system sound or tone.
    // Since audioplayers can play tones, but for now, assume asset.
    await _audioPlayer.play(AssetSource(soundAsset));
  }

  bool get isPlaying => _isPlaying;

  void dispose() {
    stop();
    _audioPlayer.dispose();
  }

  void changeSound(String newSound) {
    soundAsset = 'lib/apps/sound_pulse/assets/$newSound';
  }
}
