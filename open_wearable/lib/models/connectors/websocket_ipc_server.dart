import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:open_earable_flutter/open_earable_flutter.dart' hide logger;
import 'package:open_wearable/models/connectors/commands/command.dart';
import 'package:open_wearable/models/connectors/commands/default_action_commands.dart';
import 'package:open_wearable/models/connectors/commands/default_ipc_commands.dart';
import 'package:open_wearable/models/connectors/commands/ipc_internal_param_names.dart';
import 'package:open_wearable/models/connectors/commands/runtime.dart';
import 'package:open_wearable/models/logger.dart';
import 'package:open_wearable/models/wearable_connector.dart';

class WebSocketIpcServer implements CommandRuntime {
  static const String defaultHost = '127.0.0.1';
  static const int defaultPort = 8765;
  static const String defaultPath = '/ws';

  final WearableManager _wearableManager;
  final WearableConnector _wearableConnector;

  HttpServer? _httpServer;
  String _host = defaultHost;
  int _port = defaultPort;
  String _path = defaultPath;

  final Map<String, DiscoveredDevice> _discoveredDevicesById =
      <String, DiscoveredDevice>{};
  final Map<String, Wearable> _connectedWearablesById = <String, Wearable>{};
  final Set<_ClientSession> _clients = <_ClientSession>{};

  StreamSubscription<DiscoveredDevice>? _scanSubscription;
  StreamSubscription<DiscoveredDevice>? _connectingSubscription;
  StreamSubscription<Wearable>? _connectSubscription;

  int _nextSubscriptionId = 1;
  final Map<String, Command> _topLevelCommands = <String, Command>{};
  final Map<String, Command> _actionCommands = <String, Command>{};

  WebSocketIpcServer({
    WearableManager? wearableManager,
    WearableConnector? wearableConnector,
  })  : _wearableManager = wearableManager ?? WearableManager(),
        _wearableConnector = wearableConnector ?? WearableConnector() {
    for (final command in createDefaultIpcCommands(this)) {
      addCommand(command);
    }
    for (final command in createDefaultActionCommands(this)) {
      addActionCommand(command);
    }
  }

  bool get isRunning => _httpServer != null;

  Uri get endpoint => Uri(
        scheme: 'ws',
        host: _host,
        port: _port,
        path: _path,
      );

  Future<void> start({
    required String host,
    required int port,
    required String path,
  }) async {
    await stop();

    _host = host.trim();
    _port = port;
    _path = _normalizePath(path);

    _httpServer = await HttpServer.bind(_host, _port, shared: true);
    _attachManagerSubscriptions();

    unawaited(
      _httpServer!.forEach((request) async {
        if (request.uri.path != _path ||
            !WebSocketTransformer.isUpgradeRequest(request)) {
          request.response
            ..statusCode = HttpStatus.notFound
            ..headers.contentType = ContentType.text
            ..write('OpenWearables WebSocket IPC endpoint: $_path')
            ..close();
          return;
        }

        final socket = await WebSocketTransformer.upgrade(request);
        final session = _ClientSession(
          socket: socket,
          server: this,
        );
        _clients.add(session);
        session.start();
      }),
    );
  }

  Future<void> stop() async {
    final server = _httpServer;
    _httpServer = null;

    if (server != null) {
      await server.close(force: true);
    }

    final sessions = _clients.toList(growable: false);
    _clients.clear();
    for (final session in sessions) {
      await session.close();
    }

    await _scanSubscription?.cancel();
    await _connectingSubscription?.cancel();
    await _connectSubscription?.cancel();
    _scanSubscription = null;
    _connectingSubscription = null;
    _connectSubscription = null;

    _discoveredDevicesById.clear();
    _connectedWearablesById.clear();
  }

  void _onClientClosed(_ClientSession client) {
    _clients.remove(client);
  }

  @override
  List<String> get methods => _topLevelCommands.keys.toList(growable: false);

  void addCommand(Command command) {
    _topLevelCommands[command.name] = command;
  }

