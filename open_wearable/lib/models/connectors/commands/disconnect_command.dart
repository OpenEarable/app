import 'command.dart';
import 'param_readers.dart';
import 'runtime_command.dart';

class DisconnectCommand extends RuntimeCommand {
  DisconnectCommand({required super.runtime})
      : super(
          name: 'disconnect',
          params: [
            CommandParam<String>(name: 'device_id', required: true),
          ],
        );

  @override
  Future<Map<String, dynamic>> execute(List<CommandParam> params) {
    return runtime.disconnect(
      deviceId: requireStringParam(params, 'device_id'),
    );
  }
}
