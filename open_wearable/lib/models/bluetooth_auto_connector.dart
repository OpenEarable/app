import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart' hide logger;
import 'package:shared_preferences/shared_preferences.dart';

import 'auto_connect_preferences.dart';
import 'logger.dart';

/// Background reconnect orchestrator for remembered Bluetooth wearables.
///
/// Needs:
/// - `WearableManager` scanning/connection APIs.
/// - `AutoConnectPreferences` values and change stream.
/// - Navigation access for permission dialogs.
///
/// Does:
/// - Tracks target wearable names from preferences.
/// - Scans and connects matching devices with retry logic.
/// - Maintains per-session connection bookkeeping and disconnect recovery.
///
/// Provides:
/// - `start()` / `stop()` lifecycle control and `onWearableConnected` callback.
class BluetoothAutoConnector {
  static const Duration _scanRetryInterval = Duration(seconds: 3);

  final NavigatorState? Function() navStateGetter;
  final WearableManager wearableManager;
  final Future<SharedPreferences> prefsFuture;
  final void Function(Wearable wearable) onWearableConnected;

  StreamSubscription<Wearable>? _connectSubscription;
  StreamSubscription<DiscoveredDevice>? _scanSubscription;
  StreamSubscription<void>? _preferencesSubscription;
  Timer? _scanRetryTimer;

  bool _isConnecting = false;
  bool _isAttemptingConnection = false;
  bool _askedPermissionsThisSession = false;
  int _sessionToken = 0;

  // Names to look for during scanning
  List<String> _targetNames = [];
  Map<String, int> _targetNameCounts = const <String, int>{};
  final Set<String> _connectedDeviceIds = <String>{};
  final Map<String, int> _connectedNameCounts = <String, int>{};
  final Set<String> _pendingDeviceIds = <String>{};

  BluetoothAutoConnector({
    required this.navStateGetter,
    required this.wearableManager,
    required this.prefsFuture,
    required this.onWearableConnected,
  });

  void start() async {
    final token = ++_sessionToken;
    _stopInternal();
    _connectedDeviceIds.clear();
    _connectedNameCounts.clear();
    _pendingDeviceIds.clear();

    // Load the last connected names
    await _reloadTargetNames(token: token, reloadPrefs: false);
    if (token != _sessionToken) {
      return;
    }

    // Start listening for successful connections (to save names and set disconnect logic)
    _connectSubscription =
        wearableManager.connectStream.listen(_onDeviceConnected);
    _preferencesSubscription = AutoConnectPreferences.changes.listen((_) {
      unawaited(_syncTargetsWithPreferences(token: token, restartScan: true));
    });
    _ensureScanRetryLoop(token: token);

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
    _preferencesSubscription?.cancel();
    _preferencesSubscription = null;
    _isAttemptingConnection = false;
    _isConnecting = false;
    _pendingDeviceIds.clear();
    _scanRetryTimer?.cancel();
    _scanRetryTimer = null;
    _stopScanning();
  }

  String _normalizeDeviceId(String id) => id.trim().toUpperCase();

  Map<String, int> _buildNameCounts(List<String> names) {
    final counts = <String, int>{};
    for (final name in names) {
      counts[name] = (counts[name] ?? 0) + 1;
    }
    return counts;
  }

  int _requiredConnectionsForName(String name) => _targetNameCounts[name] ?? 0;

  void _markConnected({
    required String deviceId,
    required String deviceName,
  }) {
    final normalizedId = _normalizeDeviceId(deviceId);
    final inserted = _connectedDeviceIds.add(normalizedId);
    if (!inserted) {
      return;
    }
    _connectedNameCounts[deviceName] =
        (_connectedNameCounts[deviceName] ?? 0) + 1;
  }

  void _markDisconnected({
    required String deviceId,
    required String deviceName,
  }) {
    final normalizedId = _normalizeDeviceId(deviceId);
    final removed = _connectedDeviceIds.remove(normalizedId);
    if (!removed) {
      return;
    }
    final current = _connectedNameCounts[deviceName];
    if (current == null) {
      return;
    }
    if (current <= 1) {
      _connectedNameCounts.remove(deviceName);
      return;
    }
    _connectedNameCounts[deviceName] = current - 1;
  }

  bool _hasUnconnectedTargets() {
    if (_targetNameCounts.isEmpty) {
      return false;
    }
    return _targetNameCounts.entries.any((entry) {
      return (_connectedNameCounts[entry.key] ?? 0) < entry.value;
    });
  }

  String _deviceErrorMessageSafe(Object error, DiscoveredDevice device) {
    try {
      return wearableManager.deviceErrorMessage(error, device.name);
    } catch (_) {
      final fallback = error.toString().trim();
      if (fallback.isEmpty) {
        return 'Unknown connection error.';
      }
      return fallback;
    }
  }