  void addActionCommand(Command command) {
    _actionCommands[command.name] = command;
  }

  Future<Object?> _handleRequest({
    required _ClientSession client,
    required String method,
    required Map<String, dynamic> params,
  }) async {
    logger.d("Received request: method=$method, params=$params");

    final command = _topLevelCommands[method];
    if (command == null) {
      throw UnsupportedError('Unknown method: $method');
    }
    return command.run(_paramsToCommandParams(params, session: client));
  }

  @override
  Future<Wearable> getWearable({required String deviceId}) async {
    return _requireConnectedWearable(deviceId);
  }

  @override
  Future<bool> hasPermissions() => _wearableManager.hasPermissions();

  @override
  Future<bool> checkAndRequestPermissions() =>
      WearableManager.checkAndRequestPermissions();

  @override
  Future<Map<String, dynamic>> startScan({
    bool checkAndRequestPermissions = true,
  }) async {
    _discoveredDevicesById.clear();
    await _wearableManager.startScan(
      checkAndRequestPermissions: checkAndRequestPermissions,
    );
    return <String, dynamic>{'started': true};
  }

  @override
  Future<List<Map<String, dynamic>>> getDiscoveredDevices() async {
    return _discoveredDevicesById.values.map(_serializeDiscovered).toList();
  }

  @override
  Future<Map<String, dynamic>> connect({
    required String deviceId,
    bool connectedViaSystem = false,
  }) async {
    final discovered = _discoveredDevicesById[deviceId];
    if (discovered == null) {
      throw StateError('Device not found in discovered devices: $deviceId');
    }

    final options = connectedViaSystem
        ? <ConnectionOption>{const ConnectedViaSystem()}
        : const <ConnectionOption>{};

    final wearable = await _wearableConnector.connect(
      discovered,
      options: options,
    );
    _registerConnectedWearable(wearable);
    return _serializeWearableSummary(wearable);
  }

  @override
  Future<List<Map<String, dynamic>>> connectSystemDevices({
    List<String> ignoredDeviceIds = const <String>[],
  }) async {
    final wearables = await _wearableConnector.connectToSystemDevices(
      ignoredDeviceIds: ignoredDeviceIds,
    );
    for (final wearable in wearables) {
      _registerConnectedWearable(wearable);
    }
    return wearables.map(_serializeWearableSummary).toList();
  }

  @override
  Future<List<Map<String, dynamic>>> listConnected() async {
    return _connectedWearablesById.values
        .map(_serializeWearableSummary)
        .toList();
  }

  @override
  Future<Map<String, dynamic>> disconnect({
    required String deviceId,
  }) async {
    final wearable = _requireConnectedWearable(deviceId);
    await wearable.disconnect();
    _connectedWearablesById.remove(deviceId);
    return <String, dynamic>{'disconnected': true};
  }

  @override
  Future<int> createSubscriptionId() async {
    return _nextSubscriptionId++;
  }

  @override
  Future<void> attachStreamSubscription({
    required dynamic session,
    required int subscriptionId,
    required String streamName,
    required String deviceId,
    required Stream<dynamic> stream,
  }) async {
    final _ClientSession client = session as _ClientSession;
    await client.subscribe(
      subscriptionId: subscriptionId,
      streamName: streamName,
      deviceId: deviceId,
      stream: stream,
      serializer: _serializeStreamData,
    );
  }

  @override
  Future<Map<String, dynamic>> unsubscribe({
    required dynamic session,
    required int subscriptionId,
  }) async {
    final _ClientSession client = session as _ClientSession;
    return client.unsubscribe(subscriptionId);
  }

  @override
  Future<Object?> invokeAction({
    required String deviceId,
    required String action,
    Map<String, dynamic> args = const <String, dynamic>{},
  }) async {
    final command = _actionCommands[action];
    if (command == null) {
      throw UnsupportedError('Unsupported action: $action');
    }
    final actionParams = <CommandParam<dynamic>>[
      CommandParam<dynamic>(name: 'device_id', value: deviceId),
      ..._paramsToCommandParams(args, session: null),
    ];
    return command.run(actionParams);
  }

