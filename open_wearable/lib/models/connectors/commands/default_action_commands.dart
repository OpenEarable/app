import 'command.dart';
import 'disconnect_command.dart';
import 'list_sensor_configs_command.dart';
import 'list_sensors_command.dart';
import 'runtime.dart';
import 'set_sensor_config_command.dart';
import 'sync_time_command.dart';

List<Command> createDefaultActionCommands(CommandRuntime runtime) {
  return <Command>[
    DisconnectCommand(runtime: runtime),
    SyncTimeCommand(runtime: runtime),
    ListSensorsCommand(runtime: runtime),
    ListSensorConfigsCommand(runtime: runtime),
    SetSensorConfigCommand(runtime: runtime),
  ];
}
