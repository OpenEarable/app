import 'command.dart';
import 'runtime.dart';

abstract class RuntimeCommand extends Command {
  final CommandRuntime runtime;

  RuntimeCommand({
    required super.name,
    required this.runtime,
    super.params,
  });
}
