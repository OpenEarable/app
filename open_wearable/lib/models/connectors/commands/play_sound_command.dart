import '../audio_playback_config.dart';
import 'command.dart';
import 'param_readers.dart';
import 'runtime_command.dart';

class PlaySoundCommand extends RuntimeCommand {
  PlaySoundCommand({required super.runtime})
      : super(
          name: 'play_sound',
          params: [
            CommandParam<String>(name: 'sound_id'),
            CommandParam<double>(name: 'volume'),
            CommandParam<String>(name: 'codec'),
            CommandParam<int>(name: 'sample_rate'),
            CommandParam<int>(name: 'num_channels'),
          ],
        );

  @override
  Future<Map<String, dynamic>> execute(List<CommandParam> params) {
    final soundId = readOptionalStringParam(params, 'sound_id');
    if (soundId == null || soundId.isEmpty) {
      throw ArgumentError('play_sound requires "sound_id".');
    }

    final config = AudioPlaybackConfig.fromOptional(
      codecKey: readOptionalStringParam(params, 'codec'),
      sampleRate: readOptionalIntParam(params, 'sample_rate'),
      numChannels: readOptionalIntParam(params, 'num_channels'),
    );

    return runtime.playSound(
      soundId: soundId,
      volume: readOptionalDoubleParam(params, 'volume'),
      config: config,
    );
  }
}
