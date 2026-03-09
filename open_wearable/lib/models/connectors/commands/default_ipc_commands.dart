import 'async_scan_command.dart';
import 'check_and_request_permissions_command.dart';
import 'command.dart';
import 'connect_command.dart';
import 'connect_system_devices_command.dart';
import 'disconnect_command.dart';
import 'get_discovered_devices_command.dart';
import 'has_permissions_command.dart';
import 'invoke_action_command.dart';
import 'list_connected_command.dart';
import 'methods_command.dart';
import 'ping_command.dart';
import 'play_sound_command.dart';
import 'push_audio_stream_chunk_command.dart';
import 'runtime.dart';
import 'start_audio_stream_command.dart';
import 'start_scan_command.dart';
import 'stop_audio_stream_command.dart';
import 'store_sound_command.dart';
import 'subscribe_command.dart';
import 'unsubscribe_command.dart';

List<Command> createDefaultIpcCommands(CommandRuntime runtime) {
  return <Command>[
    PingCommand(),
    MethodsCommand(runtime: runtime),
    HasPermissionsCommand(runtime: runtime),
    CheckAndRequestPermissionsCommand(runtime: runtime),
    StartScanCommand(runtime: runtime),
    AsyncScanCommand(runtime: runtime),
    GetDiscoveredDevicesCommand(runtime: runtime),
    ConnectCommand(runtime: runtime),
    ConnectSystemDevicesCommand(runtime: runtime),
    ListConnectedCommand(runtime: runtime),
    DisconnectCommand(runtime: runtime),
    StoreSoundCommand(runtime: runtime),
    PlaySoundCommand(runtime: runtime),
    StartAudioStreamCommand(runtime: runtime),
    PushAudioStreamChunkCommand(runtime: runtime),
    StopAudioStreamCommand(runtime: runtime),
    SubscribeCommand(runtime: runtime),
    UnsubscribeCommand(runtime: runtime),
    InvokeActionCommand(runtime: runtime),
  ];
}
