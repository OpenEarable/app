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

String? formatWearableDisplayNameOrNull(String? rawName) {
  final trimmed = rawName?.trim();
  if (trimmed == null || trimmed.isEmpty) {
    return null;
  }

  return formatWearableDisplayName(trimmed);
}
