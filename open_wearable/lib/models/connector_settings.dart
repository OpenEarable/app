// ignore_for_file: cancel_subscriptions

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'connectors/websocket_ipc_server.dart';

class WebSocketConnectorSettings {
  final bool enabled;
  final String host;
  final int port;
  final String path;

  const WebSocketConnectorSettings({
    required this.enabled,
    required this.host,
    required this.port,
    required this.path,
  });

  const WebSocketConnectorSettings.defaults()
      : enabled = false,
        host = WebSocketIpcServer.defaultHost,
        port = WebSocketIpcServer.defaultPort,
        path = WebSocketIpcServer.defaultPath;

  bool get isConfigured => host.trim().isNotEmpty;

  Uri get endpoint => Uri(
        scheme: 'ws',
        host: host,
        port: port,
        path: path,
      );

  WebSocketConnectorSettings copyWith({
    bool? enabled,
    String? host,
    int? port,
    String? path,
  }) {
    return WebSocketConnectorSettings(
      enabled: enabled ?? this.enabled,
      host: host ?? this.host,
      port: port ?? this.port,
      path: path ?? this.path,
    );
  }
}

enum ConnectorRuntimeState {
  disabled,
  starting,
  running,
  error,
}

class ConnectorRuntimeStatus {
  final ConnectorRuntimeState state;
  final String? message;

  const ConnectorRuntimeStatus({
    required this.state,
    this.message,
  });

  const ConnectorRuntimeStatus.disabled()
      : state = ConnectorRuntimeState.disabled,
        message = null;

  const ConnectorRuntimeStatus.starting()
      : state = ConnectorRuntimeState.starting,
        message = null;

  const ConnectorRuntimeStatus.running()
      : state = ConnectorRuntimeState.running,
        message = null;

  const ConnectorRuntimeStatus.error(this.message)
      : state = ConnectorRuntimeState.error;
}

class ConnectorSettings {
  static const String _websocketEnabledKey = 'connector_websocket_enabled';
  static const String _websocketHostKey = 'connector_websocket_host';
  static const String _websocketPortKey = 'connector_websocket_port';
  static const String _websocketPathKey = 'connector_websocket_path';

  static final WebSocketIpcServer _webSocketServer = WebSocketIpcServer();

  static final ValueNotifier<WebSocketConnectorSettings>
      _webSocketSettingsNotifier = ValueNotifier<WebSocketConnectorSettings>(
    const WebSocketConnectorSettings.defaults(),
  );

  static final ValueNotifier<ConnectorRuntimeStatus>
      _webSocketRuntimeStatusNotifier = ValueNotifier<ConnectorRuntimeStatus>(
    const ConnectorRuntimeStatus.disabled(),
  );

  static ValueListenable<WebSocketConnectorSettings>
      get webSocketSettingsListenable => _webSocketSettingsNotifier;

  static ValueListenable<ConnectorRuntimeStatus>
      get webSocketRuntimeStatusListenable => _webSocketRuntimeStatusNotifier;

  static WebSocketConnectorSettings get currentWebSocketSettings =>
      _webSocketSettingsNotifier.value;

  static ConnectorRuntimeStatus get currentWebSocketRuntimeStatus =>
      _webSocketRuntimeStatusNotifier.value;

  static Future<void> initialize() async {
    final settings = await loadWebSocketSettings();
    await applyWebSocketSettings(settings);
  }

  static Future<void> dispose() async {
    await _webSocketServer.stop();
    _setRuntimeStatus(const ConnectorRuntimeStatus.disabled());
  }

  static Future<WebSocketConnectorSettings> loadWebSocketSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = WebSocketConnectorSettings(
      enabled: prefs.getBool(_websocketEnabledKey) ?? false,
      host:
          prefs.getString(_websocketHostKey) ?? WebSocketIpcServer.defaultHost,
      port: prefs.getInt(_websocketPortKey) ?? WebSocketIpcServer.defaultPort,
      path:
          prefs.getString(_websocketPathKey) ?? WebSocketIpcServer.defaultPath,
    );

    final normalized = _normalizeWebSocketSettings(raw);
    _setWebSocketSettings(normalized);
    return normalized;
  }

  static Future<WebSocketConnectorSettings> saveWebSocketSettings(
    WebSocketConnectorSettings settings,
  ) async {
    final normalized = _normalizeWebSocketSettings(settings);
    final prefs = await SharedPreferences.getInstance();

    await prefs.setBool(_websocketEnabledKey, normalized.enabled);
    await prefs.setString(_websocketHostKey, normalized.host);
    await prefs.setInt(_websocketPortKey, normalized.port);
    await prefs.setString(_websocketPathKey, normalized.path);

    _setWebSocketSettings(normalized);
    await applyWebSocketSettings(normalized);
    return normalized;
  }

  static Future<void> applyWebSocketSettings(
    WebSocketConnectorSettings settings,
  ) async {
    final normalized = _normalizeWebSocketSettings(settings);
    _setWebSocketSettings(normalized);

    if (!normalized.enabled || !normalized.isConfigured) {
      await _webSocketServer.stop();
      _setRuntimeStatus(const ConnectorRuntimeStatus.disabled());
      return;
    }

    _setRuntimeStatus(const ConnectorRuntimeStatus.starting());

    try {
      await _webSocketServer.start(
        host: normalized.host,
        port: normalized.port,
        path: normalized.path,
      );
      _setRuntimeStatus(const ConnectorRuntimeStatus.running());
    } catch (error) {
      _setRuntimeStatus(ConnectorRuntimeStatus.error(error.toString()));
      rethrow;
    }
  }

  static WebSocketConnectorSettings _normalizeWebSocketSettings(
    WebSocketConnectorSettings settings,
  ) {
    final host = settings.host.trim().isEmpty
        ? WebSocketIpcServer.defaultHost
        : settings.host.trim();
    final port = (settings.port > 0 && settings.port <= 65535)
        ? settings.port
        : WebSocketIpcServer.defaultPort;
    final path = _normalizePath(settings.path);

    return settings.copyWith(
      host: host,
      port: port,
      path: path,
      enabled: settings.enabled,
    );
  }

  static String _normalizePath(String path) {
    final trimmed = path.trim();
    if (trimmed.isEmpty) {
      return WebSocketIpcServer.defaultPath;
    }
    return trimmed.startsWith('/') ? trimmed : '/$trimmed';
  }

  static void _setWebSocketSettings(WebSocketConnectorSettings settings) {
    _webSocketSettingsNotifier.value = settings;
  }

  static void _setRuntimeStatus(ConnectorRuntimeStatus status) {
    _webSocketRuntimeStatusNotifier.value = status;
  }
}
