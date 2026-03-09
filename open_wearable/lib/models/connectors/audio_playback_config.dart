import 'package:flutter_sound/flutter_sound.dart';

class AudioPlaybackConfig {
  final Codec codec;
  final int sampleRate;
  final int numChannels;
  final bool interleaved;
  final int bufferSize;

  const AudioPlaybackConfig({
    this.codec = Codec.defaultCodec,
    this.sampleRate = 16000,
    this.numChannels = 1,
    this.interleaved = true,
    this.bufferSize = 8192,
  });

  AudioPlaybackConfig copyWith({
    Codec? codec,
    int? sampleRate,
    int? numChannels,
    bool? interleaved,
    int? bufferSize,
  }) {
    return AudioPlaybackConfig(
      codec: codec ?? this.codec,
      sampleRate: sampleRate ?? this.sampleRate,
      numChannels: numChannels ?? this.numChannels,
      interleaved: interleaved ?? this.interleaved,
      bufferSize: bufferSize ?? this.bufferSize,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'codec': codec.name,
      'sample_rate': sampleRate,
      'num_channels': numChannels,
      'interleaved': interleaved,
      'buffer_size': bufferSize,
    };
  }

  static AudioPlaybackConfig? fromOptional({
    String? codecKey,
    int? sampleRate,
    int? numChannels,
    bool? interleaved,
    int? bufferSize,
  }) {
    // return null if no config parameters are provided, to allow using defaults from stored sound when playing
    if (codecKey == null &&
        sampleRate == null &&
        numChannels == null &&
        interleaved == null &&
        bufferSize == null) {
      return null;
    }

    final parsedCodec =
        codecKey == null ? Codec.defaultCodec : _parseCodec(codecKey);

    final resolvedSampleRate = sampleRate ?? 16000;
    final resolvedNumChannels = numChannels ?? 1;
    final resolvedBufferSize = bufferSize ?? 8192;

    if (resolvedSampleRate <= 0) {
      throw ArgumentError('sample_rate must be > 0');
    }
    if (resolvedNumChannels <= 0) {
      throw ArgumentError('num_channels must be > 0');
    }
    if (resolvedBufferSize <= 0) {
      throw ArgumentError('buffer_size must be > 0');
    }

    return AudioPlaybackConfig(
      codec: parsedCodec,
      sampleRate: resolvedSampleRate,
      numChannels: resolvedNumChannels,
      interleaved: interleaved ?? true,
      bufferSize: resolvedBufferSize,
    );
  }

  static Codec _parseCodec(String input) {
    final normalized =
        input.trim().toLowerCase().replaceAll('_', '').replaceAll('-', '');
    switch (normalized) {
      case 'default':
      case 'defaultcodec':
        return Codec.defaultCodec;
      case 'aacadts':
        return Codec.aacADTS;
      case 'opusogg':
        return Codec.opusOGG;
      case 'opuscaf':
        return Codec.opusCAF;
      case 'mp3':
        return Codec.mp3;
      case 'vorbisogg':
        return Codec.vorbisOGG;
      case 'pcm16':
        return Codec.pcm16;
      case 'pcm16wav':
        return Codec.pcm16WAV;
      case 'pcm16aiff':
        return Codec.pcm16AIFF;
      case 'pcm16caf':
        return Codec.pcm16CAF;
      case 'flac':
        return Codec.flac;
      case 'aacmp4':
        return Codec.aacMP4;
      case 'amrnb':
        return Codec.amrNB;
      case 'amrwb':
        return Codec.amrWB;
      case 'pcm8':
        return Codec.pcm8;
      case 'pcmfloat32':
        return Codec.pcmFloat32;
      case 'pcmwebm':
        return Codec.pcmWebM;
      case 'opuswebm':
        return Codec.opusWebM;
      case 'vorbiswebm':
        return Codec.vorbisWebM;
      case 'pcmfloat32wav':
        return Codec.pcmFloat32WAV;
      default:
        throw ArgumentError('Unsupported codec: $input');
    }
  }

  @override
  String toString() {
    return 'AudioPlaybackConfig(codec: ${codec.name}, sampleRate: $sampleRate, numChannels: $numChannels, interleaved: $interleaved, bufferSize: $bufferSize)';
  }
}
