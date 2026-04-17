import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart' hide logger;

import 'logger.dart';

/// Coordinates runtime permission checks and requests for Bluetooth features.
///
/// Needs:
/// - Access to the shared [WearableManager] permission APIs.
/// - Optional navigation access for platform permission rationale dialogs.
///
/// Does:
/// - Checks whether Bluetooth-related runtime permissions are already granted.
/// - Shows a single in-app rationale dialog before requesting missing access.
/// - Serializes concurrent permission requests so multiple callers reuse one flow.
///
/// Provides:
/// - [ensureBluetoothPermissions] for feature code that needs BLE access.
class PermissionsHandler {
  final NavigatorState? Function() _navigatorGetter;
  final WearableManager _wearableManager;

  Future<bool>? _activeBluetoothPermissionRequest;
  bool _hasShownBluetoothRationaleThisSession = false;

  PermissionsHandler({
    required NavigatorState? Function() navigatorGetter,
    WearableManager? wearableManager,
  }) : _navigatorGetter = navigatorGetter,
       _wearableManager = wearableManager ?? WearableManager();

  /// Returns whether BLE-related runtime permissions are currently granted.
  Future<bool> hasBluetoothPermissions() async {
    if (!_requiresRuntimeBluetoothPermissions) {
      return true;
    }
    return _wearableManager.hasPermissions();
  }

  /// Ensures BLE-related runtime permissions are available before continuing.
  ///
  /// If permissions are missing, this method presents a rationale dialog once
  /// per app session and then delegates the actual OS permission request to the
  /// shared wearable manager.
  Future<bool> ensureBluetoothPermissions() {
    final inFlight = _activeBluetoothPermissionRequest;
    if (inFlight != null) {
      return inFlight;
    }

    final request = _performBluetoothPermissionRequest();
    _activeBluetoothPermissionRequest = request;
    request.whenComplete(() {
      if (identical(_activeBluetoothPermissionRequest, request)) {
        _activeBluetoothPermissionRequest = null;
      }
    });
    return request;
  }

  /// Whether the current platform requires explicit BLE runtime permissions.
  bool get _requiresRuntimeBluetoothPermissions {
    if (kIsWeb) {
      return false;
    }
    return Platform.isAndroid;
  }

  Future<bool> _performBluetoothPermissionRequest() async {
    if (!_requiresRuntimeBluetoothPermissions) {
      return true;
    }

    if (await hasBluetoothPermissions()) {
      return true;
    }

    if (!_hasShownBluetoothRationaleThisSession) {
      _hasShownBluetoothRationaleThisSession = true;
      await _showBluetoothPermissionRationale();
    }

    final granted = await WearableManager.checkAndRequestPermissions();
    if (!granted) {
      logger.w('Bluetooth permissions remain unavailable after request.');
    }
    return granted;
  }

  Future<void> _showBluetoothPermissionRationale() async {
    final navigator = _navigatorGetter();
    final context = navigator?.context;
    if (navigator == null || context == null) {
      return;
    }

    await navigator.push<void>(
      DialogRoute<void>(
        context: context,
        barrierDismissible: true,
        builder: (_) => PlatformAlertDialog(
          title: PlatformText('Permissions Required'),
          content: PlatformText(
            'Bluetooth scanning requires Bluetooth and Location permissions. '
            'Please grant the requested access so the app can discover and reconnect devices.',
          ),
          actions: [
            PlatformDialogAction(
              onPressed: navigator.pop,
              child: PlatformText('Continue'),
            ),
          ],
        ),
      ),
    );
  }
}
