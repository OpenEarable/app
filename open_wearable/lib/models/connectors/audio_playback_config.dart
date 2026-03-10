class AudioPlaybackConfig {
  final String codec;
  final int sampleRate;
  final int numChannels;
  final bool interleaved;
  final int bufferSize;

  const AudioPlaybackConfig({
    this.codec = 'default',
    this.sampleRate = 16000,
    this.numChannels = 1,
    this.interleaved = true,
    this.bufferSize = 8192,
  });

  AudioPlaybackConfig copyWith({
    String? codec,
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
      'codec': codec,
      'sample_rate': sampleRate,
      'num_channels': numChannels,
      'interleaved': interleaved,
      'buffer_size': bufferSize,
    };
  }

  String get normalizedCodec => _normalizeCodec(codec);

  static AudioPlaybackConfig? fromOptional({
    String? codecKey,
    int? sampleRate,
    int? numChannels,
    bool? interleaved,
    int? bufferSize,
  }) {
    if (codecKey == null &&
        sampleRate == null &&
        numChannels == null &&
        interleaved == null &&
        bufferSize == null) {
      return null;
    }

    final resolvedCodec = codecKey == null ? 'default' : _parseCodec(codecKey);
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
      codec: resolvedCodec,
      sampleRate: resolvedSampleRate,
      numChannels: resolvedNumChannels,
      interleaved: interleaved ?? true,
      bufferSize: resolvedBufferSize,
    );
  }

  static String _parseCodec(String input) {
    final normalized = _normalizeCodec(input);
    switch (normalized) {
      case 'default':
      case 'aacadts':
      case 'opusogg':
      case 'opuscaf':
      case 'mp3':
      case 'vorbisogg':
      case 'pcm16':
      case 'pcm16wav':
      case 'pcm16aiff':
      case 'pcm16caf':
      case 'flac':
      case 'aacmp4':
      case 'amrnb':
      case 'amrwb':
      case 'pcm8':
      case 'pcmfloat32':
      case 'pcmwebm':
      case 'opuswebm':
      case 'vorbiswebm':
      case 'pcmfloat32wav':
        return normalized;
      default:
        throw ArgumentError('Unsupported codec: $input');
    }
  }

  static String _normalizeCodec(String input) {
    final normalized =
        input.trim().toLowerCase().replaceAll('_', '').replaceAll('-', '');
    if (normalized == 'defaultcodec') {
      return 'default';
    }
    return normalized;
  }

  String fileExtension() {
    switch (normalizedCodec) {
      case 'mp3':
        return 'mp3';
      case 'flac':
        return 'flac';
      case 'aacadts':
      case 'aacmp4':
        return 'm4a';
      case 'pcm16wav':
      case 'pcmfloat32wav':
      case 'pcm16':
      case 'pcmfloat32':
      case 'pcm8':
        return 'wav';
      case 'opusogg':
      case 'vorbisogg':
        return 'ogg';
      case 'opuswebm':
      case 'vorbiswebm':
      case 'pcmwebm':
        return 'webm';
      default:
        return 'bin';
    }
  }

  @override
  String toString() {
    return 'AudioPlaybackConfig(codec: $codec, sampleRate: $sampleRate, numChannels: $numChannels, interleaved: $interleaved, bufferSize: $bufferSize)';
  }
}
