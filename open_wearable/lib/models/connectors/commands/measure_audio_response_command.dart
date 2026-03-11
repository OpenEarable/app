import 'package:open_earable_flutter/open_earable_flutter.dart';

import 'command.dart';
import 'device_command.dart';
import 'param_readers.dart';

class MeasureAudioResponseCommand extends DeviceCommand {
  MeasureAudioResponseCommand({required super.runtime})
      : super(
          name: 'measure_audio_response',
          params: [
            CommandParam<Map<String, dynamic>>(name: 'args'),
          ],
        );

  @override
  Future<Map<String, dynamic>> execute(List<CommandParam> params) async {
    final wearable = await getWearable(params);
    final manager = requireWearableCapability<AudioResponseManager>(
      wearable,
      action: name,
    );
    return manager.measureAudioResponse(readOptionalMapParam(params, 'args'));
  }
}
