import 'package:open_earable_flutter/open_earable_flutter.dart';
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

  Future<Wearable> connect(DiscoveredDevice device) {
    return _connector.connect(device);
  }
}
