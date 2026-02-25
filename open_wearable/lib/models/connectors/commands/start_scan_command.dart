import 'command.dart';
import 'param_readers.dart';
import 'runtime_command.dart';

class StartScanCommand extends RuntimeCommand {
  StartScanCommand({required super.runtime})
      : super(
          name: 'start_scan',
          params: [
            CommandParam<bool>(name: 'check_and_request_permissions'),
          ],
        );

  @override
  Future<Map<String, dynamic>> execute(List<CommandParam> params) {
    return runtime.startScan(
      checkAndRequestPermissions:
          readOptionalBoolParam(params, 'check_and_request_permissions') ??
              true,
    );
  }
}
