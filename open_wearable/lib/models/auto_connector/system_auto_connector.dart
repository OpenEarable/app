import 'dart:async';

import 'package:open_earable_flutter/open_earable_flutter.dart' hide logger;

import '../logger.dart';
import '../permissions_handler.dart';
import '../wearable_connector.dart';
import 'auto_connector.dart';

/// Reconnects any devices that are already paired at the OS level.
///
/// Needs:
/// - The shared [WearableConnector] used by the rest of the app.
/// - A [WearableManager] to enumerate system-known Bluetooth devices.
/// - A [PermissionsHandler] to centralize runtime permission requests.
///
/// Does:
/// - Connects visible system devices without starting a BLE discovery scan.
/// - Retries after disconnects until paired devices are restored.
///
/// Provides:
/// - `start()` / `stop()` lifecycle hooks for app-level auto-connect orchestration.
class SystemAutoConnector extends AutoConnector {
  static const Duration _retryInterval = Duration(seconds: 4);

  final WearableManager wearableManager;
  final PermissionsHandler permissionsHandler;

  StreamSubscription<WearableEvent>? _eventsSubscription;
  Timer? _retryTimer;

  bool _isAttemptingConnections = false;
  int _sessionToken = 0;

  final Set<String> _connectedDeviceIds = <String>{};
  final Set<String> _pendingDeviceIds = <String>{};

  SystemAutoConnector({
    required WearableConnector connector,
    required this.wearableManager,
    required this.permissionsHandler,
  }) : super(connector);

  @override
  void start() async {
    final token = ++_sessionToken;
    _stopInternal();
    _connectedDeviceIds.clear();
    _pendingDeviceIds.clear();

    _eventsSubscription = events.listen(_handleConnectorEvent);
    _ensureRetryLoop(token: token);

    unawaited(_attemptConnections(token: token));
  }

  @override
  void stop() {
    _sessionToken++;
    _stopInternal();
  }

  void _stopInternal() {
    _eventsSubscription?.cancel();
    _eventsSubscription = null;
    _retryTimer?.cancel();
    _retryTimer = null;
    _isAttemptingConnections = false;
    _pendingDeviceIds.clear();
  }

  void _handleConnectorEvent(WearableEvent event) {
    if (event is WearableConnectEvent) {
      _markConnected(
        deviceId: event.wearable.deviceId,
      );
      return;
    }

    if (event is WearableDisconnectedEvent) {
      _markDisconnected(
        deviceId: event.wearable.deviceId,
      );
      unawaited(_attemptConnections());
    }
  }

  void _ensureRetryLoop({required int token}) {
    _retryTimer?.cancel();
    _retryTimer = Timer.periodic(_retryInterval, (timer) {
      if (token != _sessionToken) {
        timer.cancel();
        return;
      }
      if (_isAttemptingConnections) {
        return;
      }
      unawaited(_attemptConnections(token: token));
    });
  }

  Future<void> _attemptConnections({int? token}) async {
    final activeToken = token ?? _sessionToken;
    if (activeToken != _sessionToken || _isAttemptingConnections) {
      return;
    }

    _isAttemptingConnections = true;
    try {
      if (activeToken != _sessionToken) {
        return;
      }

      final permissionsGranted =
          await permissionsHandler.ensureBluetoothPermissions();
      if (!permissionsGranted || activeToken != _sessionToken) {
        return;
      }

      await connectToSystemDevices();
    } catch (error, stackTrace) {
      logger.w('System auto-connect attempt failed: $error\n$stackTrace');
    } finally {
      _isAttemptingConnections = false;
    }
  }

  Future<void> connectToSystemDevices() async {
    final systemDevices = await wearableManager.getSystemDevices(
      checkAndRequestPermissions: false,
    );
    if (_sessionToken == 0) {
      return;
    }

    for (final device in systemDevices) {
      if (!_shouldConnect(device)) {
        continue;
      }

      final normalizedId = _normalizeDeviceId(device.id);
      _pendingDeviceIds.add(normalizedId);
      try {
        await connect(device);
        _markConnected(deviceId: device.id);
      } catch (error, stackTrace) {
        final message = _deviceErrorMessageSafe(error, device);
        if (_isAlreadyConnectedMessage(message)) {
          _markConnected(deviceId: device.id);
        } else {
          logger.w(
            'Failed to connect system device ${device.id}: $message\n$stackTrace',
          );
        }
      } finally {
        _pendingDeviceIds.remove(normalizedId);
      }
    }
  }

  bool _shouldConnect(DiscoveredDevice device) {
    final normalizedId = _normalizeDeviceId(device.id);
    return !_connectedDeviceIds.contains(normalizedId) &&
        !_pendingDeviceIds.contains(normalizedId);
  }

  String _normalizeDeviceId(String id) => id.trim().toUpperCase();

  void _markConnected({
    required String deviceId,
  }) {
    final normalizedId = _normalizeDeviceId(deviceId);
    _connectedDeviceIds.add(normalizedId);
  }

  void _markDisconnected({
    required String deviceId,
  }) {
    final normalizedId = _normalizeDeviceId(deviceId);
    _connectedDeviceIds.remove(normalizedId);
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

  bool _isAlreadyConnectedMessage(String message) {
    return message.toLowerCase().contains('already connected');
  }
}
