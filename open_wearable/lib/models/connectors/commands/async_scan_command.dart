import 'command.dart';
import 'ipc_internal_param_names.dart';
import 'param_readers.dart';
import 'runtime_command.dart';

class AsyncScanCommand extends RuntimeCommand {
  AsyncScanCommand({required super.runtime})
      : super(
          name: 'start_scan_async',
          params: [
            CommandParam<bool>(name: 'check_and_request_permissions'),
            CommandParam<dynamic>(name: sessionParamName, required: true),
          ],
        );

  @override
  Future<Map<String, dynamic>> execute(List<CommandParam> params) async {
    final session = requireParam(params, sessionParamName);
    final checkAndRequestPermissions =
        readOptionalBoolParam(params, 'check_and_request_permissions') ?? true;

    await runtime.startScan(
      checkAndRequestPermissions: checkAndRequestPermissions,
    );

    final subscriptionId = await runtime.createSubscriptionId();
    await runtime.attachStreamSubscription(
      session: session,
      subscriptionId: subscriptionId,
      streamName: 'scan',
      deviceId: 'scanner',
      stream: runtime.scanEvents,
    );

    return <String, dynamic>{
      'started': true,
      'subscription_id': subscriptionId,
      'stream': 'scan',
      'device_id': 'scanner',
    };
  }
}
