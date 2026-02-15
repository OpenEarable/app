// ignore_for_file: cancel_subscriptions

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UdpBridgeConnectorSettings {
  final bool enabled;
  final String host;
  final int port;
  final String streamPrefix;

  const UdpBridgeConnectorSettings({
    required this.enabled,
    required this.host,
    required this.port,
    required this.streamPrefix,
  });

  const UdpBridgeConnectorSettings.defaults()
      : enabled = false,
        host = '',
        port = defaultUdpBridgePort,
        streamPrefix = defaultUdpBridgeStreamPrefix;

  bool get isConfigured => host.trim().isNotEmpty;

  UdpBridgeConnectorSettings copyWith({
    bool? enabled,
    String? host,
    int? port,
    String? streamPrefix,
  }) {
    return UdpBridgeConnectorSettings(
      enabled: enabled ?? this.enabled,
      host: host ?? this.host,
      port: port ?? this.port,
      streamPrefix: streamPrefix ?? this.streamPrefix,
    );
  }
}

class ConnectorSettings {
  // Keep persisted keys stable to preserve existing user settings.
  static const String _udpBridgeEnabledKey = 'connector_lsl_enabled';
  static const String _udpBridgeHostKey = 'connector_lsl_host';
  static const String _udpBridgePortKey = 'connector_lsl_port';
  static const String _udpBridgeStreamPrefixKey = 'connector_lsl_stream_prefix';

  static final UdpBridgeForwarder _udpBridgeForwarder =
      UdpBridgeForwarder.instance;
  static final ValueNotifier<UdpBridgeConnectorSettings>
      _udpBridgeSettingsNotifier = ValueNotifier<UdpBridgeConnectorSettings>(
    const UdpBridgeConnectorSettings.defaults(),
  );
  static final ValueNotifier<SensorForwarderConnectionState>
      _udpBridgeConnectionStateNotifier =
      ValueNotifier<SensorForwarderConnectionState>(
    SensorForwarderConnectionState.active,
  );
  static StreamSubscription<SensorForwarderConnectionState>?
      _udpBridgeConnectionStateSubscription;

  static ValueListenable<UdpBridgeConnectorSettings>
      get udpBridgeSettingsListenable => _udpBridgeSettingsNotifier;
  static ValueListenable<SensorForwarderConnectionState>
      get udpBridgeConnectionStateListenable =>
          _udpBridgeConnectionStateNotifier;

  static bool get isUdpBridgeActive {
    final settings = _udpBridgeSettingsNotifier.value;
    return settings.enabled && settings.isConfigured;
  }

  static UdpBridgeConnectorSettings get currentUdpBridgeSettings =>
      _udpBridgeSettingsNotifier.value;

  static Future<void> initialize() async {
    _ensureUdpBridgeConnectionStateSubscription();
    final settings = await loadUdpBridgeSettings();
    _setUdpBridgeSettings(settings);
    _ensureUdpBridgeForwarderRegistered();
    applyUdpBridgeSettings(settings);
    _setUdpBridgeConnectionState(_udpBridgeForwarder.connectionState);
  }

  static void dispose() {
    final subscription = _udpBridgeConnectionStateSubscription;
    _udpBridgeConnectionStateSubscription = null;
    if (subscription != null) {
      unawaited(subscription.cancel());
    }
  }

  static Future<UdpBridgeConnectorSettings> loadUdpBridgeSettings() async {
    final prefs = await SharedPreferences.getInstance();

    final rawSettings = UdpBridgeConnectorSettings(
      enabled: prefs.getBool(_udpBridgeEnabledKey) ?? false,
      host: prefs.getString(_udpBridgeHostKey) ?? '',
      port: prefs.getInt(_udpBridgePortKey) ?? defaultUdpBridgePort,
      streamPrefix: prefs.getString(_udpBridgeStreamPrefixKey) ??
          defaultUdpBridgeStreamPrefix,
    );

    final normalized = _normalizeUdpBridgeSettings(rawSettings);
    _setUdpBridgeSettings(normalized);
    return normalized;
  }

  static Future<UdpBridgeConnectorSettings> saveUdpBridgeSettings(
    UdpBridgeConnectorSettings settings,
  ) async {
    final normalized = _normalizeUdpBridgeSettings(settings);
    final prefs = await SharedPreferences.getInstance();

    await prefs.setBool(_udpBridgeEnabledKey, normalized.enabled);
    await prefs.setString(_udpBridgeHostKey, normalized.host);
    await prefs.setInt(_udpBridgePortKey, normalized.port);
    await prefs.setString(_udpBridgeStreamPrefixKey, normalized.streamPrefix);

    _setUdpBridgeSettings(normalized);
    _ensureUdpBridgeForwarderRegistered();
    applyUdpBridgeSettings(normalized);

    return normalized;
  }

  static void applyUdpBridgeSettings(UdpBridgeConnectorSettings settings) {
    final normalized = _normalizeUdpBridgeSettings(settings);
    _setUdpBridgeSettings(normalized);
    _ensureUdpBridgeConnectionStateSubscription();

    if (!normalized.isConfigured || !normalized.enabled) {
      _udpBridgeForwarder.reset();
      _setUdpBridgeConnectionState(_udpBridgeForwarder.connectionState);
      return;
    }

    _udpBridgeForwarder.configure(
      host: normalized.host,
      port: normalized.port,
      enabled: normalized.enabled,
      streamPrefix: normalized.streamPrefix,
    );
    _setUdpBridgeConnectionState(_udpBridgeForwarder.connectionState);
  }

  static void _ensureUdpBridgeForwarderRegistered() {
    final manager = WearableManager();
    final alreadyRegistered = manager.sensorForwarders.any(
      (forwarder) => identical(forwarder, _udpBridgeForwarder),
    );
    if (!alreadyRegistered) {
      manager.addSensorForwarder(_udpBridgeForwarder);
    }
  }

  static UdpBridgeConnectorSettings _normalizeUdpBridgeSettings(
    UdpBridgeConnectorSettings settings,
  ) {
    final normalizedHost = settings.host.trim();
    final normalizedPort = (settings.port > 0 && settings.port <= 65535)
        ? settings.port
        : defaultUdpBridgePort;
    final normalizedPrefix = settings.streamPrefix.trim().isEmpty
        ? defaultUdpBridgeStreamPrefix
        : settings.streamPrefix.trim();
    final normalizedEnabled = normalizedHost.isNotEmpty && settings.enabled;

    return settings.copyWith(
      enabled: normalizedEnabled,
      host: normalizedHost,
      port: normalizedPort,
      streamPrefix: normalizedPrefix,
    );
  }

  static void _setUdpBridgeSettings(UdpBridgeConnectorSettings settings) {
    _udpBridgeSettingsNotifier.value = settings;
  }

  static void _ensureUdpBridgeConnectionStateSubscription() {
    if (_udpBridgeConnectionStateSubscription != null) {
      return;
    }
    _udpBridgeConnectionStateSubscription = _udpBridgeForwarder
        .connectionStateStream
        .listen(_setUdpBridgeConnectionState);
  }

  static void _setUdpBridgeConnectionState(
    SensorForwarderConnectionState state,
  ) {
    if (_udpBridgeConnectionStateNotifier.value == state) {
      return;
    }
    _udpBridgeConnectionStateNotifier.value = state;
  }
}
