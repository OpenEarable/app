import 'package:flutter/foundation.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LslConnectorSettings {
  final bool enabled;
  final String host;
  final int port;
  final String streamPrefix;

  const LslConnectorSettings({
    required this.enabled,
    required this.host,
    required this.port,
    required this.streamPrefix,
  });

  const LslConnectorSettings.defaults()
      : enabled = false,
        host = '',
        port = defaultLslBridgePort,
        streamPrefix = defaultLslStreamPrefix;

  bool get isConfigured => host.trim().isNotEmpty;

  LslConnectorSettings copyWith({
    bool? enabled,
    String? host,
    int? port,
    String? streamPrefix,
  }) {
    return LslConnectorSettings(
      enabled: enabled ?? this.enabled,
      host: host ?? this.host,
      port: port ?? this.port,
      streamPrefix: streamPrefix ?? this.streamPrefix,
    );
  }
}

class ConnectorSettings {
  static const String _lslEnabledKey = 'connector_lsl_enabled';
  static const String _lslHostKey = 'connector_lsl_host';
  static const String _lslPortKey = 'connector_lsl_port';
  static const String _lslStreamPrefixKey = 'connector_lsl_stream_prefix';

  static final LslForwarder _lslForwarder = LslForwarder.instance;
  static final ValueNotifier<LslConnectorSettings> _lslSettingsNotifier =
      ValueNotifier<LslConnectorSettings>(
    const LslConnectorSettings.defaults(),
  );

  static ValueListenable<LslConnectorSettings> get lslSettingsListenable =>
      _lslSettingsNotifier;

  static bool get isLslActive {
    final settings = _lslSettingsNotifier.value;
    return settings.enabled && settings.isConfigured;
  }

  static LslConnectorSettings get currentLslSettings =>
      _lslSettingsNotifier.value;

  static Future<void> initialize() async {
    final settings = await loadLslSettings();
    _setLslSettings(settings);
    _ensureLslForwarderRegistered();
    applyLslSettings(settings);
  }

  static Future<LslConnectorSettings> loadLslSettings() async {
    final prefs = await SharedPreferences.getInstance();

    final rawSettings = LslConnectorSettings(
      enabled: prefs.getBool(_lslEnabledKey) ?? false,
      host: prefs.getString(_lslHostKey) ?? '',
      port: prefs.getInt(_lslPortKey) ?? defaultLslBridgePort,
      streamPrefix:
          prefs.getString(_lslStreamPrefixKey) ?? defaultLslStreamPrefix,
    );

    final normalized = _normalizeLslSettings(rawSettings);
    _setLslSettings(normalized);
    return normalized;
  }

  static Future<LslConnectorSettings> saveLslSettings(
    LslConnectorSettings settings,
  ) async {
    final normalized = _normalizeLslSettings(settings);
    final prefs = await SharedPreferences.getInstance();

    await prefs.setBool(_lslEnabledKey, normalized.enabled);
    await prefs.setString(_lslHostKey, normalized.host);
    await prefs.setInt(_lslPortKey, normalized.port);
    await prefs.setString(_lslStreamPrefixKey, normalized.streamPrefix);

    _setLslSettings(normalized);
    _ensureLslForwarderRegistered();
    applyLslSettings(normalized);

    return normalized;
  }

  static void applyLslSettings(LslConnectorSettings settings) {
    final normalized = _normalizeLslSettings(settings);
    _setLslSettings(normalized);

    if (!normalized.isConfigured || !normalized.enabled) {
      _lslForwarder.reset();
      return;
    }

    _lslForwarder.configure(
      host: normalized.host,
      port: normalized.port,
      enabled: normalized.enabled,
      streamPrefix: normalized.streamPrefix,
    );
  }

  static void _ensureLslForwarderRegistered() {
    final manager = WearableManager();
    final alreadyRegistered = manager.sensorForwarders.any(
      (forwarder) => identical(forwarder, _lslForwarder),
    );
    if (!alreadyRegistered) {
      manager.addSensorForwarder(_lslForwarder);
    }
  }

  static LslConnectorSettings _normalizeLslSettings(
    LslConnectorSettings settings,
  ) {
    final normalizedHost = settings.host.trim();
    final normalizedPort = (settings.port > 0 && settings.port <= 65535)
        ? settings.port
        : defaultLslBridgePort;
    final normalizedPrefix = settings.streamPrefix.trim().isEmpty
        ? defaultLslStreamPrefix
        : settings.streamPrefix.trim();
    final normalizedEnabled = normalizedHost.isNotEmpty && settings.enabled;

    return settings.copyWith(
      enabled: normalizedEnabled,
      host: normalizedHost,
      port: normalizedPort,
      streamPrefix: normalizedPrefix,
    );
  }

  static void _setLslSettings(LslConnectorSettings settings) {
    _lslSettingsNotifier.value = settings;
  }
}
