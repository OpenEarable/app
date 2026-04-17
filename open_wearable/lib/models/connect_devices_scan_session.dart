import 'dart:async';

import 'package:flutter/material.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart' hide logger;

import 'logger.dart';
import 'permissions_handler.dart';

/// Immutable scan state consumed by the connect-devices UI.
class ConnectDevicesScanSnapshot {
  final bool isScanning;
  final DateTime? lastScanStartedAt;
  final List<DiscoveredDevice> discoveredDevices;

  const ConnectDevicesScanSnapshot({
    required this.isScanning,
    required this.lastScanStartedAt,
    required this.discoveredDevices,
  });

  factory ConnectDevicesScanSnapshot.initial() =>
      const ConnectDevicesScanSnapshot(
        isScanning: false,
        lastScanStartedAt: null,
        discoveredDevices: <DiscoveredDevice>[],
      );

  ConnectDevicesScanSnapshot copyWith({
    bool? isScanning,
    DateTime? lastScanStartedAt,
    List<DiscoveredDevice>? discoveredDevices,
  }) {
    return ConnectDevicesScanSnapshot(
      isScanning: isScanning ?? this.isScanning,
      lastScanStartedAt: lastScanStartedAt ?? this.lastScanStartedAt,
      discoveredDevices: discoveredDevices ?? this.discoveredDevices,
    );
  }
}

/// Shared scan coordinator for the connect-devices flow.
///
/// The session owns the discovery scan lifecycle and ensures permissions are
/// granted before any BLE scan begins.
class ConnectDevicesScanSession {
  static const Duration _scanIndicatorDuration = Duration(seconds: 8);

  static final WearableManager _wearableManager = WearableManager();
  static PermissionsHandler? _permissionsHandler;
  static final ValueNotifier<ConnectDevicesScanSnapshot> notifier =
      ValueNotifier<ConnectDevicesScanSnapshot>(
    ConnectDevicesScanSnapshot.initial(),
  );

  // ignore: cancel_subscriptions
  static StreamSubscription<DiscoveredDevice>? _scanSubscription;
  static Timer? _scanIndicatorTimer;
  static int _scanToken = 0;

  static ConnectDevicesScanSnapshot get snapshot => notifier.value;

  /// Injects the shared permissions handler used by the scan session.
  static void configure({required PermissionsHandler permissionsHandler}) {
    _permissionsHandler = permissionsHandler;
  }

  /// Starts a BLE discovery scan after ensuring runtime permissions exist.
  static Future<void> startScanning({bool clearPrevious = false}) async {
    final permissionsHandler = _permissionsHandler;
    if (permissionsHandler == null) {
      throw StateError(
        'ConnectDevicesScanSession.configure must be called before scanning.',
      );
    }

    final scanToken = ++_scanToken;
    await _cancelScanResources();

    final currentSnapshot = snapshot;
    final updatedDevices = clearPrevious
        ? <DiscoveredDevice>[]
        : currentSnapshot.discoveredDevices;
    _emit(
      currentSnapshot.copyWith(
        isScanning: true,
        lastScanStartedAt: DateTime.now(),
        discoveredDevices: List<DiscoveredDevice>.unmodifiable(updatedDevices),
      ),
    );

    _scanSubscription = _wearableManager.scanStream.listen(
      (incomingDevice) {
        if (scanToken != _scanToken) {
          return;
        }
        if (incomingDevice.name.isEmpty) {
          return;
        }

        final devices = snapshot.discoveredDevices;
        if (devices.any((device) => device.id == incomingDevice.id)) {
          return;
        }

        logger.d('Discovered device: ${incomingDevice.name}');
        _emit(
          snapshot.copyWith(
            discoveredDevices: List<DiscoveredDevice>.unmodifiable([
              ...devices,
              incomingDevice,
            ]),
          ),
        );
      },
      onError: (error, stackTrace) {
        logger.w('Device scan stream error: $error\n$stackTrace');
        unawaited(stopScanning());
      },
    );

    try {
      if (scanToken != _scanToken) {
        return;
      }
      final permissionsGranted =
          await permissionsHandler.ensureBluetoothPermissions();
      if (!permissionsGranted || scanToken != _scanToken) {
        await stopScanning();
        return;
      }

      await _wearableManager.startScan(checkAndRequestPermissions: false);
    } catch (error, stackTrace) {
      logger.w('Failed to start scan: $error\n$stackTrace');
      await stopScanning();
      return;
    }

    if (scanToken != _scanToken) {
      await _cancelScanResources();
      return;
    }

    _scanIndicatorTimer = Timer(_scanIndicatorDuration, () {
      if (scanToken != _scanToken) {
        return;
      }
      unawaited(stopScanning());
    });
  }

  static Future<void> stopScanning({bool clearDiscovered = false}) async {
    _scanToken++;
    await _cancelScanResources();

    final currentSnapshot = snapshot;
    final updatedDevices = clearDiscovered
        ? const <DiscoveredDevice>[]
        : currentSnapshot.discoveredDevices;
    _emit(
      currentSnapshot.copyWith(
        isScanning: false,
        discoveredDevices: List<DiscoveredDevice>.unmodifiable(updatedDevices),
      ),
    );
  }

  static void removeDiscoveredDevice(String deviceId) {
    final devices = snapshot.discoveredDevices;
    if (!devices.any((device) => device.id == deviceId)) {
      return;
    }

    _emit(
      snapshot.copyWith(
        discoveredDevices: List<DiscoveredDevice>.unmodifiable(
          devices.where((device) => device.id != deviceId),
        ),
      ),
    );
  }

  static Future<void> _cancelScanResources() async {
    _scanIndicatorTimer?.cancel();
    _scanIndicatorTimer = null;

    final currentSubscription = _scanSubscription;
    _scanSubscription = null;
    await currentSubscription?.cancel();
  }

  static void _emit(ConnectDevicesScanSnapshot next) {
    notifier.value = next;
  }
}
