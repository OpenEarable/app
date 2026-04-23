// ignore_for_file: cancel_subscriptions

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:open_wearable/models/wearable_connector.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'connectors/websocket_ipc_server.dart';

/// Persisted configuration for the network connector.
class WebSocketConnectorSettings {
  final bool enabled;
  final int port;
  final String path;

  const WebSocketConnectorSettings({
    required this.enabled,
    required this.port,
    required this.path,
  });

  const WebSocketConnectorSettings.defaults()
      : enabled = false,
        port = WebSocketIpcServer.defaultPort,
        path = WebSocketIpcServer.defaultPath;

  /// Returns a copy with selectively replaced fields.
  WebSocketConnectorSettings copyWith({
    bool? enabled,
    int? port,
    String? path,
  }) {
    return WebSocketConnectorSettings(
      enabled: enabled ?? this.enabled,
      port: port ?? this.port,
      path: path ?? this.path,
    );
  }
}

/// High-level runtime state of the connector server.
enum ConnectorRuntimeState {
  disabled,
  starting,
  running,
  error,
}

/// Snapshot of the current connector runtime state and message.
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

  /// Whether the connector is currently enabled and participating in runtime
  /// work.
  bool get isActive =>
      state == ConnectorRuntimeState.starting ||
      state == ConnectorRuntimeState.running;
}

/// Loads, normalizes, persists, and applies connector settings.
class ConnectorSettings {
  static const String _websocketEnabledKey = 'connector_websocket_enabled';
  static const String _websocketHostKey = 'connector_websocket_host';
  static const String _websocketPortKey = 'connector_websocket_port';
  static const String _websocketPathKey = 'connector_websocket_path';

  static WebSocketIpcServer _webSocketServer = WebSocketIpcServer();

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

  /// Returns the current persisted settings snapshot.
  static WebSocketConnectorSettings get currentWebSocketSettings =>
      _webSocketSettingsNotifier.value;

  /// Returns the current runtime status snapshot.
  static ConnectorRuntimeStatus get currentWebSocketRuntimeStatus =>
      _webSocketRuntimeStatusNotifier.value;

  /// Initializes the server runtime and applies persisted settings.
  static Future<void> initialize({
    WearableConnector? wearableConnector,
  }) async {
    if (wearableConnector != null) {
      _webSocketServer = WebSocketIpcServer(
        wearableConnector: wearableConnector,
      );
    }
    final settings = await loadWebSocketSettings();
    await applyWebSocketSettings(settings);
  }

  /// Stops the running server and resets the runtime status.
  static Future<void> dispose() async {
    await _webSocketServer.stop();
    _setRuntimeStatus(const ConnectorRuntimeStatus.disabled());
  }

  /// Loads persisted websocket settings and normalizes any legacy values.
  static Future<WebSocketConnectorSettings> loadWebSocketSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = WebSocketConnectorSettings(
      enabled: prefs.getBool(_websocketEnabledKey) ?? false,
      port: prefs.getInt(_websocketPortKey) ?? WebSocketIpcServer.defaultPort,
      path:
          prefs.getString(_websocketPathKey) ?? WebSocketIpcServer.defaultPath,
    );

    final normalized = _normalizeWebSocketSettings(raw);
    _setWebSocketSettings(normalized);
    return normalized;
  }

  /// Saves websocket settings, removes deprecated host state, and applies them.
  static Future<WebSocketConnectorSettings> saveWebSocketSettings(
    WebSocketConnectorSettings settings,
  ) async {
    final normalized = _normalizeWebSocketSettings(settings);
    final prefs = await SharedPreferences.getInstance();

    await prefs.setBool(_websocketEnabledKey, normalized.enabled);
    await prefs.setInt(_websocketPortKey, normalized.port);
    await prefs.setString(_websocketPathKey, normalized.path);
    await prefs.remove(_websocketHostKey);

    _setWebSocketSettings(normalized);
    await applyWebSocketSettings(normalized);
    return normalized;
  }

  /// Applies the given settings to the websocket server.
  static Future<void> applyWebSocketSettings(
    WebSocketConnectorSettings settings,
  ) async {
    final normalized = _normalizeWebSocketSettings(settings);
    _setWebSocketSettings(normalized);

    if (!normalized.enabled) {
      await _webSocketServer.stop();
      _setRuntimeStatus(const ConnectorRuntimeStatus.disabled());
      return;
    }

    _setRuntimeStatus(const ConnectorRuntimeStatus.starting());

    try {
      await _webSocketServer.start(
        port: normalized.port,
        path: normalized.path,
      );
      _setRuntimeStatus(const ConnectorRuntimeStatus.running());
    } catch (error) {
      _setRuntimeStatus(ConnectorRuntimeStatus.error(error.toString()));
      rethrow;
    }
  }

  /// Normalizes persisted settings into a valid runtime configuration.
  static WebSocketConnectorSettings _normalizeWebSocketSettings(
    WebSocketConnectorSettings settings,
  ) {
    final port = (settings.port > 0 && settings.port <= 65535)
        ? settings.port
        : WebSocketIpcServer.defaultPort;
    final path = _normalizePath(settings.path);

    return settings.copyWith(
      port: port,
      path: path,
      enabled: settings.enabled,
    );
  }

  /// Ensures the websocket path is non-empty and starts with `/`.
  static String _normalizePath(String path) {
    final trimmed = path.trim();
    if (trimmed.isEmpty) {
      return WebSocketIpcServer.defaultPath;
    }
    return trimmed.startsWith('/') ? trimmed : '/$trimmed';
  }

  /// Publishes the current settings snapshot to listeners.
  static void _setWebSocketSettings(WebSocketConnectorSettings settings) {
    _webSocketSettingsNotifier.value = settings;
  }

  /// Publishes the current runtime status to listeners.
  static void _setRuntimeStatus(ConnectorRuntimeStatus status) {
    _webSocketRuntimeStatusNotifier.value = status;
  }
}
