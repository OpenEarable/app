import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:open_earable_flutter/open_earable_flutter.dart' hide logger;
import 'package:open_wearable/models/connectors/commands/command.dart';
import 'package:open_wearable/models/connectors/commands/default_action_commands.dart';
import 'package:open_wearable/models/connectors/commands/default_ipc_commands.dart';
import 'package:open_wearable/models/connectors/commands/ipc_internal_param_names.dart';
import 'package:open_wearable/models/connectors/commands/runtime.dart';
import 'package:open_wearable/models/connectors/audio_playback_config.dart';
import 'package:open_wearable/models/connectors/websocket_audio_playback_service.dart';
import 'package:open_wearable/models/logger.dart';
import 'package:open_wearable/models/network/device_ip_address.dart';
import 'package:open_wearable/models/wearable_connector.dart';

/// Websocket-based IPC server that exposes wearable operations to external clients.
class WebSocketIpcServer implements CommandRuntime {
  static const int defaultPort = 8765;
  static const String defaultPath = '/ws';

  final WearableManager _wearableManager;
  final WearableConnector _wearableConnector;
  final WebsocketAudioPlaybackService _audioPlaybackService;

  HttpServer? _httpServer;
  final InternetAddress _host = InternetAddress.anyIPv4;
  int _port = defaultPort;
  String _path = defaultPath;
  String? _advertisedHost;

  final Map<String, DiscoveredDevice> _discoveredDevicesById =
      <String, DiscoveredDevice>{};
  final Map<String, Wearable> _connectedWearablesById = <String, Wearable>{};
  final Set<_ClientSession> _clients = <_ClientSession>{};

  StreamSubscription<DiscoveredDevice>? _scanSubscription;
  StreamSubscription<DiscoveredDevice>? _connectingSubscription;
  StreamSubscription<Wearable>? _connectSubscription;
  final StreamController<DiscoveredDevice> _scanEventsController =
      StreamController<DiscoveredDevice>.broadcast();

  int _nextSubscriptionId = 1;
  final Map<String, Command> _topLevelCommands = <String, Command>{};
  final Map<String, Command> _actionCommands = <String, Command>{};

  WebSocketIpcServer({
    WearableManager? wearableManager,
    WearableConnector? wearableConnector,
    WebsocketAudioPlaybackService? audioPlaybackService,
  })  : _wearableManager = wearableManager ?? WearableManager(),
        _wearableConnector = wearableConnector ?? WearableConnector(),
        _audioPlaybackService =
            audioPlaybackService ?? WebsocketAudioPlaybackService() {
    for (final command in createDefaultIpcCommands(this)) {
      addCommand(command);
    }
    for (final command in createDefaultActionCommands(this)) {
      addActionCommand(command);
    }
  }

  /// Returns whether the websocket server is currently bound and accepting requests.
  bool get isRunning => _httpServer != null;

  /// Returns the internal bind endpoint used by the server.
  Uri get bindEndpoint => Uri(
        scheme: 'ws',
        host: _host.address,
        port: _port,
        path: _path,
      );

  /// Returns the client-facing endpoint derived from the current advertised IP.
  Uri? get advertisedEndpoint {
    final host = _advertisedHost;
    if (host == null || host.trim().isEmpty) {
      return null;
    }
    return Uri(
      scheme: 'ws',
      host: host,
      port: _port,
      path: _path,
    );
  }

  /// Updates the client-facing host advertised by command responses.
  void updateAdvertisedHost(String? host) {
    _advertisedHost = host?.trim().isEmpty ?? true ? null : host!.trim();
  }

