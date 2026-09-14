import 'package:open_earable_flutter/open_earable_flutter.dart';
import 'package:open_wearable/models/device_name_formatter.dart';

/// Describes one runtime capability an app needs from a wearable.
class WearableCapabilityRequirement {
  /// Human-readable capability name shown when a wearable is missing it.
  final String label;

  final bool Function(Wearable wearable) _isSatisfiedBy;

  /// Creates a requirement backed by a wearable capability predicate.
  const WearableCapabilityRequirement({
    required this.label,
    required bool Function(Wearable wearable) isSatisfiedBy,
  }) : _isSatisfiedBy = isSatisfiedBy;

  /// Creates a requirement for a capability registered on [Wearable].
  static WearableCapabilityRequirement capability<T>({
    required String label,
  }) {
    return WearableCapabilityRequirement(
      label: label,
      isSatisfiedBy: (wearable) => wearable.hasCapability<T>(),
    );
  }

  /// Returns whether [wearable] satisfies this app requirement.
  bool isSatisfiedBy(Wearable wearable) => _isSatisfiedBy(wearable);
}

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

/// Returns true when [wearable] matches an app's supported device families.
bool wearableMatchesSupportedDevicePrefixes({
  required Wearable wearable,
  required List<String> supportedDevicePrefixes,
}) {
  return wearableIsCompatibleWithApp(
    wearableName: wearable.name,
    supportedDevicePrefixes: supportedDevicePrefixes,
  );
}

/// Returns capability requirements from [requirements] missing on [wearable].
List<WearableCapabilityRequirement> missingWearableCapabilityRequirements({
  required Wearable wearable,
  required List<WearableCapabilityRequirement> requirements,
}) {
  return requirements
      .where((requirement) => !requirement.isSatisfiedBy(wearable))
      .toList(growable: false);
}

/// Returns true when [wearable] matches the app family and runtime capabilities.
bool wearableSatisfiesAppRequirements({
  required Wearable wearable,
  required List<String> supportedDevicePrefixes,
  required List<WearableCapabilityRequirement> requiredCapabilities,
}) {
  return wearableMatchesSupportedDevicePrefixes(
        wearable: wearable,
        supportedDevicePrefixes: supportedDevicePrefixes,
      ) &&
      missingWearableCapabilityRequirements(
        wearable: wearable,
        requirements: requiredCapabilities,
      ).isEmpty;
}

bool hasConnectedWearableForPrefix({
  required String devicePrefix,
  required Iterable<String> connectedWearableNames,
}) {
  return connectedWearableNames.any(
    (name) => wearableNameStartsWithPrefix(name, devicePrefix),
  );
}
