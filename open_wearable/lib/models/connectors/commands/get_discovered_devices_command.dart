import 'command.dart';
import 'runtime_command.dart';

class GetDiscoveredDevicesCommand extends RuntimeCommand {
  GetDiscoveredDevicesCommand({required super.runtime})
      : super(name: 'get_discovered_devices');

  @override
  Future<List<Map<String, dynamic>>> execute(List<CommandParam> params) {
    return runtime.getDiscoveredDevices();
  }
}
