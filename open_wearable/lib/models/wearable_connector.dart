import 'dart:async';

import 'package:open_earable_flutter/open_earable_flutter.dart';

abstract class WearableEvent {
  final Wearable wearable;
  WearableEvent(this.wearable);
}

abstract class WearableConnectionEvent extends WearableEvent {
  // final DiscoveredDevice discoveredDevice;
  WearableConnectionEvent(/*this.discoveredDevice, */super.wearable);
}
final class WearableConnectEvent extends WearableConnectionEvent {
  WearableConnectEvent(/*super.discoveredDevice, */super.wearable);
}

enum DisconnectReason {
  user, system
}
final class WearableDisconnectedEvent extends WearableConnectionEvent {
  final DisconnectReason disconnectReason;
  WearableDisconnectedEvent(this.disconnectReason, /*super.discoveredDevice, */super.wearable);
}

final class WearableStereoPairedEvent extends WearableEvent {
  final Wearable partner;
  WearableStereoPairedEvent(this.partner, super.wearable);
}


/// This class handles all connections with wearables and notifies subscribers over Wearable events
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
      _events.add(WearableDisconnectedEvent(DisconnectReason.system,/* device, */wearable));
      //_connectedDevices.remove(device);
    });
    _events.add(WearableConnectEvent(/*device, */wearable));
  }
}
