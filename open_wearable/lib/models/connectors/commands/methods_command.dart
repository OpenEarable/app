import 'command.dart';
import 'runtime_command.dart';

class MethodsCommand extends RuntimeCommand {
  MethodsCommand({required super.runtime}) : super(name: 'methods');

  @override
  Future<List<String>> execute(List<CommandParam> params) async =>
      runtime.methods;
}
