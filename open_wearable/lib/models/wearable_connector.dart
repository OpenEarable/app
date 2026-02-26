import 'dart:async';

import 'package:open_earable_flutter/open_earable_flutter.dart';

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

  final _events = StreamController<WearableEvent>.broadcast();
  Stream<WearableEvent> get events => _events.stream;

  WearableConnector([WearableManager? wm]) : _wm = wm ?? WearableManager();

  Future<Wearable> connect(DiscoveredDevice device) async {
    final wearable = await _wm.connectToDevice(device);
    _handleConnection(wearable);
    return wearable;
  }

  Future<void> connectToSystemDevices() async {
    List<Wearable> connectedWearables = await _wm.connectToSystemDevices();
    connectedWearables.forEach(_handleConnection);
  }

  void _handleConnection(Wearable wearable) {
    //_connectedDevices[device] = wearable;
    wearable.addDisconnectListener(() {
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
