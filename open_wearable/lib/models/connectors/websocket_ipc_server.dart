import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:open_earable_flutter/open_earable_flutter.dart';
import 'package:open_wearable/models/wearable_connector.dart';

class WebSocketIpcServer {
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

  WebSocketIpcServer({
    WearableManager? wearableManager,
    WearableConnector? wearableConnector,
  })  : _wearableManager = wearableManager ?? WearableManager(),
        _wearableConnector = wearableConnector ?? WearableConnector();

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

  List<String> get methods => const <String>[
        'ping',
        'methods',
        'has_permissions',
        'check_and_request_permissions',
        'start_scan',
        'get_discovered_devices',
        'connect',
        'connect_system_devices',
        'list_connected',
        'disconnect',
        'set_auto_connect',
        'get_wearable',
        'get_actions',
        'invoke_action',
        'subscribe',
        'unsubscribe',
      ];

  Future<Object?> _handleRequest({
    required _ClientSession client,
    required String method,
    required Map<String, dynamic> params,
  }) async {
    switch (method) {
      case 'ping':
        return <String, dynamic>{'ok': true};
      case 'methods':
        return methods;
      case 'has_permissions':
        return _wearableManager.hasPermissions();
      case 'check_and_request_permissions':
        return WearableManager.checkAndRequestPermissions();
      case 'start_scan':
        final checkAndRequestPermissions =
            _asOptionalBool(params['check_and_request_permissions']) ?? true;
        _discoveredDevicesById.clear();
        await _wearableManager.startScan(
          checkAndRequestPermissions: checkAndRequestPermissions,
        );
        return <String, dynamic>{'started': true};
      case 'get_discovered_devices':
        return _discoveredDevicesById.values.map(_serializeDiscovered).toList();
      case 'connect':
        return _connect(params);
      case 'connect_system_devices':
        return _connectSystemDevices(params);
      case 'list_connected':
        return _connectedWearablesById.values
            .map(_serializeWearableSummary)
            .toList();
      case 'disconnect':
        return _disconnect(params);
      case 'set_auto_connect':
        return _setAutoConnect(params);
      case 'get_wearable':
        return _getWearable(params);
      case 'get_actions':
        return _getActions(params);
      case 'invoke_action':
        return _invokeAction(params);
      case 'subscribe':
        return _subscribe(client, params);
      case 'unsubscribe':
        return client.unsubscribe(
          _asInt(params['subscription_id'], name: 'subscription_id'),
        );
      default:
        throw UnsupportedError('Unknown method: $method');
    }
  }

