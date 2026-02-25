import 'command.dart';
import 'ipc_internal_param_names.dart';
import 'param_readers.dart';
import 'runtime_command.dart';

class UnsubscribeCommand extends RuntimeCommand {
  UnsubscribeCommand({required super.runtime})
      : super(
          name: 'unsubscribe',
          params: [
            CommandParam<int>(name: 'subscription_id', required: true),
            CommandParam<dynamic>(name: sessionParamName, required: true),
          ],
        );

  @override
  Future<Map<String, dynamic>> execute(List<CommandParam> params) {
    return runtime.unsubscribe(
      session: requireParam(params, sessionParamName),
      subscriptionId: requireIntParam(params, 'subscription_id'),
    );
  }
}
