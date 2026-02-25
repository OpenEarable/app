import 'command.dart';
import 'param_readers.dart';
import 'runtime_command.dart';

class InvokeActionCommand extends RuntimeCommand {
  InvokeActionCommand({required super.runtime})
      : super(
          name: 'invoke_action',
          params: [
            CommandParam<String>(name: 'device_id', required: true),
            CommandParam<String>(name: 'action', required: true),
            CommandParam<Map<String, dynamic>>(name: 'args'),
          ],
        );

  @override
  Future<Object?> execute(List<CommandParam> params) {
    return runtime.invokeAction(
      deviceId: requireStringParam(params, 'device_id'),
      action: requireStringParam(params, 'action'),
      args: readOptionalMapParam(params, 'args'),
    );
  }
}
