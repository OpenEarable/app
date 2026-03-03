import 'package:open_wearable/models/connectors/commands/command.dart';

class PingCommand extends Command {
  PingCommand() : super(name: 'ping');

  @override
  Future<Map<String, dynamic>> execute(List<CommandParam> params) async =>
      <String, dynamic>{'ok': true};
}
