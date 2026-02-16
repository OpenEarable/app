import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppShutdownSettings {
  static const String _shutOffAllSensorsOnAppCloseKey =
      'app_shut_off_all_sensors_on_close';
  static const String _disableLiveDataGraphsKey =
      'app_disable_live_data_graphs';

  static final ValueNotifier<bool> _shutOffAllSensorsOnAppCloseNotifier =
      ValueNotifier<bool>(false);
  static final ValueNotifier<bool> _disableLiveDataGraphsNotifier =
      ValueNotifier<bool>(false);

  static ValueListenable<bool> get shutOffAllSensorsOnAppCloseListenable =>
      _shutOffAllSensorsOnAppCloseNotifier;
  static ValueListenable<bool> get disableLiveDataGraphsListenable =>
      _disableLiveDataGraphsNotifier;

  static bool get shutOffAllSensorsOnAppClose =>
      _shutOffAllSensorsOnAppCloseNotifier.value;
  static bool get disableLiveDataGraphs => _disableLiveDataGraphsNotifier.value;

  static Future<void> initialize() async {
    await Future.wait([
      loadShutOffAllSensorsOnAppClose(),
      loadDisableLiveDataGraphs(),
    ]);
  }

  static Future<bool> loadShutOffAllSensorsOnAppClose() async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool(_shutOffAllSensorsOnAppCloseKey) ?? false;
    _setShutOffAllSensorsOnAppClose(enabled);
    return enabled;
  }

  static Future<bool> saveShutOffAllSensorsOnAppClose(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_shutOffAllSensorsOnAppCloseKey, enabled);
    _setShutOffAllSensorsOnAppClose(enabled);
    return enabled;
  }

  static Future<bool> loadDisableLiveDataGraphs() async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool(_disableLiveDataGraphsKey) ?? false;
    _setDisableLiveDataGraphs(enabled);
    return enabled;
  }

  static Future<bool> saveDisableLiveDataGraphs(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_disableLiveDataGraphsKey, enabled);
    _setDisableLiveDataGraphs(enabled);
    return enabled;
  }

  static void _setShutOffAllSensorsOnAppClose(bool enabled) {
    if (_shutOffAllSensorsOnAppCloseNotifier.value == enabled) {
      return;
    }
    _shutOffAllSensorsOnAppCloseNotifier.value = enabled;
  }

  static void _setDisableLiveDataGraphs(bool enabled) {
    if (_disableLiveDataGraphsNotifier.value == enabled) {
      return;
    }
    _disableLiveDataGraphsNotifier.value = enabled;
  }
}
