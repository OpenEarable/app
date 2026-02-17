import 'package:open_wearable/models/device_name_formatter.dart';

bool wearableNameStartsWithPrefix(String wearableName, String prefix) {
  final normalizedPrefix = prefix.trim().toLowerCase();
  final normalizedWearableName = wearableName.trim().toLowerCase();
  if (normalizedWearableName.isEmpty || normalizedPrefix.isEmpty) {
    return false;
  }

  if (normalizedWearableName.startsWith(normalizedPrefix)) {
    return true;
  }

  final formattedWearableName =
      formatWearableDisplayName(wearableName).trim().toLowerCase();
  if (formattedWearableName.isEmpty) {
    return false;
  }

  return formattedWearableName.startsWith(normalizedPrefix);
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
