bool wearableNameStartsWithPrefix(String wearableName, String prefix) {
  final normalizedWearableName = wearableName.trim().toLowerCase();
  final normalizedPrefix = prefix.trim().toLowerCase();
  if (normalizedWearableName.isEmpty || normalizedPrefix.isEmpty) return false;
  return normalizedWearableName.startsWith(normalizedPrefix);
}

bool wearableIsCompatibleWithApp({
  required String wearableName,
  required List<String> supportedDevicePrefixes,
}) {
  if (supportedDevicePrefixes.isEmpty) return true;
  return supportedDevicePrefixes.any(
    (prefix) => wearableNameStartsWithPrefix(wearableName, prefix),
  );
}

bool hasConnectedWearableForPrefix({
  required String devicePrefix,
  required Iterable<String> connectedWearableNames,
}) {
  return connectedWearableNames.any(
    (name) => wearableNameStartsWithPrefix(name, devicePrefix),
  );
}
