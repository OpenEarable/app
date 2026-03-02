import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class SensorConfigurationStorage {
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
    return configDir.list().where((file) =>
      file is File && file.path.endsWith('.json'),
    ).cast<File>().toList();
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
  static Future<void> saveConfiguration(String key, Map<String, String> config) async {
    final File file = await _getConfigFile(key);
    await file.writeAsString(jsonEncode(config));
  }

  static Future<List<String>> listConfigurationKeys() async {
    final files = await _getAllConfigFiles();
    return files.map(_getKeyFromFile).toList();
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
      allConfigs[_getKeyFromFile(file)] = Map<String, String>.from(jsonDecode(contents));
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

  static String sanitizeKey(String key) => key.replaceAll(RegExp(r'[^\w\-]'), '_');
}
