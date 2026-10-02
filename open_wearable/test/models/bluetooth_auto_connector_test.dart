import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart';
import 'package:open_wearable/models/auto_connect_preferences.dart';
import 'package:open_wearable/models/bluetooth_auto_connector.dart';
import 'package:open_wearable/models/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Wearable extends Wearable {
  _Wearable(this.deviceId, WearableDisconnectNotifier notifier)
      : super(name: 'OpenEarable', disconnectNotifier: notifier);
  @override
  final String deviceId;
  @override
  Future<void> disconnect() async {}
}

class _Manager implements WearableManager {
  final connections = StreamController<Wearable>.broadcast(sync: true);
  final scans = StreamController<DiscoveredDevice>.broadcast();
  final connected = <String, _Wearable>{};
  final notifiers = <String, WearableDisconnectNotifier>{};
  final attempts = <String>[];
  final connectionOptions = <Set<ConnectionOption>>[];
  bool failRight = true;
  int scanStarts = 0;
  @override
  Stream<Wearable> get connectStream => connections.stream;
  @override
  Stream<DiscoveredDevice> get scanStream => scans.stream;
  @override
  Future<void> startScan({bool checkAndRequestPermissions = true}) async { scanStarts++; }
  @override
  Future<List<DiscoveredDevice>> getSystemDevices(
          {bool checkAndRequestPermissions = true,}) async =>
      ['left', 'right', 'unrelated']
          .map((id) => DiscoveredDevice(
              id: id,
              name: id == 'unrelated' ? 'Unknown' : 'OpenEarable',
              manufacturerData: Uint8List(0),
              rssi: -50,
              serviceUuids: [],),)
          .toList();
  @override
  Future<Wearable> connectToDevice(DiscoveredDevice device,
      {Set<ConnectionOption> options = const {},}) async {
    attempts.add(device.id);
    connectionOptions.add(options);
    if (device.id == 'right' && failRight) throw Exception('already connected');
    final notifier = WearableDisconnectNotifier();
    notifiers[device.id] = notifier;
    final wearable = _Wearable(device.id, notifier);
    connected[device.id] = wearable;
    connections.add(wearable);
    return wearable;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  initLogger(Logger(level: Level.off));
  testWidgets(
      'reconciles a missing system ear without scan events or phantom success',
      (tester) async {
    // The macOS test host queries Universal BLE permissions through Pigeon.
    tester.binding.defaultBinaryMessenger.setMockDecodedMessageHandler<Object?>(
      const BasicMessageChannel<Object?>(
          'dev.flutter.pigeon.universal_ble.UniversalBlePlatformChannel.hasPermissions',
          StandardMessageCodec(),),
      (_) async => <Object?>[true],
    );
    SharedPreferences.setMockInitialValues({
      AutoConnectPreferences.connectedDeviceNamesKey: [
        'OpenEarable',
        'OpenEarable',
      ],
    });
    final prefs = await SharedPreferences.getInstance();
    final manager = _Manager();
    final delivered = <String>[];
    final connector = BluetoothAutoConnector(
        navStateGetter: () => null,
        wearableManager: manager,
        prefsFuture: Future.value(prefs),
        connectedWearables: () => manager.connected.values,
        onWearableConnected: (wearable) => delivered.add(wearable.deviceId),);
    connector.start();
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    expect(delivered, ['left']);
    final scanStarts = manager.scanStarts;
    await tester.pump(const Duration(seconds: 3));
    expect(manager.scanStarts, scanStarts); // system retry must not restart an active scan
    manager.failRight = false;
    await tester.pump(const Duration(seconds: 3));
    expect(delivered, ['left', 'right']);
    expect(manager.attempts.where((id) => id == 'left'), hasLength(1));
    expect(manager.attempts, isNot(contains('unrelated')));
    expect(manager.connectionOptions.every((options) => options.single is ConnectedViaSystem), isTrue);
    final attemptsBeforeRestart = manager.attempts.length;
    connector.start(); // duplicate powered-on notification
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    expect(manager.attempts, hasLength(attemptsBeforeRestart));
    connector.stop();
    connector.start(); // resume while both ears remain connected in the app
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    expect(manager.attempts, hasLength(attemptsBeforeRestart));
    manager.connected.remove('left');
    manager.notifiers['left']!.notifyListeners();
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    expect(delivered, ['left', 'right', 'left']);
    connector.stop();
    await manager.connections.close();
    await manager.scans.close();
  });
}
