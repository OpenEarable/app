import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart' hide logger;
import 'package:shared_preferences/shared_preferences.dart'; // New dependency for persistence

import 'logger.dart';
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
  StreamSubscription<BluetoothAvailabilityState>? _availabilitySubscription;

  bool _isConnecting = false;
  bool _isAttemptingConnection = false;
  bool _askedPermissionsThisSession = false;
  BluetoothAvailabilityState _availabilityState =
      BluetoothAvailabilityState.unknown;
  int _sessionToken = 0;

  // Names to look for during scanning
  List<String> _targetNames = [];

  BluetoothAutoConnector({
    required this.navStateGetter,
    required this.wearableManager,
    required this.connector,
    required this.prefsFuture,
    required this.onWearableConnected,
  });

  bool get _isBluetoothReady =>
      _availabilityState == BluetoothAvailabilityState.poweredOn;

  void start() async {
    final token = ++_sessionToken;
    _stopInternal();

    // Load the last connected names
    final prefs = await prefsFuture;
    if (token != _sessionToken) {
      return;
    }
    _targetNames = prefs.getStringList(_connectedDeviceNamesKey) ?? [];

    // Start listening for successful connections (to save names and set disconnect logic)
    _connectSubscription =
        wearableManager.connectStream.listen(_onDeviceConnected);

    _availabilitySubscription =
        wearableManager.bluetoothAvailabilityStream.listen(
      _handleAvailabilityChanged,
      onError: (Object error, StackTrace stackTrace) {
        logger.w('Bluetooth availability stream error: $error\n$stackTrace');
      },
    );

    try {
      _availabilityState =
          await wearableManager.getBluetoothAvailabilityState();
    } catch (error, stackTrace) {
      logger.w('Failed to read Bluetooth availability: $error\n$stackTrace');
    }
    if (token != _sessionToken) {
      return;
    }

    // Initiate the connection sequence
    _attemptConnection(token: token);
  }

  void stop() {
    _sessionToken++;
    _stopInternal();
  }

  void _stopInternal() {
    _connectSubscription?.cancel();
    _connectSubscription = null;
    _availabilitySubscription?.cancel();
    _availabilitySubscription = null;
    _isAttemptingConnection = false;
    _isConnecting = false;
    _stopScanning();
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
    _stopScanning();

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

  Future<void> _attemptConnection({int? token}) async {
    final activeToken = token ?? _sessionToken;
    if (activeToken != _sessionToken) {
      return;
    }
    if (_isAttemptingConnection) {
      return;
    }
    if (!_isBluetoothReady) {
      logger.w('Skipping auto-connect: Bluetooth is not ready.');
      return;
    }

    _isAttemptingConnection = true;
    if (!Platform.isIOS) {
      final hasPerm = await wearableManager.hasPermissions();
      if (activeToken != _sessionToken) {
        _isAttemptingConnection = false;
        return;
      }
      if (!hasPerm) {
        if (!_askedPermissionsThisSession) {
          _askedPermissionsThisSession = true;
          _showPermissionsDialog();
        }
        logger.w('Skipping auto-connect: no permissions granted yet.');
        _isAttemptingConnection = false;
        return;
      }
    }

    try {
      await connector.connectToSystemDevices();
      if (activeToken != _sessionToken) {
        return;
      }

      if (_targetNames.isNotEmpty && _isBluetoothReady) {
        _setupScanListener();
        await wearableManager.startScan();
      }
    } catch (error, stackTrace) {
      logger.w('Auto-connect attempt failed: $error\n$stackTrace');
    } finally {
      _isAttemptingConnection = false;
    }
  }

  void _setupScanListener() {
    if (_scanSubscription != null) return;

    _scanSubscription = wearableManager.scanStream.listen((device) {
      if (!_isBluetoothReady) return;
      if (_isConnecting) return;

      if (_targetNames.contains(device.name)) {
        _isConnecting = true;
        _stopScanning();

        logger.i(
          "Match found for ${device.name}. Connecting using rotating ID: ${device.id}",
        );

        wearableManager
            .connectToDevice(device)
            .then(onWearableConnected)
            .catchError((e) {
          logger.e(
            "Failed to connect to ${device.id}: ${wearableManager.deviceErrorMessage(e, device.name)}",
          );
        }).whenComplete(() {
          _isConnecting = false;
        });
      }
    });
  }

  void _handleAvailabilityChanged(BluetoothAvailabilityState state) {
    final previous = _availabilityState;
    _availabilityState = state;

    if (!_isBluetoothReady) {
      if (previous == BluetoothAvailabilityState.poweredOn) {
        _sessionToken++;
      }
      _isAttemptingConnection = false;
      _isConnecting = false;
      _stopScanning();
      return;
    }

    if (previous != BluetoothAvailabilityState.poweredOn && _isBluetoothReady) {
      _attemptConnection();
    }
  }

  void _stopScanning() {
    _scanSubscription?.cancel();
    _scanSubscription = null;
    unawaited(wearableManager.stopScan());
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
