import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:universal_ble/universal_ble.dart';

/// Helper for checking app-wide permissions including BLE and microphone.
class PermissionsHelper {
  static const bool _requestAndroidBleLocationPermission = true;

  /// Checks if all required permissions are granted.
  static Future<bool> hasAllPermissions() async {
    if (kIsWeb) {
      return true; // Permissions are not required on web
    }

    final hasBle = await hasBlePermissions();
    if (!hasBle) {
      return false;
    }

    // Microphone permission is currently requested on Android and Windows.
    if (Platform.isAndroid || Platform.isWindows) {
      return await Permission.microphone.isGranted;
    }

    return true;
  }

  /// Checks if BLE permissions are granted (without microphone).
  static Future<bool> hasBlePermissions() async {
    if (kIsWeb) {
      return true;
    }

    if (Platform.isAndroid) {
      return await UniversalBle.hasPermissions(
        withAndroidFineLocation: _requestAndroidBleLocationPermission,
      );
    }

    if (Platform.isIOS || Platform.isMacOS) {
      return await UniversalBle.hasPermissions();
    }

    return true;
  }

  /// Requests BLE permissions using the same platform path as the app checks.
  static Future<bool> requestBlePermissions() async {
    if (kIsWeb) {
      return true;
    }

    try {
      if (Platform.isAndroid) {
        await UniversalBle.requestPermissions(
          withAndroidFineLocation: _requestAndroidBleLocationPermission,
        );
      } else if (Platform.isIOS || Platform.isMacOS) {
        await UniversalBle.requestPermissions();
      } else {
        return true;
      }
    } catch (_) {
      // Fall through to the final status check so callers get a consistent bool.
    }

    return await hasBlePermissions();
  }

  /// Checks if microphone permission is granted.
  static Future<bool> hasMicrophonePermission() async {
    if (kIsWeb || (!Platform.isAndroid && !Platform.isWindows)) {
      return true;
    }

    return await Permission.microphone.isGranted;
  }
}
