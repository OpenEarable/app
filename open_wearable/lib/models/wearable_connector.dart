import 'dart:async';

import 'package:open_earable_flutter/open_earable_flutter.dart';

import 'permissions_handler.dart';

/// Base event type emitted by [WearableConnector].
abstract class WearableEvent {
  final Wearable wearable;
  WearableEvent(this.wearable);
}

/// Base class for wearable connection lifecycle events.
abstract class WearableConnectionEvent extends WearableEvent {
  // final DiscoveredDevice discoveredDevice;
  WearableConnectionEvent(/*this.discoveredDevice, */ super.wearable);
}

/// Emitted when a wearable connection is established.
final class WearableConnectEvent extends WearableConnectionEvent {
  WearableConnectEvent(/*super.discoveredDevice, */ super.wearable);
}

/// Disconnection reason used by [WearableDisconnectedEvent].
enum DisconnectReason { user, system }

/// Emitted when an already connected wearable disconnects.
final class WearableDisconnectedEvent extends WearableConnectionEvent {
  final DisconnectReason disconnectReason;
  WearableDisconnectedEvent(
    this.disconnectReason,
    /*super.discoveredDevice, */ super.wearable,
  );
}

/// Emitted when two wearable sides are paired.
final class WearableStereoPairedEvent extends WearableEvent {
  final Wearable partner;
  WearableStereoPairedEvent(this.partner, super.wearable);
}

/// Connection facade around `WearableManager` with a broadcast event stream.
///
/// Needs:
/// - A configured `WearableManager` (default or injected).
///
/// Does:
/// - Connects discovered/system devices.
/// - Emits connection/disconnection events.
///
/// Provides:
/// - A single stream (`events`) consumed by app-level orchestration.
class WearableConnector {
  // final Map<DiscoveredDevice, Wearable> _connectedDevices = {};

  final WearableManager _wm;
  final PermissionsHandler _permissionsHandler;
  final Set<String> _trackedWearableIds = <String>{};

  final _events = StreamController<WearableEvent>.broadcast();
  Stream<WearableEvent> get events => _events.stream;

  WearableConnector({
    WearableManager? wearableManager,
    required PermissionsHandler permissionsHandler,
  }) : _wm = wearableManager ?? WearableManager(),
       _permissionsHandler = permissionsHandler;

  /// Normalizes a device id for stable set membership and comparisons.
  String _normalizeDeviceId(String deviceId) => deviceId.trim().toUpperCase();

  Future<Wearable> connect(DiscoveredDevice device) async {
    final wearable = await _wm.connectToDevice(device);
    _handleConnection(wearable);
    return wearable;
  }

  /// Returns the normalized ids of devices currently paired at the OS level.
  Future<Set<String>> getSystemDeviceIds({
    bool checkAndRequestPermissions = false,
  }) async {
    final systemDevices = await _wm.getSystemDevices(
      checkAndRequestPermissions: checkAndRequestPermissions,
    );
    return systemDevices
        .map((device) => _normalizeDeviceId(device.id))
        .toSet();
  }

  /// Returns whether the provided discovered device is already OS-paired.
  Future<bool> isSystemDevice(
    DiscoveredDevice device, {
    bool checkAndRequestPermissions = false,
  }) {
    return isSystemDeviceId(
      device.id,
      checkAndRequestPermissions: checkAndRequestPermissions,
    );
  }

  /// Returns whether the provided device id is already OS-paired.
  Future<bool> isSystemDeviceId(
    String deviceId, {
    bool checkAndRequestPermissions = false,
  }) async {
    final normalizedId = _normalizeDeviceId(deviceId);
    final systemDeviceIds = await getSystemDeviceIds(
      checkAndRequestPermissions: checkAndRequestPermissions,
    );
    return systemDeviceIds.contains(normalizedId);
  }

  /// Connects all currently available system devices and reports whether the
  /// provided device id was among the connected system wearables.
  ///
  /// The underlying library exposes system-device connection as a bulk action,
  /// so this helper keeps the "connect a paired device through the system path"
  /// behavior centralized in this facade.
  Future<bool> connectSystemDevice(DiscoveredDevice device) async {
    final permissionsGranted =
        await _permissionsHandler.ensureBluetoothPermissions();
    if (!permissionsGranted) {
      return false;
    }

    final normalizedId = _normalizeDeviceId(device.id);
    final connectedWearables = await _wm.connectToSystemDevices();
    var connectedRequestedDevice = false;
    for (final wearable in connectedWearables) {
      if (_normalizeDeviceId(wearable.deviceId) == normalizedId) {
        connectedRequestedDevice = true;
      }
      _handleConnection(wearable);
    }
    return connectedRequestedDevice;
  }

  /// Connects to already paired system devices after permissions are ensured.
  Future<void> connectToSystemDevices() async {
    final permissionsGranted =
        await _permissionsHandler.ensureBluetoothPermissions();
    if (!permissionsGranted) {
      return;
    }

    List<Wearable> connectedWearables = await _wm.connectToSystemDevices();
    connectedWearables.forEach(_handleConnection);
  }

  /// Clears local connection bookkeeping.
  ///
  /// Useful when the platform Bluetooth adapter is powered off and the
  /// platform stack does not emit per-device disconnect callbacks.
  void clearTrackedConnections({Iterable<String>? deviceIds}) {
    if (deviceIds == null) {
      _trackedWearableIds.clear();
      return;
    }
    for (final id in deviceIds) {
      _trackedWearableIds.remove(id);
    }
  }

  void _handleConnection(Wearable wearable) {
    if (_trackedWearableIds.contains(wearable.deviceId)) {
      return;
    }
    _trackedWearableIds.add(wearable.deviceId);

    //_connectedDevices[device] = wearable;
    wearable.addDisconnectListener(() {
      _trackedWearableIds.remove(wearable.deviceId);
      _events.add(
        WearableDisconnectedEvent(
          DisconnectReason.system,
          /* device, */ wearable,
        ),
      );
      //_connectedDevices.remove(device);
    });
    _events.add(WearableConnectEvent(/*device, */ wearable));
  }
}