  bool _isAlreadyConnectedMessage(String message) =>
      message.toLowerCase().contains('already connected');

  Future<void> _reloadTargetNames({
    required int token,
    bool reloadPrefs = true,
  }) async {
    final prefs = await prefsFuture;
    if (token != _sessionToken) {
      return;
    }
    if (reloadPrefs) {
      await prefs.reload();
      if (token != _sessionToken) {
        return;
      }
    }
    _targetNames = AutoConnectPreferences.readRememberedDeviceNames(prefs);
    _targetNameCounts = _buildNameCounts(_targetNames);
  }

  Future<void> _syncTargetsWithPreferences({
    required int token,
    bool restartScan = false,
  }) async {
    await _reloadTargetNames(token: token);
    if (token != _sessionToken) {
      return;
    }

    if (_targetNames.isEmpty || !_hasUnconnectedTargets()) {
      _stopScanning();
      return;
    }

    if (restartScan) {
      await _restartScanIfNeeded();
    }
  }

  void _ensureScanRetryLoop({required int token}) {
    _scanRetryTimer?.cancel();
    _scanRetryTimer = Timer.periodic(_scanRetryInterval, (timer) {
      if (token != _sessionToken) {
        timer.cancel();
        return;
      }
      if (_isAttemptingConnection || _isConnecting) {
        return;
      }
      unawaited(_syncTargetsWithPreferences(token: token, restartScan: true));
    });
  }

  /// Called when the WearableManager successfully connects to a device.
  void _onDeviceConnected(Wearable wearable) async {
    final token = _sessionToken;
    _markConnected(deviceId: wearable.deviceId, deviceName: wearable.name);

    final prefs = await prefsFuture;
    if (token != _sessionToken) {
      return;
    }
    final rememberedCount = AutoConnectPreferences.countRememberedDeviceName(
      prefs,
      wearable.name,
    );
    final connectedCount = _connectedNameCounts[wearable.name] ?? 0;
    if (connectedCount > rememberedCount) {
      await AutoConnectPreferences.rememberDeviceName(prefs, wearable.name);
    }

    // Stop scanning immediately when a successful connection is made
    _stopScanning();

    // Set up the disconnect listener to trigger a scan for the saved name.
    wearable.addDisconnectListener(() async {
      if (token != _sessionToken) {
        return;
      }
      logger.i(
        "Device ${wearable.name} disconnected. Initiating reconnection scan.",
      );
      _markDisconnected(deviceId: wearable.deviceId, deviceName: wearable.name);

      await _syncTargetsWithPreferences(token: token);

      if (_hasUnconnectedTargets()) {
        _attemptConnection();
      }
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
      await _syncTargetsWithPreferences(token: activeToken);
      if (activeToken != _sessionToken) {
        return;
      }

      if (_targetNames.isNotEmpty && _hasUnconnectedTargets()) {
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
      if (_isConnecting) return;

      final normalizedId = _normalizeDeviceId(device.id);
      if (_pendingDeviceIds.contains(normalizedId) ||
          _connectedDeviceIds.contains(normalizedId)) {
        return;
      }
      final requiredConnections = _requiredConnectionsForName(device.name);
      if (requiredConnections == 0) {
        return;
      }
      if ((_connectedNameCounts[device.name] ?? 0) >= requiredConnections) {
        return;
      }

      _isConnecting = true;
      _pendingDeviceIds.add(normalizedId);
      _stopScanning();

      logger.i(
        "Match found for ${device.name}. Connecting using rotating ID: ${device.id}",
      );

      wearableManager.connectToDevice(device).then((wearable) {
        _markConnected(
          deviceId: wearable.deviceId,
          deviceName: wearable.name,
        );
        onWearableConnected(wearable);
      }).catchError((error, stackTrace) {
        final message = _deviceErrorMessageSafe(error, device);
        if (_isAlreadyConnectedMessage(message)) {
          _markConnected(deviceId: device.id, deviceName: device.name);
          logger.i(
            'Skipping auto-connect for ${device.id}: $message',
          );
          return;
        }
        logger.w(
          'Failed to connect to ${device.id}: $message\n$stackTrace',
        );
      }).whenComplete(() {
        _pendingDeviceIds.remove(normalizedId);
        _isConnecting = false;
        unawaited(_restartScanIfNeeded());
      });
    });
  }

  Future<void> _restartScanIfNeeded() async {
    if (_isConnecting || _isAttemptingConnection) {
      return;
    }
    if (_scanSubscription != null) {
      return;
    }
    if (!_hasUnconnectedTargets()) {
      return;
    }
    try {
      _setupScanListener();
      await wearableManager.startScan();
    } catch (error, stackTrace) {
      logger.w('Failed to restart auto-connect scan: $error\n$stackTrace');
      _stopScanning();
    }
  }

  void _stopScanning() {
    _scanSubscription?.cancel();
    _scanSubscription = null;
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
