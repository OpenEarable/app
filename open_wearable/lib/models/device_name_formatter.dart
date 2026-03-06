/// Normalizes wearable names for UI display.
///
/// Converts legacy `bcl...` prefixes into `OpenRing-...` and keeps all other
/// names unchanged.
String formatWearableDisplayName(String rawName) {
  final trimmed = rawName.trim();
  if (trimmed.isEmpty) {
    return trimmed;
  }

  final replaced = trimmed.replaceFirst(
    RegExp(r'^bcl[-_\s]*', caseSensitive: false),
    'OpenRing-',
  );

  if (replaced == 'OpenRing-') {
    return 'OpenRing';
  }

  return replaced;
}

/// Returns a normalized display name or `null` when the input is empty.
String? formatWearableDisplayNameOrNull(String? rawName) {
  final trimmed = rawName?.trim();
  if (trimmed == null || trimmed.isEmpty) {
    return null;
  }

  return formatWearableDisplayName(trimmed);
}