  /// Starts the server with the provided port and path.
  Future<void> start({
    required int port,
    required String path,
  }) async {
    await stop();

    _port = port;
    _path = _normalizePath(path);
    logger.i(
      '[connector.websocket] starting bind_address=${_host.address} port=$_port path=$_path',
    );

    _httpServer = await HttpServer.bind(_host, _port, shared: true);
    updateAdvertisedHost(await resolveCurrentDeviceIpAddress());
    logger.i(
      '[connector.websocket] listening address=${_httpServer!.address.address} port=${_httpServer!.port} path=$_path advertised_endpoint=${advertisedEndpoint?.toString() ?? 'unavailable'}',
    );
    _attachManagerSubscriptions();

    _httpServer!.listen(
      (request) async {
        if (request.uri.path != _path ||
            !WebSocketTransformer.isUpgradeRequest(request)) {
          logger.d(
            '[connector.websocket] rejected_http_request method=${request.method} path=${request.uri.path} remote=${request.connectionInfo?.remoteAddress.address}:${request.connectionInfo?.remotePort}',
          );
          request.response
            ..statusCode = HttpStatus.notFound
            ..headers.contentType = ContentType.text
            ..write('OpenWearables WebSocket IPC endpoint: $_path')
            ..close();
          return;
        }

        logger.i(
          '[connector.websocket] upgrade_request accepted remote=${request.connectionInfo?.remoteAddress.address}:${request.connectionInfo?.remotePort}',
        );
        final socket = await WebSocketTransformer.upgrade(request);
        final session = _ClientSession(
          socket: socket,
          server: this,
        );
        _clients.add(session);
        logger.i(
          '[connector.websocket] client_connected client=${session.label} active_clients=${_clients.length}',
        );
        session.start();
      },
      onError: (error, stackTrace) {
        logger.e(
          '[connector.websocket] http_server_loop_failed error=$error',
          error: error,
          stackTrace: stackTrace,
        );
      },
    );
  }

