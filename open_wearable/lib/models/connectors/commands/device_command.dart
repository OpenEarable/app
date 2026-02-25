import 'package:open_earable_flutter/open_earable_flutter.dart';
import 'package:open_wearable/models/connectors/commands/command.dart';
import 'package:open_wearable/models/connectors/commands/runtime_command.dart';

abstract class DeviceCommand extends RuntimeCommand {
  DeviceCommand({
    required super.name,
    required super.runtime,
    List<CommandParam> params = const [],
  }) : super(
          params: [
            CommandParam<String>(name: 'device_id', required: true),
            ...params,
          ],
        );

  Future<Wearable> getWearable(List<CommandParam> params) async {
    final deviceId = requireParam<String>(params, 'device_id');
    return runtime.getWearable(deviceId: deviceId);
  }

  T requireWearableCapability<T>(
    Wearable wearable, {
    required String action,
  }) {
    if (!wearable.hasCapability<T>()) {
      throw UnsupportedError(
        'Action "$action" requires capability $T on ${wearable.deviceId}.',
      );
    }
    return wearable.requireCapability<T>();
  }
}
