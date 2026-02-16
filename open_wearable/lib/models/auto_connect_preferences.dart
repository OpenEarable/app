import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

class AutoConnectPreferences {
  static const String connectedDeviceNamesKey = 'connectedDeviceNames';
  static final StreamController<void> _changesController =
      StreamController<void>.broadcast();

  static Stream<void> get changes => _changesController.stream;

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
}
