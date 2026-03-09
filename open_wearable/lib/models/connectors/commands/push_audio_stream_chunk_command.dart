import 'dart:convert';
import 'dart:typed_data';

import 'command.dart';
import 'param_readers.dart';
import 'runtime_command.dart';

class PushAudioStreamChunkCommand extends RuntimeCommand {
  PushAudioStreamChunkCommand({required super.runtime})
      : super(
          name: 'push_audio_stream_chunk',
          params: [
            CommandParam<String>(name: 'audio_base64', required: true),
          ],
        );

  @override
  Future<Map<String, dynamic>> execute(List<CommandParam> params) {
    final audioBase64 = requireStringParam(params, 'audio_base64');
    final Uint8List bytes = base64Decode(audioBase64);
    return runtime.pushAudioStreamChunk(bytes: bytes);
  }
}
