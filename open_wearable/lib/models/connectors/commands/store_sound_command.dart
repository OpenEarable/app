import 'dart:convert';
import 'dart:typed_data';

import '../audio_playback_config.dart';
import 'command.dart';
import 'param_readers.dart';
import 'runtime_command.dart';

class StoreSoundCommand extends RuntimeCommand {
  StoreSoundCommand({required super.runtime})
      : super(
          name: 'store_sound',
          params: [
            CommandParam<String>(name: 'sound_id', required: true),
            CommandParam<String>(name: 'audio_base64', required: true),
            CommandParam<String>(name: 'codec'),
            CommandParam<int>(name: 'sample_rate'),
            CommandParam<int>(name: 'num_channels'),
            CommandParam<bool>(name: 'interleaved'),
            CommandParam<int>(name: 'buffer_size'),
          ],
        );

  @override
  Future<Map<String, dynamic>> execute(List<CommandParam> params) {
    final soundId = requireStringParam(params, 'sound_id');
    final audioBase64 = requireStringParam(params, 'audio_base64');
    final Uint8List bytes = base64Decode(audioBase64);

    final config = AudioPlaybackConfig.fromOptional(
      codecKey: readOptionalStringParam(params, 'codec'),
      sampleRate: readOptionalIntParam(params, 'sample_rate'),
      numChannels: readOptionalIntParam(params, 'num_channels'),
      interleaved: readOptionalBoolParam(params, 'interleaved'),
      bufferSize: readOptionalIntParam(params, 'buffer_size'),
    );

    return runtime.storeSound(
      soundId: soundId,
      bytes: bytes,
      config: config ?? AudioPlaybackConfig(),
    );
  }
}
