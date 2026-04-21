import 'package:open_earable_flutter/open_earable_flutter.dart' hide logger;
import 'package:open_wearable/models/logger.dart';
import 'package:open_wearable/models/wearable_connector.dart';

/// Base lifecycle contract for background connection orchestrators.
abstract class AutoConnector {
  /// Shared wearable connection facade used by subclasses.
  final WearableConnector _connector;

  AutoConnector(WearableConnector connector) : _connector = connector;

  /// Broadcast connection lifecycle events emitted by the shared connector.
  Stream<WearableEvent> get events => _connector.events;

  /// Starts the connector lifecycle.
  void start();

  /// Stops the connector lifecycle.
  void stop();

  /// Returns whether the provided device id is already paired at the OS level.
  Future<bool> isSystemDeviceId(String deviceId) {
    return _connector.isSystemDeviceId(deviceId);
  }

  Future<Wearable> connect(DiscoveredDevice device) {
    // log which auto-connector is connecting to which device
    logger.i(
      'AutoConnector $runtimeType connecting to device ${device.name} (${device.id})',
    );
    return _connector.connect(device);
  }
}
