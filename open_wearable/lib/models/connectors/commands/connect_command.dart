import 'command.dart';
import 'param_readers.dart';
import 'runtime_command.dart';

class ConnectCommand extends RuntimeCommand {
  ConnectCommand({required super.runtime})
      : super(
          name: 'connect',
          params: [
            CommandParam<String>(name: 'device_id', required: true),
            CommandParam<bool>(name: 'connected_via_system'),
          ],
        );

  @override
  Future<Map<String, dynamic>> execute(List<CommandParam> params) {
    return runtime.connect(
      deviceId: requireStringParam(params, 'device_id'),
      connectedViaSystem:
          readOptionalBoolParam(params, 'connected_via_system') ?? false,
    );
  }
}
