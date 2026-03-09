import 'command.dart';
import 'runtime_command.dart';

class StopAudioStreamCommand extends RuntimeCommand {
  StopAudioStreamCommand({required super.runtime})
      : super(name: 'stop_audio_stream');

  @override
  Future<Map<String, dynamic>> execute(List<CommandParam> params) {
    return runtime.stopAudioStream();
  }
}
