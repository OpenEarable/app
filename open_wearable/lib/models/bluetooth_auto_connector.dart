import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart'; // New dependency for persistence

import 'wearable_connector.dart';

const String _connectedDeviceNamesKey = "connectedDeviceNames";

class BluetoothAutoConnector {
  final NavigatorState? Function() navStateGetter;
  final WearableManager wearableManager;
  final WearableConnector connector;
  final Future<SharedPreferences> prefsFuture;
  final void Function(Wearable wearable) onWearableConnected;

  StreamSubscription<Wearable>? _connectSubscription;
  StreamSubscription<DiscoveredDevice>? _scanSubscription;

  bool _isConnecting = false;
  bool _askedPermissionsThisSession = false;

  // Names to look for during scanning
  List<String> _targetNames = [];

  BluetoothAutoConnector(
      {required this.navStateGetter,
      required this.wearableManager,
      required this.connector,
      required this.prefsFuture,
      required this.onWearableConnected});

  void start() async {
    stop();

    // Load the last connected names
    final prefs = await prefsFuture;
    _targetNames = prefs.getStringList(_connectedDeviceNamesKey) ?? [];

    // Start listening for successful connections (to save names and set disconnect logic)
    _connectSubscription =
        wearableManager.connectStream.listen(_onDeviceConnected);

    // Initiate the connection sequence
    _attemptConnection();
  }

  void stop() {
    _connectSubscription?.cancel();
    _connectSubscription = null;
    _scanSubscription?.cancel();
    _scanSubscription = null;
    // Stop any ongoing scan initiated by this class
    // Use the public WearableManager function to stop the scan
    wearableManager.setAutoConnect([]);

    // Cancel the local listener to prevent further triggers
    _scanSubscription?.cancel();
    _scanSubscription = null;
  }

  /// Called when the WearableManager successfully connects to a device.
  void _onDeviceConnected(Wearable wearable) async {
    final prefs = await prefsFuture;

    List<String> deviceNames =
        prefs.getStringList(_connectedDeviceNamesKey) ?? [];
    if (!deviceNames.contains(wearable.name)) {
      deviceNames.add(wearable.name);
      await prefs.setStringList(_connectedDeviceNamesKey, deviceNames);
    }

    // Stop scanning immediately when a successful connection is made
    if (_scanSubscription != null) {
      // stop scan
      wearableManager.setAutoConnect([]);

      _scanSubscription?.cancel();
      _scanSubscription = null;

      _scanSubscription?.cancel();
      _scanSubscription = null;
    }

    // Set up the disconnect listener to trigger a scan for the saved name.
    wearable.addDisconnectListener(() {
      logger.i(
        "Device ${wearable.name} disconnected. Initiating reconnection scan.",
      );

      prefs.reload();
      _targetNames = prefs.getStringList(_connectedDeviceNamesKey) ?? [];

      _attemptConnection();
    });
  }

  Future<void> _attemptConnection() async {
    if (!Platform.isIOS) {
      final hasPerm = await wearableManager.hasPermissions();
      if (!hasPerm) {
        if (!_askedPermissionsThisSession) {
          _askedPermissionsThisSession = true;
          _showPermissionsDialog();
        }
        logger.w('Skipping auto-connect: no permissions granted yet.');
        return;
      }
    }

    await connector.connectToSystemDevices();

    if (_targetNames.isNotEmpty) {
      _setupScanListener();
      await wearableManager.startScan(excludeUnsupported: true);
    }
  }

  void _setupScanListener() {
    if (_scanSubscription != null) return;

    _scanSubscription = wearableManager.scanStream.listen((device) {
      print("device.name: ${device.name}, targets: $_targetNames");
      if (_isConnecting) return;

      if (_targetNames.contains(device.name)) {
        _isConnecting = true;
        // stop scan
        wearableManager.setAutoConnect([]);
        _scanSubscription?.cancel();
        _scanSubscription = null;

        logger.i(
            "Match found for ${device.name}. Connecting using rotating ID: ${device.id}");

        wearableManager
            .connectToDevice(device)
            .then(onWearableConnected)
            .catchError((e) {
          logger.e("Failed to connect to ${device.name}: $e");
        }).whenComplete(() {
          _isConnecting = false;
        });
      }
    });
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
