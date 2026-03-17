import 'package:open_earable_flutter/open_earable_flutter.dart';
import 'package:open_wearable/apps/models/sensor_matching.dart';
import 'package:open_wearable/models/device_name_formatter.dart';

typedef WearablePredicate = bool Function(Wearable wearable);
typedef CapabilityPredicate<T> = bool Function(T capability, Wearable wearable);

/// Returns whether [wearableName] matches the given user-facing [prefix].
///
/// Matching checks both the raw device name and the formatted display name so
/// aliases such as OpenRing `bcl-*` names remain compatible with prefix-based
/// app rules.
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

/// A composable compatibility rule evaluated against a [Wearable].
///
/// Apps typically combine multiple requirements via [allOf] and [anyOf] and
/// then attach them to one or more [AppSupportOption] entries.
sealed class AppRequirement {
  const AppRequirement();

  /// Returns whether this requirement is satisfied by [wearable].
  bool matches(Wearable wearable);

  /// Matches every wearable.
  const factory AppRequirement.always() = _AlwaysRequirement;

  /// Matches wearables whose raw or formatted name starts with [prefix].
  const factory AppRequirement.nameStartsWith(String prefix) =
      _WearableNamePrefixRequirement;

  /// Matches wearables that satisfy every requirement in [requirements].
  const factory AppRequirement.allOf(List<AppRequirement> requirements) =
      _AllOfRequirement;

  /// Matches wearables that satisfy at least one requirement in [requirements].
  ///
  /// An empty [requirements] list matches every wearable.
  const factory AppRequirement.anyOf(List<AppRequirement> requirements) =
      _AnyOfRequirement;

  /// Matches wearables that expose capability [T].
  static AppRequirement hasCapability<T>() => _HasCapabilityRequirement<T>();

  /// Matches wearables that expose a sensor matching [matcher].
  static AppRequirement hasSensor(SensorMatcher matcher) {
    return _HasSensorRequirement(matcher);
  }

  /// Matches wearables that expose a sensor whose name or chart title contains
  /// any of [aliases].
  static AppRequirement hasSensorByAliases(Iterable<String> aliases) {
    return _HasSensorByAliasesRequirement(aliases);
  }

  /// Matches wearables that expose capability [T] and satisfy [predicate].
  static AppRequirement capability<T>(CapabilityPredicate<T> predicate) {
    return _CapabilityPredicateRequirement<T>(predicate);
  }

  /// Matches wearables for which [predicate] returns `true`.
  ///
  /// Prefer the typed helpers above when possible; this method is the escape
  /// hatch for custom compatibility logic.
  static AppRequirement custom(WearablePredicate predicate) {
    return _CustomRequirement(predicate);
  }
}

final class _AlwaysRequirement extends AppRequirement {
  const _AlwaysRequirement();

  @override
  bool matches(Wearable wearable) => true;
}

final class _WearableNamePrefixRequirement extends AppRequirement {
  final String prefix;

  const _WearableNamePrefixRequirement(this.prefix);

  @override
  bool matches(Wearable wearable) {
    return wearableNameStartsWithPrefix(wearable.name, prefix);
  }
}

final class _HasCapabilityRequirement<T> extends AppRequirement {
  const _HasCapabilityRequirement();

  @override
  bool matches(Wearable wearable) => wearable.hasCapability<T>();
}

final class _HasSensorRequirement extends AppRequirement {
  final SensorMatcher matcher;

  const _HasSensorRequirement(this.matcher);

  @override
  bool matches(Wearable wearable) {
    final sensorManager = wearable.getCapability<SensorManager>();
    return sensorManager != null &&
        findSensor(sensorManager.sensors, matcher) != null;
  }
}

final class _HasSensorByAliasesRequirement extends AppRequirement {
  final List<String> aliases;

  _HasSensorByAliasesRequirement(Iterable<String> aliases)
      : aliases = List.unmodifiable(aliases);

  @override
  bool matches(Wearable wearable) {
    final sensorManager = wearable.getCapability<SensorManager>();
    return sensorManager != null &&
        findSensorByAliases(sensorManager.sensors, aliases) != null;
  }
}

final class _CapabilityPredicateRequirement<T> extends AppRequirement {
  final CapabilityPredicate<T> predicate;

  const _CapabilityPredicateRequirement(this.predicate);

  @override
  bool matches(Wearable wearable) {
    final capability = wearable.getCapability<T>();
    return capability != null && predicate(capability, wearable);
  }
}

final class _CustomRequirement extends AppRequirement {
  final WearablePredicate predicate;

  const _CustomRequirement(this.predicate);

  @override
  bool matches(Wearable wearable) => predicate(wearable);
}

final class _AllOfRequirement extends AppRequirement {
  final List<AppRequirement> requirements;

  const _AllOfRequirement(this.requirements);

  @override
  bool matches(Wearable wearable) {
    return requirements.every((requirement) => requirement.matches(wearable));
  }
}

final class _AnyOfRequirement extends AppRequirement {
  final List<AppRequirement> requirements;

  const _AnyOfRequirement(this.requirements);

  @override
  bool matches(Wearable wearable) {
    if (requirements.isEmpty) {
      return true;
    }
    return requirements.any((requirement) => requirement.matches(wearable));
  }
}

/// A user-visible supported-device entry for an app.
///
/// The [label] is shown in the apps UI, while [requirement] defines which
/// wearables actually match that support option.
final class AppSupportOption {
  final String label;
  final AppRequirement requirement;

  const AppSupportOption({
    required this.label,
    required this.requirement,
  });

  bool matches(Wearable wearable) => requirement.matches(wearable);
}

/// Returns whether [wearable] is compatible with an app.
///
/// Compatibility is defined as matching at least one entry in
/// [supportedDevices]. An empty [supportedDevices] list means the app supports
/// every wearable.
bool wearableIsCompatibleWithApp({
  required Wearable wearable,
  required List<AppSupportOption> supportedDevices,
}) {
  if (supportedDevices.isEmpty) return true;
  return supportedDevices.any((device) => device.matches(wearable));
}

/// Returns whether any connected wearable matches the given support option.
bool hasConnectedWearableForOption({
  required AppSupportOption supportedDevice,
  required Iterable<Wearable> connectedWearables,
}) {
  return connectedWearables.any(supportedDevice.matches);
}
