import 'command.dart';
import 'runtime_command.dart';

class CheckAndRequestPermissionsCommand extends RuntimeCommand {
  CheckAndRequestPermissionsCommand({required super.runtime})
      : super(name: 'check_and_request_permissions');

  @override
  Future<bool> execute(List<CommandParam> params) {
    return runtime.checkAndRequestPermissions();
  }
}
