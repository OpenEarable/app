import 'command.dart';
import 'param_readers.dart';
import 'runtime_command.dart';

class ConnectSystemDevicesCommand extends RuntimeCommand {
  ConnectSystemDevicesCommand({required super.runtime})
      : super(
          name: 'connect_system_devices',
          params: [
            CommandParam<List<String>>(name: 'ignored_device_ids'),
          ],
        );

  @override
  Future<List<Map<String, dynamic>>> execute(List<CommandParam> params) {
    return runtime.connectSystemDevices(
      ignoredDeviceIds:
          readOptionalStringListParam(params, 'ignored_device_ids'),
    );
  }
}
