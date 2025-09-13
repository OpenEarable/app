import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart';

import 'wearable_connector.dart';

class BluetoothAutoConnector {
  final NavigatorState? Function() navStateGetter; // () => rootNavigatorKey.currentState
  final Duration interval;
  final WearableManager wearableManager;
  final WearableConnector connector;

  Timer? _timer;
  bool _running = false;
  bool _askedPermissionsThisSession = false;

  BluetoothAutoConnector({
    required this.navStateGetter,
    required this.wearableManager,
    required this.connector,
    this.interval = const Duration(seconds: 3),
  });

  void start() {
    _timer ??= Timer.periodic(interval, (_) => _tick());
    // kick once immediately
    _tick();
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _tick() async {
    if (_running) return;
    _running = true;
    try {
      // 1) Permissions (Android). iOS: skip dialog.
      if (!Platform.isIOS) {
        final hasPerm = await wearableManager.hasPermissions();
        if (!hasPerm && !_askedPermissionsThisSession) {
          _askedPermissionsThisSession = true;
          _showPermissionsDialog();
          // Don’t attempt connecting until user saw dialog at least once.
          logger.w('Skipping auto-connect: no permissions granted yet.');
          _running = false;
          return;
        }
      }

      connector.connectToSystemDevices();
    } catch (e, st) {
      logger.w('Auto-connect tick failed: $e\n$st');
    } finally {
      _running = false;
    }
  }

  void _showPermissionsDialog() {
    final nav = navStateGetter();
    final navCtx = nav?.context;
    if (nav == null || navCtx == null) return;

    // Fire-and-forget; no async/await needed here
    nav.push(
      DialogRoute<void>(
        context: navCtx,
        barrierDismissible: true,
        builder: (_) => PlatformAlertDialog(
          title: PlatformText("Permissions Required"),
          content: PlatformText(
            "This app requires Bluetooth and Location permissions to function properly.\n"
            "Location access is needed for Bluetooth scanning to work. Please enable both "
            "Bluetooth and Location services and grant the necessary permissions.\n"
            "No data will be collected or sent to any server and will remain only on your device.",
          ),
          actions: [
            PlatformDialogAction(
              onPressed: nav.pop,
              child: PlatformText("OK"),
            ),
          ],
        ),
      ),
    );
  }
}
