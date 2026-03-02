import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class SensorConfigurationStorage {
  static const String _scopeSeparator = '__';

  /// Returns the directory where sensor configurations are stored.
  /// Creates the directory if it does not exist.
  static Future<Directory> _getConfigDirectory() async {
    final dir = await getApplicationDocumentsDirectory();
    final configDir = Directory('${dir.path}/sensor_configurations');
    if (!await configDir.exists()) {
      await configDir.create(recursive: true);
    }
    return configDir;
  }

  /// Returns a list of all configuration files in the sensor configurations directory.
  /// Each file is expected to be a JSON file with a specific configuration.
  static Future<List<File>> _getAllConfigFiles() async {
    final configDir = await _getConfigDirectory();
    final files = <File>[];
    try {
      await for (final entity in configDir.list(followLinks: false)) {
        if (entity is File && entity.path.toLowerCase().endsWith('.json')) {
          files.add(entity);
        }
      }
    } on FileSystemException {
      return const [];
    }
    return files;
  }

  /// Returns the file for a specific configuration key.
  /// Creates the file if it does not exist.
  static Future<File> _getConfigFile(String key) async {
    final configDir = await _getConfigDirectory();
    return File('${configDir.path}/${sanitizeKey(key)}.json');
  }

  /// Saves a configuration for a specific key.
  /// If the file already exists, it will be overwritten.
  /// The configuration is expected to be a map of string key-value pairs.
  static Future<void> saveConfiguration(
    String key,
    Map<String, String> config,
  ) async {
    final File file = await _getConfigFile(key);
    await file.writeAsString(jsonEncode(config));
  }

  static Future<List<String>> listConfigurationKeys() async {
    final files = await _getAllConfigFiles();
    return files.map(_getKeyFromFile).where((key) => key.isNotEmpty).toList();
  }

  static String _getKeyFromFile(File file) =>
      file.uri.pathSegments.last.replaceAll('.json', '');

  /// Loads all configurations from the sensor configurations directory.
  /// Returns a map where the keys are configuration names and the values are maps of string key-value pairs.
  /// Each configuration is expected to be stored in a JSON file.
  static Future<Map<String, Map<String, String>>> loadConfigurations() async {
    final allConfigs = <String, Map<String, String>>{};
    final configFiles = await _getAllConfigFiles();
    for (final file in configFiles) {
      final contents = await file.readAsString();
      allConfigs[_getKeyFromFile(file)] =
          Map<String, String>.from(jsonDecode(contents));
    }
    return allConfigs;
  }

  static Future<Map<String, String>> loadConfiguration(String key) async {
    final file = await _getConfigFile(key);
    if (await file.exists()) {
      final contents = await file.readAsString();
      return Map<String, String>.from(jsonDecode(contents));
    }
    return {};
  }

  /// Deletes a specific configuration by its key.
  /// If the file does not exist, it will do nothing.
  static Future<void> deleteConfiguration(String key) async {
    final file = await _getConfigFile(key);
    if (await file.exists()) {
      await file.delete();
    }
  }

  static String scopedPrefix(String scope) =>
      '${sanitizeKey(scope)}$_scopeSeparator';

  static String normalizeDeviceNameForScope(String deviceName) {
    final compact = deviceName.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (compact.isEmpty) {
      return 'unknown_device';
    }
    return sanitizeKey(compact.toLowerCase());
  }

  static String? normalizeFirmwareVersionForScope(String? firmwareVersion) {
    if (firmwareVersion == null) {
      return null;
    }
    var normalized = firmwareVersion.trim().toLowerCase();
    if (normalized.isEmpty) {
      return null;
    }
    normalized = normalized.replaceFirst(RegExp(r'^v(?=\d)'), '');
    if (normalized.isEmpty) {
      return null;
    }
    return sanitizeKey(normalized);
  }

  static String deviceNameScope(String deviceName) =>
      'name_${normalizeDeviceNameForScope(deviceName)}';

  static String? deviceNameFirmwareScope({
    required String deviceName,
    required String? firmwareVersion,
  }) {
    final normalizedFirmware =
        normalizeFirmwareVersionForScope(firmwareVersion);
    if (normalizedFirmware == null) {
      return null;
    }
    return '${deviceNameScope(deviceName)}__fw_$normalizedFirmware';
  }

  static String buildScopedKey({
    required String scope,
    required String name,
  }) {
    final sanitizedName = sanitizeKey(name.trim());
    return '${scopedPrefix(scope)}$sanitizedName';
  }

  static bool keyMatchesScope(String key, String scope) {
    return key.startsWith(scopedPrefix(scope));
  }

  static String displayNameFromScopedKey(
    String key, {
    required String scope,
  }) {
    if (!keyMatchesScope(key, scope)) {
      return key.replaceAll('_', ' ');
    }
    return key.substring(scopedPrefix(scope).length).replaceAll('_', ' ');
  }

  static bool isLegacyUnscopedKey(String key) => !key.contains(_scopeSeparator);

  static String sanitizeKey(String key) =>
      key.replaceAll(RegExp(r'[^\w\-]'), '_');
}

class DeviceProfileScopeMatch {
  final String nameScope;
  final String? firmwareScope;

  const DeviceProfileScopeMatch({
    required this.nameScope,
    required this.firmwareScope,
  });

  factory DeviceProfileScopeMatch.forDevice({
    required String deviceName,
    String? firmwareVersion,
  }) {
    return DeviceProfileScopeMatch(
      nameScope: SensorConfigurationStorage.deviceNameScope(deviceName),
      firmwareScope: SensorConfigurationStorage.deviceNameFirmwareScope(
        deviceName: deviceName,
        firmwareVersion: firmwareVersion,
      ),
    );
  }

  String get saveScope => firmwareScope ?? nameScope;

  String? matchingScopeForKey(String key) {
    final preferredScope = firmwareScope ?? nameScope;
    if (SensorConfigurationStorage.keyMatchesScope(key, preferredScope)) {
      return preferredScope;
    }
    return null;
  }

  bool matchesScopedKey(String key) => matchingScopeForKey(key) != null;

  bool allowsKey(String key) =>
      matchesScopedKey(key) ||
      SensorConfigurationStorage.isLegacyUnscopedKey(key);
}