  /// Stops the server, closes active clients, and clears runtime state.
  Future<void> stop() async {
    final server = _httpServer;
    _httpServer = null;

    if (server != null) {
      logger.i(
        '[connector.websocket] stopping address=${server.address.address} port=${server.port} active_clients=${_clients.length}',
      );
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
    _advertisedHost = null;
    logger.i('[connector.websocket] stopped');
  }

  /// Removes a disconnected client session from the active set.
  void _onClientClosed(_ClientSession client) {
    _clients.remove(client);
    logger.i(
      '[connector.websocket] client_disconnected client=${client.label} active_clients=${_clients.length}',
    );
  }

  @override

  /// Returns the list of registered top-level IPC method names.
  List<String> get methods => _topLevelCommands.keys.toList(growable: false);

  /// Registers a top-level IPC command.
  void addCommand(Command command) {
    _topLevelCommands[command.name] = command;
  }

  /// Registers an action command callable through `invoke_action`.
  void addActionCommand(Command command) {
    _actionCommands[command.name] = command;
  }

  /// Dispatches an inbound request to the matching command.
  Future<Object?> _handleRequest({
    required _ClientSession client,
    required String method,
    required Map<String, dynamic> params,
  }) async {
    final command = _topLevelCommands[method];
    if (command == null) {
      logger.w(
        '[connector.websocket] unknown_method client=${client.label} method=$method',
      );
      throw UnsupportedError('Unknown method: $method');
    }
    return command.run(_paramsToCommandParams(params, session: client));
  }

  @override

  /// Returns a connected wearable by device id.
  Future<Wearable> getWearable({required String deviceId}) async {
    return _requireConnectedWearable(deviceId);
  }

  @override

  /// Returns whether the underlying wearable runtime already has required permissions.
  Future<bool> hasPermissions() => _wearableManager.hasPermissions();

  @override

  /// Checks for and requests missing runtime permissions from the platform.
  Future<bool> checkAndRequestPermissions() =>
      WearableManager.checkAndRequestPermissions();

  /// Starts device scanning through the wearable manager.
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

  /// Returns the currently discovered devices as JSON-safe maps.
  @override
  Future<List<Map<String, dynamic>>> getDiscoveredDevices() async {
    return _discoveredDevicesById.values.map(_serializeDiscovered).toList();
  }

  @override

  /// Exposes the scan event stream for async scan subscriptions.
  Stream<DiscoveredDevice> get scanEvents => _scanEventsController.stream;

  /// Connects to a discovered device by id.
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

  /// Connects to system-managed wearables and registers them with the server.
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

  /// Lists currently connected wearables.
  @override
  Future<List<Map<String, dynamic>>> listConnected() async {
    return _connectedWearablesById.values
        .map(_serializeWearableSummary)
        .toList();
  }

  /// Disconnects a connected wearable by id.
  @override
  Future<Map<String, dynamic>> disconnect({
    required String deviceId,
  }) async {
    final wearable = _requireConnectedWearable(deviceId);
    await wearable.disconnect();
    _connectedWearablesById.remove(deviceId);
    return <String, dynamic>{'disconnected': true};
  }

  /// Stores a sound in app memory for later playback.
  @override
  Future<Map<String, dynamic>> storeSound({
    required String soundId,
    required Uint8List bytes,
    required AudioPlaybackConfig config,
  }) async {
    await _audioPlaybackService.storeSound(
      soundId: soundId,
      bytes: bytes,
      config: config,
    );
    return <String, dynamic>{
      'sound_id': soundId,
      'stored': true,
      'bytes': bytes.length,
      'config': config.toJson(),
    };
  }

  /// Plays a previously stored sound.
  @override
  Future<Map<String, dynamic>> playSound({
    String? soundId,
    double? volume,
    AudioPlaybackConfig? config,
  }) async {
    final hasSoundId = soundId != null && soundId.trim().isNotEmpty;
    if (!hasSoundId) {
      throw ArgumentError('play_sound requires "sound_id".');
    }

    final usedConfig = await _audioPlaybackService.playStoredSound(
      soundId: soundId,
      volume: volume,
      overrideConfig: config,
    );
    return <String, dynamic>{
      'source': 'sound_id',
      'sound_id': soundId,
      'playing': true,
      'config': usedConfig.toJson(),
    };
  }

  /// Allocates the next unique subscription id for a client.
  @override
  Future<int> createSubscriptionId() async {
    return _nextSubscriptionId++;
  }

  /// Attaches a stream subscription to the given client session.
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

  /// Cancels a previously registered client stream subscription.
  @override
  Future<Map<String, dynamic>> unsubscribe({
    required dynamic session,
    required int subscriptionId,
  }) async {
    final _ClientSession client = session as _ClientSession;
    return client.unsubscribe(subscriptionId);
  }

  /// Invokes an action command against a connected wearable.
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

  /// Converts raw request params into command params for command execution.
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

  /// Hooks wearable manager streams into websocket broadcast events.
  void _attachManagerSubscriptions() {
    _scanSubscription ??= _wearableManager.scanStream.listen((device) {
      _discoveredDevicesById[device.id] = device;
      _scanEventsController.add(device);
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

  /// Tracks a connected wearable and removes it when it disconnects.
  void _registerConnectedWearable(Wearable wearable) {
    _connectedWearablesById[wearable.deviceId] = wearable;
    wearable.addDisconnectListener(() {
      _connectedWearablesById.remove(wearable.deviceId);
    });
  }

  /// Broadcasts a JSON event to all currently connected clients.
  void _broadcastEvent(Map<String, dynamic> event) {
    final payload = _jsonEncode(event);
    for (final client in _clients.toList(growable: false)) {
      client.sendRaw(payload);
    }
  }

  /// Sends the initial ready event to a newly connected client.
  void _sendReady(_ClientSession client) {
    client.send(
      <String, dynamic>{
        'event': 'ready',
        'methods': methods,
        'endpoint': advertisedEndpoint?.toString(),
      },
    );
  }

  /// Serializes a discovered device into the external IPC format.
  Map<String, dynamic> _serializeDiscovered(DiscoveredDevice device) {
    return <String, dynamic>{
      'id': device.id,
      'name': device.name,
      'service_uuids': device.serviceUuids,
      'manufacturer_data': device.manufacturerData.toList(),
      'rssi': device.rssi,
    };
  }

  /// Serializes a connected wearable summary into the external IPC format.
  Map<String, dynamic> _serializeWearableSummary(Wearable wearable) {
    return <String, dynamic>{
      'device_id': wearable.deviceId,
      'name': wearable.name,
      'type': wearable.runtimeType.toString(),
      'capabilities': _capabilitiesForWearable(wearable),
    };
  }

  /// Serializes streamed capability data into JSON-safe payloads.
  Object? _serializeStreamData(dynamic data) {
    if (data is DiscoveredDevice) {
      return _serializeDiscovered(data);
    }
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

  /// Serializes battery power status into a JSON-safe payload.
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

  /// Serializes battery health status into a JSON-safe payload.
  Map<String, dynamic> _serializeBatteryHealthStatus(
    BatteryHealthStatus status,
  ) {
    return <String, dynamic>{
      'health_summary': status.healthSummary,
      'cycle_count': status.cycleCount,
      'current_temperature': status.currentTemperature,
    };
  }

  /// Serializes battery energy status into a JSON-safe payload.
  Map<String, dynamic> _serializeBatteryEnergyStatus(
    BatteryEnergyStatus status,
  ) {
    return <String, dynamic>{
      'voltage': status.voltage,
      'available_capacity': status.availableCapacity,
      'charge_rate': status.chargeRate,
    };
  }

  /// Lists known capabilities for a connected wearable.
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

  /// Looks up a connected wearable and throws if it is unavailable.
  Wearable _requireConnectedWearable(String deviceId) {
    final wearable = _connectedWearablesById[deviceId];
    if (wearable == null) {
      throw StateError('No connected wearable for device_id: $deviceId');
    }
    return wearable;
  }

  /// Ensures the configured websocket path is non-empty and absolute.
  String _normalizePath(String path) {
    final trimmed = path.trim();
    if (trimmed.isEmpty) {
      return defaultPath;
    }
    return trimmed.startsWith('/') ? trimmed : '/$trimmed';
  }

  /// Encodes an event payload after coercing unsupported values to JSON-safe forms.
  String _jsonEncode(Map<String, dynamic> payload) {
    return jsonEncode(_jsonSafe(payload));
  }

  /// Recursively converts arbitrary values into JSON-safe representations.
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

  /// Normalizes arbitrary request payloads into string-keyed maps.
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

/// Represents one connected websocket client and its active subscriptions.
class _ClientSession {
  final WebSocket socket;
  final WebSocketIpcServer server;

  final Map<int, StreamSubscription<dynamic>> _subscriptions =
      <int, StreamSubscription<dynamic>>{};

  bool _closed = false;

  /// Returns a log-friendly label for this client session.
  String get label {
    final remote = socket.closeCode == null
        ? '${socket.hashCode}'
        : '${socket.hashCode}:${socket.closeCode}';
    final address = socket.hashCode;
    return 'ws#$address/$remote';
  }

  _ClientSession({
    required this.socket,
    required this.server,
  });

  /// Starts listening for websocket messages and lifecycle events.
  void start() {
    server._sendReady(this);

    socket.listen(
      (message) async {
        await _handleMessage(message);
      },
      onDone: () async {
        await close();
      },
      onError: (error, stackTrace) async {
        logger.w(
          '[connector.websocket] socket_error client=$label error=$error\n$stackTrace',
        );
        await close();
      },
      cancelOnError: true,
    );
  }

  /// Sends a JSON payload to the client.
  void send(Map<String, dynamic> payload) {
    if (_closed) {
      return;
    }
    sendRaw(jsonEncode(payload));
  }

  /// Sends a pre-serialized websocket text frame to the client.
  void sendRaw(String payload) {
    if (_closed) {
      return;
    }
    socket.add(payload);
  }

  /// Parses and executes a single inbound websocket message.
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
      logger.w(
        '[connector.websocket] request_failed client=$label id=$id error=$error\n$stackTrace',
      );
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

  /// Registers or replaces a stream subscription owned by this client.
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
        logger.w(
          '[connector.websocket] stream_error client=$label subscription_id=$subscriptionId stream=$streamName device_id=$deviceId error=$error\n$stackTrace',
        );
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

  /// Cancels a single client-owned stream subscription.
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

  /// Closes the client socket and cancels all active subscriptions.
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