  List<CommandParam<dynamic>> _paramsToCommandParams(
    Map<String, dynamic> params, {
    required _ClientSession? session,
  }) {
    final commandParams = <CommandParam<dynamic>>[];
    if (session != null) {
      commandParams
          .add(CommandParam<dynamic>(name: sessionParamName, value: session));
    }
    params.forEach((key, value) {
      commandParams.add(CommandParam<dynamic>(name: key, value: value));
    });
    return commandParams;
  }

  void _attachManagerSubscriptions() {
    _scanSubscription ??= _wearableManager.scanStream.listen((device) {
      _discoveredDevicesById[device.id] = device;
      _broadcastEvent(
        <String, dynamic>{
          'event': 'scan',
          'device': _serializeDiscovered(device),
        },
      );
    });

    _connectingSubscription ??=
        _wearableManager.connectingStream.listen((device) {
      _broadcastEvent(
        <String, dynamic>{
          'event': 'connecting',
          'device': _serializeDiscovered(device),
        },
      );
    });

    _connectSubscription ??= _wearableManager.connectStream.listen((wearable) {
      _registerConnectedWearable(wearable);
      _broadcastEvent(
        <String, dynamic>{
          'event': 'connected',
          'wearable': _serializeWearableSummary(wearable),
        },
      );
    });
  }

  void _registerConnectedWearable(Wearable wearable) {
    _connectedWearablesById[wearable.deviceId] = wearable;
    wearable.addDisconnectListener(() {
      _connectedWearablesById.remove(wearable.deviceId);
    });
  }

  void _broadcastEvent(Map<String, dynamic> event) {
    final payload = _jsonEncode(event);
    for (final client in _clients.toList(growable: false)) {
      client.sendRaw(payload);
    }
  }

  void _sendReady(_ClientSession client) {
    client.send(
      <String, dynamic>{
        'event': 'ready',
        'methods': methods,
      },
    );
  }


  Map<String, dynamic> _serializeDiscovered(DiscoveredDevice device) {
    return <String, dynamic>{
      'id': device.id,
      'name': device.name,
      'service_uuids': device.serviceUuids,
      'manufacturer_data': device.manufacturerData.toList(),
      'rssi': device.rssi,
    };
  }

  Map<String, dynamic> _serializeWearableSummary(Wearable wearable) {
    return <String, dynamic>{
      'device_id': wearable.deviceId,
      'name': wearable.name,
      'type': wearable.runtimeType.toString(),
      'capabilities': _capabilitiesForWearable(wearable),
    };
  }

  Object? _serializeStreamData(dynamic data) {
    if (data is SensorValue) {
      final payload = <String, dynamic>{
        'timestamp': data.timestamp,
        'value_strings': data.valueStrings,
      };
      if (data is SensorDoubleValue) {
        payload['values'] = data.values;
      } else if (data is SensorIntValue) {
        payload['values'] = data.values;
      }
      return payload;
    }
    if (data is ButtonEvent) {
      return data.name;
    }
    if (data is BatteryPowerStatus) {
      return _serializeBatteryPowerStatus(data);
    }
    if (data is BatteryHealthStatus) {
      return _serializeBatteryHealthStatus(data);
    }
    if (data is BatteryEnergyStatus) {
      return _serializeBatteryEnergyStatus(data);
    }
    if (data is Map<SensorConfiguration, SensorConfigurationValue>) {
      return data.entries
          .map(
            (entry) => <String, dynamic>{
              'name': entry.key.name,
              'value_key': entry.value.key,
            },
          )
          .toList();
    }

    return _jsonSafe(data);
  }

