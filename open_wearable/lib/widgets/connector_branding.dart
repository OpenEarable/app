import 'package:flutter/material.dart';

/// Shared visual identity for connector entry points and status surfaces.
class ConnectorBranding {
  const ConnectorBranding._();

  /// Primary connector icon used wherever connector features are represented.
  static const IconData icon = Icons.hub_rounded;

  /// User-facing connector family label.
  static const String label = 'Connector';

  /// User-facing plural connector family label.
  static const String pluralLabel = 'Connectors';
}
