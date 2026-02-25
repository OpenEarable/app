import 'command.dart';
import 'runtime_command.dart';

class ListConnectedCommand extends RuntimeCommand {
  ListConnectedCommand({required super.runtime})
      : super(name: 'list_connected');

  @override
  Future<List<Map<String, dynamic>>> execute(List<CommandParam> params) {
    return runtime.listConnected();
  }
}