  Map<String, dynamic> _serializeBatteryPowerStatus(BatteryPowerStatus status) {
    return <String, dynamic>{
      'battery_present': status.batteryPresent,
      'wired_external_power_source_connected':
          status.wiredExternalPowerSourceConnected.name,
      'wireless_external_power_source_connected':
          status.wirelessExternalPowerSourceConnected.name,
      'charge_state': status.chargeState.name,
      'charge_level': status.chargeLevel.name,
      'charging_type': status.chargingType.name,
      'charging_fault_reason':
          status.chargingFaultReason.map((item) => item.name).toList(),
    };
  }

  Map<String, dynamic> _serializeBatteryHealthStatus(
    BatteryHealthStatus status,
  ) {
    return <String, dynamic>{
      'health_summary': status.healthSummary,
      'cycle_count': status.cycleCount,
      'current_temperature': status.currentTemperature,
    };
  }

  Map<String, dynamic> _serializeBatteryEnergyStatus(
    BatteryEnergyStatus status,
  ) {
    return <String, dynamic>{
      'voltage': status.voltage,
      'available_capacity': status.availableCapacity,
      'charge_rate': status.chargeRate,
    };
  }

  List<String> _capabilitiesForWearable(Wearable wearable) {
    final capabilities = <String>[];
    void addIf<T>(String name) {
      if (wearable.hasCapability<T>()) {
        capabilities.add(name);
      }
    }

    addIf<SensorManager>('SensorManager');
    addIf<SensorConfigurationManager>('SensorConfigurationManager');
    addIf<DeviceIdentifier>('DeviceIdentifier');
    addIf<DeviceFirmwareVersion>('DeviceFirmwareVersion');
    addIf<DeviceHardwareVersion>('DeviceHardwareVersion');
    addIf<RgbLed>('RgbLed');
    addIf<StatusLed>('StatusLed');
    addIf<BatteryLevelStatus>('BatteryLevelStatus');
    addIf<BatteryLevelStatusService>('BatteryLevelStatusService');
    addIf<BatteryHealthStatusService>('BatteryHealthStatusService');
    addIf<BatteryEnergyStatusService>('BatteryEnergyStatusService');
    addIf<FrequencyPlayer>('FrequencyPlayer');
    addIf<JinglePlayer>('JinglePlayer');
    addIf<AudioPlayerControls>('AudioPlayerControls');
    addIf<StoragePathAudioPlayer>('StoragePathAudioPlayer');
    addIf<AudioModeManager>('AudioModeManager');
    addIf<MicrophoneManager>('MicrophoneManager');
    addIf<EdgeRecorderManager>('EdgeRecorderManager');
    addIf<ButtonManager>('ButtonManager');
    addIf<StereoDevice>('StereoDevice');
    addIf<SystemDevice>('SystemDevice');
    addIf<TimeSynchronizable>('TimeSynchronizable');
    return capabilities;
  }

  Wearable _requireConnectedWearable(String deviceId) {
    final wearable = _connectedWearablesById[deviceId];
    if (wearable == null) {
      throw StateError('No connected wearable for device_id: $deviceId');
    }
    return wearable;
  }

  String _normalizePath(String path) {
    final trimmed = path.trim();
    if (trimmed.isEmpty) {
      return defaultPath;
    }
    return trimmed.startsWith('/') ? trimmed : '/$trimmed';
  }

  String _jsonEncode(Map<String, dynamic> payload) {
    return jsonEncode(_jsonSafe(payload));
  }

  Object? _jsonSafe(Object? value) {
    if (value == null || value is num || value is bool || value is String) {
      return value;
    }
    if (value is Enum) {
      return value.name;
    }
    if (value is List) {
      return value.map(_jsonSafe).toList(growable: false);
    }
    if (value is Set) {
      return value.map(_jsonSafe).toList(growable: false);
    }
    if (value is Map) {
      final map = <String, Object?>{};
      value.forEach((key, nestedValue) {
        map[key.toString()] = _jsonSafe(nestedValue);
      });
      return map;
    }
    return value.toString();
  }

  Map<String, dynamic> _asMap(Object? value) {
    if (value == null) {
      return <String, dynamic>{};
    }
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return value.map((key, val) => MapEntry(key.toString(), val));
    }
    throw FormatException('Expected params/args to be an object.');
  }

}

