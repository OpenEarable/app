import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persistent preferences for Bluetooth auto-connect behavior.
///
/// Needs:
/// - `SharedPreferences` storage.
///
/// Does:
/// - Stores auto-connect enabled state.
/// - Stores remembered wearable names used for reconnect targeting.
/// - Emits change notifications for connector logic.
///
/// Provides:
/// - Static getters/listenables and helper methods for preference updates.
class AutoConnectPreferences {
  static const String connectedDeviceNamesKey = 'connectedDeviceNames';
  static const String autoConnectEnabledKey = 'auto_connect_enabled';
  static final StreamController<void> _changesController =
      StreamController<void>.broadcast();
  static final ValueNotifier<bool> _autoConnectEnabledNotifier =
      ValueNotifier<bool>(true);

  static Stream<void> get changes => _changesController.stream;
  static ValueListenable<bool> get autoConnectEnabledListenable =>
      _autoConnectEnabledNotifier;
  static bool get autoConnectEnabled => _autoConnectEnabledNotifier.value;

  static Future<void> initialize() async {
    await loadAutoConnectEnabled();
  }

  static Future<bool> loadAutoConnectEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool(autoConnectEnabledKey) ?? true;
    _setAutoConnectEnabled(enabled);
    return enabled;
  }

  static Future<bool> saveAutoConnectEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    final success = await prefs.setBool(autoConnectEnabledKey, enabled);
    if (success) {
      _setAutoConnectEnabled(enabled);
      _changesController.add(null);
    }
    return enabled;
  }

  static List<String> readRememberedDeviceNames(SharedPreferences prefs) {
    final names =
        prefs.getStringList(connectedDeviceNamesKey) ?? const <String>[];
    final normalizedNames = <String>[];

    for (final name in names) {
      final normalizedName = name.trim();
      if (normalizedName.isEmpty) {
        continue;
      }
      normalizedNames.add(normalizedName);
    }

    return normalizedNames;
  }

  static int countRememberedDeviceName(
    SharedPreferences prefs,
    String deviceName,
  ) {
    final normalizedName = deviceName.trim();
    if (normalizedName.isEmpty) {
      return 0;
    }
    final names = readRememberedDeviceNames(prefs);
    return names.where((name) => name == normalizedName).length;
  }

  static Future<void> rememberDeviceName(
    SharedPreferences prefs,
    String deviceName,
  ) async {
    final normalizedName = deviceName.trim();
    if (normalizedName.isEmpty) {
      return;
    }

    final names = readRememberedDeviceNames(prefs);

    final success = await prefs.setStringList(connectedDeviceNamesKey, <String>[
      ...names,
      normalizedName,
    ]);
    if (success) {
      _changesController.add(null);
    }
  }

  static Future<void> forgetDeviceName(
    SharedPreferences prefs,
    String deviceName,
  ) async {
    final normalizedName = deviceName.trim();
    if (normalizedName.isEmpty) {
      return;
    }

    final names = readRememberedDeviceNames(prefs);
    final index = names.indexOf(normalizedName);
    if (index < 0) {
      return;
    }
    final updatedNames = [...names]..removeAt(index);

    final success = await prefs.setStringList(
      connectedDeviceNamesKey,
      updatedNames,
    );
    if (success) {
      _changesController.add(null);
    }
  }

  static void _setAutoConnectEnabled(bool enabled) {
    if (_autoConnectEnabledNotifier.value == enabled) {
      return;
    }
    _autoConnectEnabledNotifier.value = enabled;
  }
}
