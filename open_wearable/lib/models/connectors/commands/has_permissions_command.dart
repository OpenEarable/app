import 'command.dart';
import 'runtime_command.dart';

class HasPermissionsCommand extends RuntimeCommand {
  HasPermissionsCommand({required super.runtime})
      : super(name: 'has_permissions');

  @override
  Future<bool> execute(List<CommandParam> params) {
    return runtime.hasPermissions();
  }
}