class _ClientSession {
  final WebSocket socket;
  final WebSocketIpcServer server;

  final Map<int, StreamSubscription<dynamic>> _subscriptions =
      <int, StreamSubscription<dynamic>>{};

  bool _closed = false;

  _ClientSession({
    required this.socket,
    required this.server,
  });

  void start() {
    server._sendReady(this);

    socket.listen(
      (message) async {
        await _handleMessage(message);
      },
      onDone: () async {
        await close();
      },
      onError: (_) async {
        await close();
      },
      cancelOnError: true,
    );
  }

  void send(Map<String, dynamic> payload) {
    if (_closed) {
      return;
    }
    sendRaw(jsonEncode(payload));
  }

  void sendRaw(String payload) {
    if (_closed) {
      return;
    }
    socket.add(payload);
  }

  Future<void> _handleMessage(dynamic rawMessage) async {
    dynamic id;
    try {
      if (rawMessage is! String) {
        throw const FormatException('Expected text websocket frame.');
      }

      final decoded = jsonDecode(rawMessage);
      if (decoded is! Map) {
        throw const FormatException('Request must be a JSON object.');
      }

      final request =
          decoded.map((key, value) => MapEntry(key.toString(), value));
      id = request['id'];

      final method = request['method'];
      if (method is! String || method.trim().isEmpty) {
        throw const FormatException(
          'Request method must be a non-empty string.',
        );
      }

      final params = server._asMap(request['params']);
      final result = await server._handleRequest(
        client: this,
        method: method,
        params: params,
      );

      send(
        <String, dynamic>{
          'id': id,
          'result': result,
        },
      );
    } catch (error, stackTrace) {
      send(
        <String, dynamic>{
          'id': id,
          'error': <String, dynamic>{
            'message': error.toString(),
            'type': error.runtimeType.toString(),
            'stack': stackTrace.toString(),
          },
        },
      );
    }
  }

  Future<void> subscribe({
    required int subscriptionId,
    required String streamName,
    required String deviceId,
    required Stream<dynamic> stream,
    required Object? Function(dynamic value) serializer,
  }) async {
    await _subscriptions[subscriptionId]?.cancel();
    _subscriptions[subscriptionId] = stream.listen(
      (data) {
        send(
          <String, dynamic>{
            'event': 'stream',
            'subscription_id': subscriptionId,
            'stream': streamName,
            'device_id': deviceId,
            'data': serializer(data),
          },
        );
      },
      onError: (error, stackTrace) {
        send(
          <String, dynamic>{
            'event': 'stream_error',
            'subscription_id': subscriptionId,
            'stream': streamName,
            'device_id': deviceId,
            'error': <String, dynamic>{
              'message': error.toString(),
              'type': error.runtimeType.toString(),
              'stack': stackTrace.toString(),
            },
          },
        );
      },
      onDone: () {
        _subscriptions.remove(subscriptionId);
        send(
          <String, dynamic>{
            'event': 'stream_done',
            'subscription_id': subscriptionId,
            'stream': streamName,
            'device_id': deviceId,
          },
        );
      },
      cancelOnError: false,
    );
  }

  Future<Map<String, dynamic>> unsubscribe(int subscriptionId) async {
    final existing = _subscriptions.remove(subscriptionId);
    if (existing == null) {
      return <String, dynamic>{
        'subscription_id': subscriptionId,
        'cancelled': false,
      };
    }
    await existing.cancel();
    return <String, dynamic>{
      'subscription_id': subscriptionId,
      'cancelled': true,
    };
  }

  Future<void> close() async {
    if (_closed) {
      return;
    }
    _closed = true;

    final subscriptions = _subscriptions.values.toList(growable: false);
    _subscriptions.clear();

    for (final subscription in subscriptions) {
      await subscription.cancel();
    }

    await socket.close();
    server._onClientClosed(this);
  }
}