  Future<Map<String, dynamic>> _connect(Map<String, dynamic> params) async {
    final deviceId = _asString(params['device_id'], name: 'device_id');
    final discovered = _discoveredDevicesById[deviceId];
    if (discovered == null) {
      throw StateError('Device not found in discovered devices: $deviceId');
    }

    final connectedViaSystem =
        _asOptionalBool(params['connected_via_system']) ?? false;
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

  Future<List<Map<String, dynamic>>> _connectSystemDevices(
    Map<String, dynamic> params,
  ) async {
    final ignoredIds = _asStringList(params['ignored_device_ids']);
    final wearables = await _wearableConnector.connectToSystemDevices(
      ignoredDeviceIds: ignoredIds,
    );
    for (final wearable in wearables) {
      _registerConnectedWearable(wearable);
    }
    return wearables.map(_serializeWearableSummary).toList();
  }

  Future<Map<String, dynamic>> _disconnect(Map<String, dynamic> params) async {
    final deviceId = _asString(params['device_id'], name: 'device_id');
    final wearable = _requireConnectedWearable(deviceId);
    await wearable.disconnect();
    _connectedWearablesById.remove(deviceId);
    return <String, dynamic>{'disconnected': true};
  }

  Map<String, dynamic> _setAutoConnect(Map<String, dynamic> params) {
    final deviceIds = _asStringList(params['device_ids']);
    _wearableManager.setAutoConnect(deviceIds);
    return <String, dynamic>{'device_ids': deviceIds};
  }

  Map<String, dynamic> _getWearable(Map<String, dynamic> params) {
    final wearable = _requireConnectedWearable(
      _asString(params['device_id'], name: 'device_id'),
    );

    final details = _serializeWearableSummary(wearable);
    details['sensors'] = _serializeSensors(wearable);
    details['sensor_configurations'] = _serializeSensorConfigurations(wearable);
    details['actions'] = _actionsForWearable(wearable);
    details['streams'] = _streamsForWearable(wearable);
    return details;
  }

  List<String> _getActions(Map<String, dynamic> params) {
    final wearable = _requireConnectedWearable(
      _asString(params['device_id'], name: 'device_id'),
    );
    return _actionsForWearable(wearable);
  }

  Future<Object?> _invokeAction(Map<String, dynamic> params) async {
    final wearable = _requireConnectedWearable(
      _asString(params['device_id'], name: 'device_id'),
    );
    final action = _asString(params['action'], name: 'action');
    final args = _asMap(params['args']);

    switch (action) {
      case 'disconnect':
        await wearable.disconnect();
        _connectedWearablesById.remove(wearable.deviceId);
        return <String, dynamic>{'disconnected': true};
      case 'get_wearable_icon_path':
        return wearable.getWearableIconPath(
          darkmode: _asOptionalBool(args['darkmode']) ?? false,
        );
      case 'list_sensors':
        return _serializeSensors(wearable);
      case 'list_sensor_configurations':
        return _serializeSensorConfigurations(wearable);
      case 'set_sensor_configuration':
        return _setSensorConfiguration(wearable, args);
      case 'set_sensor_frequency_best_effort':
        return _setSensorFrequencyBestEffort(wearable, args);
      case 'set_sensor_maximum_frequency':
        return _setSensorMaximumFrequency(wearable, args);
      case 'read_device_identifier':
        return _requireCapability<DeviceIdentifier>(
          wearable,
          action: action,
        ).readDeviceIdentifier();
      case 'read_device_firmware_version':
        return _requireCapability<DeviceFirmwareVersion>(
          wearable,
          action: action,
        ).readDeviceFirmwareVersion();
      case 'read_firmware_version_number':
        return (await _requireCapability<DeviceFirmwareVersion>(
          wearable,
          action: action,
        ).readFirmwareVersionNumber())
            ?.toString();
      case 'check_firmware_support':
        return (await _requireCapability<DeviceFirmwareVersion>(
          wearable,
          action: action,
        ).checkFirmwareSupport())
            .name;
      case 'read_device_hardware_version':
        return _requireCapability<DeviceHardwareVersion>(
          wearable,
          action: action,
        ).readDeviceHardwareVersion();
      case 'write_led_color':
        await _requireCapability<RgbLed>(
          wearable,
          action: action,
        ).writeLedColor(
          r: _asInt(args['r'], name: 'r'),
          g: _asInt(args['g'], name: 'g'),
          b: _asInt(args['b'], name: 'b'),
        );
        return <String, dynamic>{'ok': true};
      case 'show_status':
        await _requireCapability<StatusLed>(
          wearable,
          action: action,
        ).showStatus(_asRequiredBool(args['status'], name: 'status'));
        return <String, dynamic>{'ok': true};
      case 'read_battery_percentage':
        return _requireCapability<BatteryLevelStatus>(
          wearable,
          action: action,
        ).readBatteryPercentage();
      case 'read_power_status':
        return _serializeBatteryPowerStatus(
          await _requireCapability<BatteryLevelStatusService>(
            wearable,
            action: action,
          ).readPowerStatus(),
        );
      case 'read_health_status':
        return _serializeBatteryHealthStatus(
          await _requireCapability<BatteryHealthStatusService>(
            wearable,
            action: action,
          ).readHealthStatus(),
        );
      case 'read_energy_status':
        return _serializeBatteryEnergyStatus(
          await _requireCapability<BatteryEnergyStatusService>(
            wearable,
            action: action,
          ).readEnergyStatus(),
        );
      case 'play_frequency':
        await _playFrequency(wearable, args);
        return <String, dynamic>{'ok': true};
      case 'list_wave_types':
        return _requireCapability<FrequencyPlayer>(
          wearable,
          action: action,
        ).supportedFrequencyPlayerWaveTypes.map((w) => w.key).toList();
      case 'play_jingle':
        await _playJingle(wearable, args);
        return <String, dynamic>{'ok': true};
      case 'list_jingles':
        return _requireCapability<JinglePlayer>(
          wearable,
          action: action,
        ).supportedJingles.map((j) => j.key).toList();
      case 'start_audio':
        await _requireCapability<AudioPlayerControls>(
          wearable,
          action: action,
        ).startAudio();
        return <String, dynamic>{'ok': true};
      case 'pause_audio':
        await _requireCapability<AudioPlayerControls>(
          wearable,
          action: action,
        ).pauseAudio();
        return <String, dynamic>{'ok': true};
      case 'stop_audio':
        await _requireCapability<AudioPlayerControls>(
          wearable,
          action: action,
        ).stopAudio();
        return <String, dynamic>{'ok': true};
      case 'play_audio_from_storage_path':
        await _requireCapability<StoragePathAudioPlayer>(
          wearable,
          action: action,
        ).playAudioFromStoragePath(
            _asString(args['filepath'], name: 'filepath'));
        return <String, dynamic>{'ok': true};
      case 'list_audio_modes':
        return _requireCapability<AudioModeManager>(
          wearable,
          action: action,
        ).availableAudioModes.map((mode) => mode.key).toList();
      case 'set_audio_mode':
        _setAudioMode(wearable, args);
        return <String, dynamic>{'ok': true};
      case 'get_audio_mode':
        return (await _requireCapability<AudioModeManager>(
          wearable,
          action: action,
        ).getAudioMode())
            .key;
      case 'list_microphones':
        return _listMicrophones(wearable);
      case 'set_microphone':
        await _setMicrophone(wearable, args);
        return <String, dynamic>{'ok': true};
      case 'get_microphone':
        return _getMicrophone(wearable);
      case 'get_file_prefix':
        return _requireCapability<EdgeRecorderManager>(
          wearable,
          action: action,
        ).filePrefix;
      case 'set_file_prefix':
        await _requireCapability<EdgeRecorderManager>(
          wearable,
          action: action,
        ).setFilePrefix(_asString(args['prefix'], name: 'prefix'));
        return <String, dynamic>{'ok': true};
      case 'get_position':
        final position = await _requireCapability<StereoDevice>(
          wearable,
          action: action,
        ).position;
        return position?.name;
      case 'pair':
        await _pairWearable(wearable, args);
        return <String, dynamic>{'ok': true};
      case 'unpair':
        await _requireCapability<StereoDevice>(
          wearable,
          action: action,
        ).unpair();
        return <String, dynamic>{'ok': true};
      case 'is_connected_via_system':
        return _requireCapability<SystemDevice>(
          wearable,
          action: action,
        ).isConnectedViaSystem;
      case 'is_time_synchronized':
        return _requireCapability<TimeSynchronizable>(
          wearable,
          action: action,
        ).isTimeSynchronized;
      case 'synchronize_time':
        await _requireCapability<TimeSynchronizable>(
          wearable,
          action: action,
        ).synchronizeTime();
        return <String, dynamic>{'ok': true};
      case 'measure_audio_response':
      case 'measure_freq_response':
        return _measureAudioResponse(wearable, args);
      default:
        throw UnsupportedError('Unsupported action: $action');
    }
  }

  Future<Map<String, dynamic>> _subscribe(
    _ClientSession client,
    Map<String, dynamic> params,
  ) async {
    final wearable = _requireConnectedWearable(
      _asString(params['device_id'], name: 'device_id'),
    );
    final streamName = _asString(params['stream'], name: 'stream');
    final args = _asMap(params['args']);

    final Stream<dynamic> stream;
    switch (streamName) {
      case 'sensor_values':
        stream = _resolveSensor(wearable, args).sensorStream;
        break;
      case 'sensor_configuration':
        stream = _requireCapability<SensorConfigurationManager>(
          wearable,
          action: 'subscribe:$streamName',
        ).sensorConfigurationStream;
        break;
      case 'button_events':
        stream = _requireCapability<ButtonManager>(
          wearable,
          action: 'subscribe:$streamName',
        ).buttonEvents;
        break;
      case 'battery_percentage':
        stream = _requireCapability<BatteryLevelStatus>(
          wearable,
          action: 'subscribe:$streamName',
        ).batteryPercentageStream;
        break;
      case 'battery_power_status':
        stream = _requireCapability<BatteryLevelStatusService>(
          wearable,
          action: 'subscribe:$streamName',
        ).powerStatusStream;
        break;
      case 'battery_health_status':
        stream = _requireCapability<BatteryHealthStatusService>(
          wearable,
          action: 'subscribe:$streamName',
        ).healthStatusStream;
        break;
      case 'battery_energy_status':
        stream = _requireCapability<BatteryEnergyStatusService>(
          wearable,
          action: 'subscribe:$streamName',
        ).energyStatusStream;
        break;
      default:
        throw UnsupportedError('Unknown stream: $streamName');
    }

    final subscriptionId = _nextSubscriptionId++;
    await client.subscribe(
      subscriptionId: subscriptionId,
      streamName: streamName,
      deviceId: wearable.deviceId,
      stream: stream,
      serializer: _serializeStreamData,
    );

    return <String, dynamic>{
      'subscription_id': subscriptionId,
      'stream': streamName,
      'device_id': wearable.deviceId,
    };
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

  Sensor _resolveSensor(Wearable wearable, Map<String, dynamic> args) {
    final sensorManager = wearable.getCapability<SensorManager>();
    if (sensorManager == null) {
      throw StateError('Wearable has no SensorManager capability.');
    }

    final sensors = sensorManager.sensors;
    if (sensors.isEmpty) {
      throw StateError('Wearable has no sensors.');
    }

    final sensorId = args['sensor_id'];
    if (sensorId != null) {
      final id = _asString(sensorId, name: 'sensor_id');
      for (var i = 0; i < sensors.length; i++) {
        if (_sensorId(sensors[i], i) == id) {
          return sensors[i];
        }
      }
      throw StateError('Unknown sensor_id: $id');
    }

    final sensorIndex = args['sensor_index'];
    if (sensorIndex != null) {
      final index = _asInt(sensorIndex, name: 'sensor_index');
      if (index < 0 || index >= sensors.length) {
        throw RangeError.index(index, sensors, 'sensor_index');
      }
      return sensors[index];
    }

    final sensorName = args['sensor_name'];
    if (sensorName != null) {
      final name = _asString(sensorName, name: 'sensor_name');
      final matched =
          sensors.where((sensor) => sensor.sensorName == name).toList();
      if (matched.length != 1) {
        throw StateError(
          'sensor_name must resolve to exactly one sensor. Matches: ${matched.length}',
        );
      }
      return matched.first;
    }

    throw ArgumentError(
      'sensor_values subscription requires one of sensor_id, sensor_index, or sensor_name.',
    );
  }

  Map<String, dynamic> _setSensorConfiguration(
    Wearable wearable,
    Map<String, dynamic> args,
  ) {
    final config = _requireSensorConfiguration(
      wearable,
      _asString(args['configuration_name'], name: 'configuration_name'),
    );
    final valueKey = _asString(args['value_key'], name: 'value_key');
    final selected = config.values.where((v) => v.key == valueKey).firstOrNull;
    if (selected == null) {
      throw StateError(
        'Value "$valueKey" not found for configuration ${config.name}.',
      );
    }

    _applyConfiguration(config, selected);
    return <String, dynamic>{
      'configuration_name': config.name,
      'value_key': selected.key,
    };
  }

  Map<String, dynamic> _setSensorFrequencyBestEffort(
    Wearable wearable,
    Map<String, dynamic> args,
  ) {
    final config = _requireSensorConfiguration(
      wearable,
      _asString(args['configuration_name'], name: 'configuration_name'),
    );
    if (config is! SensorFrequencyConfiguration) {
      throw UnsupportedError(
        'Configuration ${config.name} is not frequency-based.',
      );
    }

    final targetHz = _asInt(args['target_hz'], name: 'target_hz');
    final streamData = _asOptionalBool(args['stream_data']);
    final recordData = _asOptionalBool(args['record_data']);

    final selected = _selectBestEffortFrequencyValue(
      config: config,
      targetHz: targetHz,
      streamData: streamData,
      recordData: recordData,
    );

    if (selected == null) {
      throw StateError('No frequency value available for ${config.name}.');
    }

    _applyConfiguration(config, selected);
    return <String, dynamic>{
      'configuration_name': config.name,
      'value_key': selected.key,
      'target_hz': targetHz,
      'selected_hz': _frequencyHzForValue(selected),
    };
  }

  Map<String, dynamic> _setSensorMaximumFrequency(
    Wearable wearable,
    Map<String, dynamic> args,
  ) {
    final config = _requireSensorConfiguration(
      wearable,
      _asString(args['configuration_name'], name: 'configuration_name'),
    );
    if (config is! SensorFrequencyConfiguration) {
      throw UnsupportedError(
        'Configuration ${config.name} is not frequency-based.',
      );
    }

    final streamData = _asOptionalBool(args['stream_data']);
    final recordData = _asOptionalBool(args['record_data']);

    final selected = _selectMaximumFrequencyValue(
      config: config,
      streamData: streamData,
      recordData: recordData,
    );

    if (selected == null) {
      throw StateError('No frequency value available for ${config.name}.');
    }

    _applyConfiguration(config, selected);
    return <String, dynamic>{
      'configuration_name': config.name,
      'value_key': selected.key,
      'selected_hz': _frequencyHzForValue(selected),
    };
  }

  SensorConfiguration _requireSensorConfiguration(
      Wearable wearable, String name) {
    final manager = wearable.getCapability<SensorConfigurationManager>();
    if (manager == null) {
      throw StateError(
          'Wearable has no SensorConfigurationManager capability.');
    }

    final config = manager.sensorConfigurations
        .where((configuration) => configuration.name == name)
        .firstOrNull;
    if (config == null) {
      throw StateError('Unknown configuration: $name');
    }
    return config;
  }

  void _applyConfiguration(
    SensorConfiguration configuration,
    SensorConfigurationValue value,
  ) {
    final dynamic dynamicConfiguration = configuration;
    dynamicConfiguration.setConfiguration(value);
  }

  SensorConfigurationValue? _selectBestEffortFrequencyValue({
    required SensorFrequencyConfiguration config,
    required int targetHz,
    required bool? streamData,
    required bool? recordData,
  }) {
    final values = _filterConfigValuesByOptions(
      config.values,
      streamData: streamData,
      recordData: recordData,
    );

    if (values.isEmpty) {
      return null;
    }

    SensorConfigurationValue? lower;
    SensorConfigurationValue? higher;

    for (final value in values) {
      final hz = _frequencyHzForValue(value);
      if (hz == null) {
        continue;
      }

      if (hz < targetHz) {
        if (lower == null || hz > (_frequencyHzForValue(lower) ?? hz)) {
          lower = value;
        }
      } else {
        if (higher == null || hz < (_frequencyHzForValue(higher) ?? hz)) {
          higher = value;
        }
      }
    }

    return higher ?? lower;
  }

  SensorConfigurationValue? _selectMaximumFrequencyValue({
    required SensorFrequencyConfiguration config,
    required bool? streamData,
    required bool? recordData,
  }) {
    final values = _filterConfigValuesByOptions(
      config.values,
      streamData: streamData,
      recordData: recordData,
    );
    if (values.isEmpty) {
      return null;
    }

    SensorConfigurationValue? currentMax;
    for (final value in values) {
      final hz = _frequencyHzForValue(value);
      if (hz == null) {
        continue;
      }
      if (currentMax == null || hz > (_frequencyHzForValue(currentMax) ?? hz)) {
        currentMax = value;
      }
    }
    return currentMax;
  }

  List<SensorConfigurationValue> _filterConfigValuesByOptions(
    List<SensorConfigurationValue> values, {
    bool? streamData,
    bool? recordData,
  }) {
    return values.where((value) {
      if (value is! ConfigurableSensorConfigurationValue) {
        return true;
      }

      bool hasOption<T extends SensorConfigurationOption>() {
        return value.options.any((option) => option is T);
      }

      if (streamData != null &&
          streamData != hasOption<StreamSensorConfigOption>()) {
        return false;
      }
      if (recordData != null &&
          recordData != hasOption<RecordSensorConfigOption>()) {
        return false;
      }
      return true;
    }).toList(growable: false);
  }

  double? _frequencyHzForValue(SensorConfigurationValue value) {
    if (value is SensorFrequencyConfigurationValue) {
      return value.frequencyHz;
    }
    return null;
  }

  Future<void> _playFrequency(
      Wearable wearable, Map<String, dynamic> args) async {
    final player = _requireCapability<FrequencyPlayer>(
      wearable,
      action: 'play_frequency',
    );
    final waveTypeKey = _asString(args['wave_type'], name: 'wave_type');
    final waveType = player.supportedFrequencyPlayerWaveTypes
        .where((wave) => wave.key == waveTypeKey)
        .firstOrNull;
    if (waveType == null) {
      throw StateError('Unsupported wave type: $waveTypeKey');
    }

    final frequency = _asDouble(args['frequency']) ?? 440.0;
    final loudness = _asDouble(args['loudness']) ?? 1.0;
    await player.playFrequency(
      waveType,
      frequency: frequency,
      loudness: loudness,
    );
  }

  Future<void> _playJingle(Wearable wearable, Map<String, dynamic> args) async {
    final player = _requireCapability<JinglePlayer>(
      wearable,
      action: 'play_jingle',
    );
    final key = _asString(args['jingle'], name: 'jingle');
    final jingle =
        player.supportedJingles.where((j) => j.key == key).firstOrNull;
    if (jingle == null) {
      throw StateError('Unsupported jingle: $key');
    }
    await player.playJingle(jingle);
  }

  void _setAudioMode(Wearable wearable, Map<String, dynamic> args) {
    final manager = _requireCapability<AudioModeManager>(
      wearable,
      action: 'set_audio_mode',
    );
    final key = _asString(args['audio_mode'], name: 'audio_mode');
    final mode =
        manager.availableAudioModes.where((m) => m.key == key).firstOrNull;
    if (mode == null) {
      throw StateError('Unsupported audio_mode: $key');
    }
    manager.setAudioMode(mode);
  }

  List<String> _listMicrophones(Wearable wearable) {
    final manager = _requireCapability<MicrophoneManager>(
      wearable,
      action: 'list_microphones',
    );
    final microphones = manager.availableMicrophones.cast<dynamic>();
    return microphones.map((microphone) => microphone.key.toString()).toList();
  }

  Future<void> _setMicrophone(
      Wearable wearable, Map<String, dynamic> args) async {
    final manager = _requireCapability<MicrophoneManager>(
      wearable,
      action: 'set_microphone',
    );
    final key = _asString(args['microphone'], name: 'microphone');
    final microphones = manager.availableMicrophones.cast<dynamic>();
    final dynamic selected = microphones.where((microphone) {
      return microphone.key.toString() == key;
    }).firstOrNull;

    if (selected == null) {
      throw StateError('Unsupported microphone: $key');
    }

    manager.setMicrophone(selected);
  }

  Future<String?> _getMicrophone(Wearable wearable) async {
    final manager = _requireCapability<MicrophoneManager>(
      wearable,
      action: 'get_microphone',
    );
    final dynamic microphone = await manager.getMicrophone();
    return microphone?.key?.toString();
  }

  Future<void> _pairWearable(
      Wearable wearable, Map<String, dynamic> args) async {
    final stereo = _requireCapability<StereoDevice>(
      wearable,
      action: 'pair',
    );
    final otherDeviceId =
        _asString(args['other_device_id'], name: 'other_device_id');
    final partner = _requireConnectedWearable(otherDeviceId);
    final partnerStereo = _requireCapability<StereoDevice>(
      partner,
      action: 'pair',
    );
    await stereo.pair(partnerStereo);
  }

  Future<Object?> _measureAudioResponse(
    Wearable wearable,
    Map<String, dynamic> args,
  ) async {
    final dynamic dynamicWearable = wearable;

    try {
      if (args.isEmpty) {
        return await dynamicWearable.measureAudioResponse();
      }
      return await Function.apply(
        dynamicWearable.measureAudioResponse,
        const <Object?>[],
        args.map((key, value) => MapEntry(Symbol(key), value)),
      );
    } on NoSuchMethodError {
      if (args.isEmpty) {
        return await dynamicWearable.measureFreqResponse();
      }
      return await Function.apply(
        dynamicWearable.measureFreqResponse,
        const <Object?>[],
        args.map((key, value) => MapEntry(Symbol(key), value)),
      );
    }
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

  List<Map<String, dynamic>> _serializeSensors(Wearable wearable) {
    final manager = wearable.getCapability<SensorManager>();
    if (manager == null) {
      return const <Map<String, dynamic>>[];
    }

    final sensors = manager.sensors;
    return [
      for (var index = 0; index < sensors.length; index++)
        <String, dynamic>{
          'sensor_id': _sensorId(sensors[index], index),
          'sensor_index': index,
          'sensor_name': sensors[index].sensorName,
          'chart_title': sensors[index].chartTitle,
          'short_chart_title': sensors[index].shortChartTitle,
          'axis_names': sensors[index].axisNames,
          'axis_units': sensors[index].axisUnits,
          'timestamp_exponent': sensors[index].timestampExponent,
        },
    ];
  }

  List<Map<String, dynamic>> _serializeSensorConfigurations(Wearable wearable) {
    final manager = wearable.getCapability<SensorConfigurationManager>();
    if (manager == null) {
      return const <Map<String, dynamic>>[];
    }

    return manager.sensorConfigurations.map((configuration) {
      return <String, dynamic>{
        'name': configuration.name,
        'unit': configuration.unit,
        'values': configuration.values
            .map((value) => _serializeSensorConfigurationValue(value))
            .toList(),
        'off_value': configuration.offValue?.key,
      };
    }).toList();
  }

  Map<String, dynamic> _serializeSensorConfigurationValue(
    SensorConfigurationValue value,
  ) {
    final payload = <String, dynamic>{'key': value.key};

    if (value is SensorFrequencyConfigurationValue) {
      payload['frequency_hz'] = value.frequencyHz;
    }
    if (value is ConfigurableSensorConfigurationValue) {
      payload['options'] = value.options.map((option) => option.name).toList();
    }

    return payload;
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
      BatteryHealthStatus status) {
    return <String, dynamic>{
      'health_summary': status.healthSummary,
      'cycle_count': status.cycleCount,
      'current_temperature': status.currentTemperature,
    };
  }

  Map<String, dynamic> _serializeBatteryEnergyStatus(
      BatteryEnergyStatus status) {
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

  List<String> _actionsForWearable(Wearable wearable) {
    final actions = <String>[
      'disconnect',
      'get_wearable_icon_path',
      'list_sensors',
      'list_sensor_configurations',
      'set_sensor_configuration',
      'set_sensor_frequency_best_effort',
      'set_sensor_maximum_frequency',
    ];

    void addIf<T>(List<String> names) {
      if (wearable.hasCapability<T>()) {
        actions.addAll(names);
      }
    }

    addIf<DeviceIdentifier>(<String>['read_device_identifier']);
    addIf<DeviceFirmwareVersion>(<String>[
      'read_device_firmware_version',
      'read_firmware_version_number',
      'check_firmware_support',
    ]);
    addIf<DeviceHardwareVersion>(<String>['read_device_hardware_version']);
    addIf<RgbLed>(<String>['write_led_color']);
    addIf<StatusLed>(<String>['show_status']);
    addIf<BatteryLevelStatus>(<String>['read_battery_percentage']);
    addIf<BatteryLevelStatusService>(<String>['read_power_status']);
    addIf<BatteryHealthStatusService>(<String>['read_health_status']);
    addIf<BatteryEnergyStatusService>(<String>['read_energy_status']);
    addIf<FrequencyPlayer>(<String>['play_frequency', 'list_wave_types']);
    addIf<JinglePlayer>(<String>['play_jingle', 'list_jingles']);
    addIf<AudioPlayerControls>(
        <String>['start_audio', 'pause_audio', 'stop_audio']);
    addIf<StoragePathAudioPlayer>(<String>['play_audio_from_storage_path']);
    addIf<AudioModeManager>(
        <String>['list_audio_modes', 'set_audio_mode', 'get_audio_mode']);
    addIf<MicrophoneManager>(
        <String>['list_microphones', 'set_microphone', 'get_microphone']);
    addIf<EdgeRecorderManager>(<String>['get_file_prefix', 'set_file_prefix']);
    addIf<StereoDevice>(<String>['get_position', 'pair', 'unpair']);
    addIf<SystemDevice>(<String>['is_connected_via_system']);
    addIf<TimeSynchronizable>(
        <String>['is_time_synchronized', 'synchronize_time']);

    final dynamic dynamicWearable = wearable;
    final hasMeasureAudioResponse = _hasDynamicMethod(
      dynamicWearable,
      'measureAudioResponse',
    );
    final hasMeasureFreqResponse = _hasDynamicMethod(
      dynamicWearable,
      'measureFreqResponse',
    );
    if (hasMeasureAudioResponse || hasMeasureFreqResponse) {
      actions
          .addAll(<String>['measure_audio_response', 'measure_freq_response']);
    }

    return actions;
  }

  List<String> _streamsForWearable(Wearable wearable) {
    final streams = <String>[];
    if (wearable.hasCapability<SensorManager>()) {
      streams.add('sensor_values');
    }
    if (wearable.hasCapability<SensorConfigurationManager>()) {
      streams.add('sensor_configuration');
    }
    if (wearable.hasCapability<ButtonManager>()) {
      streams.add('button_events');
    }
    if (wearable.hasCapability<BatteryLevelStatus>()) {
      streams.add('battery_percentage');
    }
    if (wearable.hasCapability<BatteryLevelStatusService>()) {
      streams.add('battery_power_status');
    }
    if (wearable.hasCapability<BatteryHealthStatusService>()) {
      streams.add('battery_health_status');
    }
    if (wearable.hasCapability<BatteryEnergyStatusService>()) {
      streams.add('battery_energy_status');
    }
    return streams;
  }

  bool _hasDynamicMethod(dynamic target, String methodName) {
    try {
      // ignore: unnecessary_statements
      target.noSuchMethod;
      switch (methodName) {
        case 'measureAudioResponse':
          // ignore: unnecessary_statements
          target.measureAudioResponse;
          return true;
        case 'measureFreqResponse':
          // ignore: unnecessary_statements
          target.measureFreqResponse;
          return true;
        default:
          return false;
      }
    } on NoSuchMethodError {
      return false;
    }
  }

  Wearable _requireConnectedWearable(String deviceId) {
    final wearable = _connectedWearablesById[deviceId];
    if (wearable == null) {
      throw StateError('No connected wearable for device_id: $deviceId');
    }
    return wearable;
  }

  T _requireCapability<T>(
    Wearable wearable, {
    required String action,
  }) {
    final capability = wearable.getCapability<T>();
    if (capability != null) {
      return capability;
    }
    throw UnsupportedError(
      'Action "$action" requires capability $T on ${wearable.deviceId}.',
    );
  }

  String _sensorId(Sensor sensor, int index) {
    final normalized = sensor.sensorName
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    return '${normalized}_$index';
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

  String _asString(Object? value, {required String name}) {
    if (value is String) {
      return value;
    }
    throw FormatException('Expected "$name" to be a string.');
  }

  bool? _asOptionalBool(Object? value) {
    if (value == null) {
      return null;
    }
    if (value is bool) {
      return value;
    }
    throw const FormatException('Expected a boolean.');
  }

  bool _asRequiredBool(Object? value, {required String name}) {
    if (value is bool) {
      return value;
    }
    throw FormatException('Expected "$name" to be a boolean.');
  }

  int _asInt(Object? value, {required String name}) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      final parsed = int.tryParse(value);
      if (parsed != null) {
        return parsed;
      }
    }
    throw FormatException('Expected "$name" to be an integer.');
  }

  double? _asDouble(Object? value) {
    if (value == null) {
      return null;
    }
    if (value is double) {
      return value;
    }
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      return double.tryParse(value);
    }
    return null;
  }

  List<String> _asStringList(Object? value) {
    if (value == null) {
      return <String>[];
    }
    if (value is List) {
      return value.map((entry) => entry.toString()).toList(growable: false);
    }
    throw FormatException('Expected a list of strings.');
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
            'Request method must be a non-empty string.');
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

extension<T> on Iterable<T> {
  T? get firstOrNull {
    if (isEmpty) {
      return null;
    }
    return first;
  }
}
