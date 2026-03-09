import 'dart:async';
import 'dart:collection';
import 'dart:typed_data';

import 'package:flutter_sound/flutter_sound.dart';

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
  final FlutterSoundPlayer _preloadedPlayer = FlutterSoundPlayer();
  final FlutterSoundPlayer _streamPlayer = FlutterSoundPlayer();

  final Map<String, _StoredSound> _preloadedSounds = <String, _StoredSound>{};
  final Queue<Uint8List> _streamQueue = Queue<Uint8List>();

  bool _playersOpen = false;
  bool _streamActive = false;
  bool _streamUsesFeedApi = false;
  bool _drainingStreamQueue = false;
  double? _streamVolume;
  AudioPlaybackConfig _streamConfig = const AudioPlaybackConfig();

  Future<void> storeSound({
    required String soundId,
    required Uint8List bytes,
    required AudioPlaybackConfig config,
  }) async {
    final sound = _StoredSound(bytes: bytes, config: config);
    _preloadedSounds[soundId] = sound;
    logger.i(
      '[connector.audio] stored sound_id=$soundId sound=$sound',
    );
  }

  Future<AudioPlaybackConfig> playStoredSound({
    required String soundId,
    double? volume,
    AudioPlaybackConfig? overrideConfig,
  }) async {
    await _ensurePlayersOpen();

    final stored = _preloadedSounds[soundId];
    if (stored == null) {
      throw StateError('Unknown sound_id: $soundId');
    }

    final config = overrideConfig ?? stored.config;

    if (volume != null) {
      await _preloadedPlayer.setVolume(volume);
    }

    logger.d("[connector.audio] playing stored sound_id=$soundId with override config: codec=${config.codec.name} sample_rate=${config.sampleRate} num_channels=${config.numChannels}");

    await _preloadedPlayer.stopPlayer();
    await _preloadedPlayer.startPlayer(
      fromDataBuffer: stored.bytes,
      codec: config.codec,
      sampleRate: config.sampleRate,
      numChannels: config.numChannels,
    );

    logger.i(
      '[connector.audio] playing stored sound_id=$soundId codec=${config.codec.name} sample_rate=${config.sampleRate} num_channels=${config.numChannels}',
    );
    return config;
  }

  Future<AudioPlaybackConfig> playFromUrl({
    required String url,
    double? volume,
    AudioPlaybackConfig? config,
  }) async {
    await _ensurePlayersOpen();

    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme) {
      throw ArgumentError('Invalid URL: $url');
    }
    if (uri.scheme != 'http' && uri.scheme != 'https') {
      throw ArgumentError(
        'Only http/https URLs are supported. Got: ${uri.scheme}',
      );
    }
    if (uri.host == 'commons.wikimedia.org' &&
        uri.path.startsWith('/wiki/File:')) {
      throw ArgumentError(
        'URL points to a Wikimedia page, not a direct audio file. Use the raw media URL from upload.wikimedia.org.',
      );
    }

    if (volume != null) {
      await _preloadedPlayer.setVolume(volume);
    }

    final playbackConfig = config ?? const AudioPlaybackConfig();

    await _preloadedPlayer.stopPlayer();

    try {
      await _preloadedPlayer.startPlayer(
        fromURI: url,
        codec: playbackConfig.codec,
      );
    } catch (error) {
      throw StateError(
        'Failed to play URL source. Ensure it is a direct audio file URL (not an HTML page). Original error: $error',
      );
    }

    logger.i(
      '[connector.audio] playing url source=$url codec=${playbackConfig.codec.name}',
    );
    return playbackConfig;
  }

  Future<void> startStream({
    double? volume,
    required AudioPlaybackConfig config,
  }) async {
    await _ensurePlayersOpen();

    _streamActive = true;
    _streamVolume = volume;
    _streamConfig = config;
    _streamQueue.clear();

    await _streamPlayer.stopPlayer();
    if (volume != null) {
      await _streamPlayer.setVolume(volume);
    }

    _streamUsesFeedApi =
        config.codec == Codec.pcm16 || config.codec == Codec.pcmFloat32;

    if (_streamUsesFeedApi) {
      await _streamPlayer.startPlayerFromStream(
        codec: config.codec,
        interleaved: config.interleaved,
        numChannels: config.numChannels,
        sampleRate: config.sampleRate,
        bufferSize: config.bufferSize,
      );
    }

    logger.i(
      '[connector.audio] stream started codec=${config.codec.name} sample_rate=${config.sampleRate} num_channels=${config.numChannels} interleaved=${config.interleaved} buffer_size=${config.bufferSize} mode=${_streamUsesFeedApi ? 'feed' : 'chunk'}',
    );
  }

  Future<void> pushStreamChunk(Uint8List bytes) async {
    if (!_streamActive) {
      throw StateError(
        'Audio stream is not active. Call start_audio_stream first.',
      );
    }

    if (_streamUsesFeedApi) {
      await _streamPlayer.feedUint8FromStream(bytes);
      return;
    }

    _streamQueue.add(bytes);
    unawaited(_drainStreamQueue());
  }

  Future<void> stopStream() async {
    _streamActive = false;
    _streamQueue.clear();
    _streamUsesFeedApi = false;

    if (_playersOpen) {
      await _streamPlayer.stopPlayer();
    }
    logger.i('[connector.audio] stream stopped');
  }

  Future<void> dispose() async {
    await stopStream();
    if (_playersOpen) {
      await _preloadedPlayer.closePlayer();
      await _streamPlayer.closePlayer();
      _playersOpen = false;
    }
  }

  Future<void> _ensurePlayersOpen() async {
    if (_playersOpen) {
      return;
    }
    await _preloadedPlayer.openPlayer();
    await _streamPlayer.openPlayer();
    _playersOpen = true;
  }

  Future<void> _drainStreamQueue() async {
    if (_drainingStreamQueue) {
      return;
    }
    _drainingStreamQueue = true;
    try {
      while (_streamActive && _streamQueue.isNotEmpty) {
        final chunk = _streamQueue.removeFirst();
        if (_streamVolume != null) {
          await _streamPlayer.setVolume(_streamVolume!);
        }
        await _playChunkAndWait(chunk);
      }
    } finally {
      _drainingStreamQueue = false;
    }
  }

  Future<void> _playChunkAndWait(Uint8List bytes) async {
    final completer = Completer<void>();

    await _streamPlayer.stopPlayer();
    await _streamPlayer.startPlayer(
      fromDataBuffer: bytes,
      codec: _streamConfig.codec,
      sampleRate: _streamConfig.sampleRate,
      numChannels: _streamConfig.numChannels,
      whenFinished: () {
        if (!completer.isCompleted) {
          completer.complete();
        }
      },
    );

    await completer.future.timeout(
      const Duration(seconds: 30),
      onTimeout: () {
        logger.w('[connector.audio] stream chunk playback timeout');
      },
    );
  }
}
