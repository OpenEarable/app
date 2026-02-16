import 'package:shared_preferences/shared_preferences.dart';

class AutoConnectPreferences {
  static const String connectedDeviceNamesKey = 'connectedDeviceNames';

  static List<String> readRememberedDeviceNames(SharedPreferences prefs) {
    final names =
        prefs.getStringList(connectedDeviceNamesKey) ?? const <String>[];
    final uniqueNames = <String>{};

    for (final name in names) {
      final normalizedName = name.trim();
      if (normalizedName.isEmpty) {
        continue;
      }
      uniqueNames.add(normalizedName);
    }

    return uniqueNames.toList(growable: false);
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
    if (names.contains(normalizedName)) {
      return;
    }

    await prefs.setStringList(connectedDeviceNamesKey, <String>[
      ...names,
      normalizedName,
    ]);
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
    final updatedNames =
        names.where((name) => name != normalizedName).toList(growable: false);
    if (updatedNames.length == names.length) {
      return;
    }

    await prefs.setStringList(connectedDeviceNamesKey, updatedNames);
  }
}
