import 'dart:async';
import 'package:logger/logger.dart';
import 'package:open_wearable/models/logger.dart';
import 'package:open_wearable/models/connectors/websocket_audio_playback_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart';
import 'package:open_wearable/models/connectors/websocket_ipc_server.dart';

class _Manager implements WearableManager {
  final connections = StreamController<Wearable>.broadcast(sync: true);
  @override
  Stream<Wearable> get connectStream => connections.stream;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Wearable extends Wearable {
  _Wearable(this.deviceId, WearableDisconnectNotifier notifier)
      : super(name: 'OpenEarable', disconnectNotifier: notifier);
  @override
  final String deviceId;
  @override
  Future<void> disconnect() async {}
}

class _Audio implements WebsocketAudioPlaybackService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  initLogger(Logger(level: Level.off));
  test('tracks connections and disconnects while disabled and across stops',
      () async {
    final manager = _Manager();
    final server = WebSocketIpcServer(wearableManager: manager, audioPlaybackService: _Audio());
    final oldNotifier = WearableDisconnectNotifier();
    final newNotifier = WearableDisconnectNotifier();
    manager.connections.add(_Wearable('left', oldNotifier));
    expect((await server.listConnected()).single['device_id'], 'left');
    await server.stop();
    expect(await server.listConnected(), hasLength(1));
    manager.connections.add(_Wearable('left', newNotifier));
    oldNotifier.notifyListeners();
    expect(await server.listConnected(), hasLength(1));
    newNotifier.notifyListeners();
    expect(await server.listConnected(), isEmpty);
    await server.dispose();
    expect(manager.connections.hasListener, isFalse);
    await manager.connections.close();
  });
}
