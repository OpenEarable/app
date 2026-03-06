import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persisted app-wide shutdown and live-data display settings.
///
/// Needs:
/// - `SharedPreferences` availability.
///
/// Does:
/// - Loads/saves settings and mirrors them through `ValueNotifier`s.
///
/// Provides:
/// - Synchronous getters and `ValueListenable`s consumed by UI/lifecycle code.
class AppShutdownSettings {
  static const String _shutOffAllSensorsOnAppCloseKey =
      'app_shut_off_all_sensors_on_close';
  static const String _disableLiveDataGraphsKey =
      'app_disable_live_data_graphs';
  static const String _hideLiveDataGraphsWithoutDataKey =
      'app_hide_live_data_graphs_without_data';

  static final ValueNotifier<bool> _shutOffAllSensorsOnAppCloseNotifier =
      ValueNotifier<bool>(false);
  static final ValueNotifier<bool> _disableLiveDataGraphsNotifier =
      ValueNotifier<bool>(false);
  static final ValueNotifier<bool> _hideLiveDataGraphsWithoutDataNotifier =
      ValueNotifier<bool>(false);

  static ValueListenable<bool> get shutOffAllSensorsOnAppCloseListenable =>
      _shutOffAllSensorsOnAppCloseNotifier;
  static ValueListenable<bool> get disableLiveDataGraphsListenable =>
      _disableLiveDataGraphsNotifier;
  static ValueListenable<bool> get hideLiveDataGraphsWithoutDataListenable =>
      _hideLiveDataGraphsWithoutDataNotifier;

  static bool get shutOffAllSensorsOnAppClose =>
      _shutOffAllSensorsOnAppCloseNotifier.value;
  static bool get disableLiveDataGraphs => _disableLiveDataGraphsNotifier.value;
  static bool get hideLiveDataGraphsWithoutData =>
      _hideLiveDataGraphsWithoutDataNotifier.value;

  static Future<void> initialize() async {
    await Future.wait([
      loadShutOffAllSensorsOnAppClose(),
      loadDisableLiveDataGraphs(),
      loadHideLiveDataGraphsWithoutData(),
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

  static Future<bool> loadHideLiveDataGraphsWithoutData() async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool(_hideLiveDataGraphsWithoutDataKey) ?? false;
    _setHideLiveDataGraphsWithoutData(enabled);
    return enabled;
  }

  static Future<bool> saveHideLiveDataGraphsWithoutData(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_hideLiveDataGraphsWithoutDataKey, enabled);
    _setHideLiveDataGraphsWithoutData(enabled);
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

  static void _setHideLiveDataGraphsWithoutData(bool enabled) {
    if (_hideLiveDataGraphsWithoutDataNotifier.value == enabled) {
      return;
    }
    _hideLiveDataGraphsWithoutDataNotifier.value = enabled;
  }
}
