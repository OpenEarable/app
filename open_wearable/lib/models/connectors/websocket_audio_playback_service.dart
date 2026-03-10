import 'dart:typed_data';

import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';

import '../logger.dart';
import 'audio_playback_config.dart';

class _StoredSound {
  final Uint8List bytes;
  final AudioPlaybackConfig config;

  const _StoredSound({
    required this.bytes,
    required this.config,
  });

  @override
  String toString() {
    return '_StoredSound(bytes=${bytes.length}, config=$config)';
  }
}

/// Handles app-side playback for websocket-delivered audio.
class WebsocketAudioPlaybackService {
  final AudioPlayer _preloadedPlayer = AudioPlayer();

  final Map<String, _StoredSound> _preloadedSounds = <String, _StoredSound>{};

  Future<void> storeSound({
    required String soundId,
    required Uint8List bytes,
    required AudioPlaybackConfig config,
  }) async {
    final sound = _StoredSound(bytes: bytes, config: config);
    _preloadedSounds[soundId] = sound;
    logger.i('[connector.audio] stored sound_id=$soundId sound=$sound');
  }

  Future<AudioPlaybackConfig> playStoredSound({
    required String soundId,
    double? volume,
    AudioPlaybackConfig? overrideConfig,
  }) async {
    final stored = _preloadedSounds[soundId];
    if (stored == null) {
      throw StateError('Unknown sound_id: $soundId');
    }

    final config = overrideConfig ?? stored.config;
    if (volume != null) {
      await _preloadedPlayer.setVolume(volume);
    }

    final filePath = await _writeTempAudioFile(
      stored.bytes,
      prefix: 'stored_$soundId',
      extension: config.fileExtension(),
    );

    await _preloadedPlayer.stop();
    await _preloadedPlayer.play(DeviceFileSource(filePath));

    logger.i(
      '[connector.audio] playing stored sound_id=$soundId codec=${config.codec} sample_rate=${config.sampleRate} num_channels=${config.numChannels}',
    );
    return config;
  }

  Future<void> dispose() async {
    await _preloadedPlayer.dispose();
  }

  Future<String> _writeTempAudioFile(
    Uint8List bytes, {
    required String prefix,
    required String extension,
  }) async {
    final dir = await getTemporaryDirectory();
    final file = File(
      '${dir.path}/${prefix}_${DateTime.now().microsecondsSinceEpoch}.$extension',
    );
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }
}
