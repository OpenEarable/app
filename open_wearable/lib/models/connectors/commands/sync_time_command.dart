import 'package:open_earable_flutter/open_earable_flutter.dart';
import 'device_command.dart';

import 'command.dart';

class SyncTimeCommand extends DeviceCommand {
  SyncTimeCommand({required super.runtime}) : super(name: 'synchronize_time');

  @override
  Future<Map<String, dynamic>> execute(List<CommandParam> params) async {
    final wearable = await getWearable(params);
    await requireWearableCapability<TimeSynchronizable>(
      wearable,
      action: name,
    ).synchronizeTime();
    return <String, dynamic>{'synchronized': true};
  }
}
