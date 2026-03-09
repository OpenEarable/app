import '../audio_playback_config.dart';
import 'command.dart';
import 'param_readers.dart';
import 'runtime_command.dart';

class StartAudioStreamCommand extends RuntimeCommand {
  StartAudioStreamCommand({required super.runtime})
      : super(
          name: 'start_audio_stream',
          params: [
            CommandParam<double>(name: 'volume'),
            CommandParam<String>(name: 'codec'),
            CommandParam<int>(name: 'sample_rate'),
            CommandParam<int>(name: 'num_channels'),
            CommandParam<bool>(name: 'interleaved'),
            CommandParam<int>(name: 'buffer_size'),
          ],
        );

  @override
  Future<Map<String, dynamic>> execute(List<CommandParam> params) {
    final config = AudioPlaybackConfig.fromOptional(
      codecKey: readOptionalStringParam(params, 'codec'),
      sampleRate: readOptionalIntParam(params, 'sample_rate'),
      numChannels: readOptionalIntParam(params, 'num_channels'),
      interleaved: readOptionalBoolParam(params, 'interleaved'),
      bufferSize: readOptionalIntParam(params, 'buffer_size'),
    );

    return runtime.startAudioStream(
      volume: readOptionalDoubleParam(params, 'volume'),
      config: config ?? AudioPlaybackConfig(),
    );
  }
}
