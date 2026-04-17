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
  static final ValueNotifier<List<String>> _rememberedDeviceNamesNotifier =
      ValueNotifier<List<String>>(const <String>[]);

  /// Broadcasts any persisted auto-connect preference change.
  static Stream<void> get changes => _changesController.stream;

  /// Exposes the stored Bluetooth auto-connect toggle state.
  static ValueListenable<bool> get autoConnectEnabledListenable =>
      _autoConnectEnabledNotifier;

  /// Returns the currently cached Bluetooth auto-connect toggle state.
  static bool get autoConnectEnabled => _autoConnectEnabledNotifier.value;

  /// Exposes the normalized remembered device names used for auto-connect.
  static ValueListenable<List<String>> get rememberedDeviceNamesListenable =>
      _rememberedDeviceNamesNotifier;

  /// Returns the currently cached remembered device names used for
  /// auto-connect.
  static List<String> get rememberedDeviceNames =>
      List<String>.unmodifiable(_rememberedDeviceNamesNotifier.value);

  /// Loads the persisted auto-connect settings into the in-memory notifiers.
  static Future<void> initialize() async {
    await loadAutoConnectEnabled();
    await loadRememberedDeviceNames();
  }

  /// Loads the persisted auto-connect enabled flag from storage.
  static Future<bool> loadAutoConnectEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool(autoConnectEnabledKey) ?? true;
    _setAutoConnectEnabled(enabled);
    return enabled;
  }

  /// Persists the auto-connect enabled flag and updates listeners on success.
  static Future<bool> saveAutoConnectEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    final success = await prefs.setBool(autoConnectEnabledKey, enabled);
    if (success) {
      _setAutoConnectEnabled(enabled);
      _changesController.add(null);
    }
    return enabled;
  }

  /// Loads the remembered auto-connect device names from storage.
  static Future<List<String>> loadRememberedDeviceNames() async {
    final prefs = await SharedPreferences.getInstance();
    final rememberedNames = readRememberedDeviceNames(prefs);
    _setRememberedDeviceNames(rememberedNames);
    return rememberedNames;
  }

  /// Reads normalized remembered device names from the provided preferences.
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

  /// Counts how often a device name appears in the remembered device list.
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

  /// Persists a remembered device name for future background auto-connect.
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
      _setRememberedDeviceNames(<String>[
        ...names,
        normalizedName,
      ]);
      _changesController.add(null);
    }
  }

  /// Removes one remembered device-name entry from the auto-connect targets.
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
      _setRememberedDeviceNames(updatedNames);
      _changesController.add(null);
    }
  }

  static void _setAutoConnectEnabled(bool enabled) {
    if (_autoConnectEnabledNotifier.value == enabled) {
      return;
    }
    _autoConnectEnabledNotifier.value = enabled;
  }

  /// Updates the cached remembered device names for listening widgets.
  static void _setRememberedDeviceNames(List<String> deviceNames) {
    if (listEquals(_rememberedDeviceNamesNotifier.value, deviceNames)) {
      return;
    }
    _rememberedDeviceNamesNotifier.value = List<String>.unmodifiable(
      List<String>.from(deviceNames),
    );
  }
}
