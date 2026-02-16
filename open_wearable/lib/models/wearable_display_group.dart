import 'package:open_earable_flutter/open_earable_flutter.dart';
import 'package:open_wearable/models/device_name_formatter.dart';

class WearableDisplayGroup {
  final Wearable primary;
  final Wearable? secondary;
  final Wearable? pairCandidate;
  final DevicePosition? primaryPosition;
  final DevicePosition? secondaryPosition;
  final String displayName;
  final String? stereoPairKey;

  const WearableDisplayGroup._({
    required this.primary,
    required this.secondary,
    required this.pairCandidate,
    required this.primaryPosition,
    required this.secondaryPosition,
    required this.displayName,
    required this.stereoPairKey,
  });

  factory WearableDisplayGroup.single({
    required Wearable wearable,
    DevicePosition? position,
    Wearable? pairCandidate,
    String? stereoPairKey,
  }) {
    return WearableDisplayGroup._(
      primary: wearable,
      secondary: null,
      pairCandidate: pairCandidate,
      primaryPosition: position,
      secondaryPosition: null,
      displayName: formatWearableDisplayName(wearable.name),
      stereoPairKey: stereoPairKey,
    );
  }

  factory WearableDisplayGroup.combined({
    required Wearable left,
    required Wearable right,
    required String displayName,
    String? stereoPairKey,
  }) {
    return WearableDisplayGroup._(
      primary: left,
      secondary: right,
      pairCandidate: null,
      primaryPosition: DevicePosition.left,
      secondaryPosition: DevicePosition.right,
      displayName: displayName,
      stereoPairKey: stereoPairKey ?? stereoPairKeyForDevices(left, right),
    );
  }

  bool get isCombined => secondary != null;

  Wearable get representative => primary;

  Wearable? get leftDevice {
    if (!isCombined) {
      return primaryPosition == DevicePosition.left ? primary : null;
    }
    return primaryPosition == DevicePosition.left ? primary : secondary;
  }

  Wearable? get rightDevice {
    if (!isCombined) {
      return primaryPosition == DevicePosition.right ? primary : null;
    }
    return primaryPosition == DevicePosition.right ? primary : secondary;
  }

  String get identifiersLabel {
    if (!isCombined) {
      return primary.deviceId;
    }

    final leftId = leftDevice?.deviceId ?? primary.deviceId;
    final rightId = rightDevice?.deviceId ?? secondary!.deviceId;
    return '$leftId / $rightId';
  }

  List<Wearable> get members => isCombined ? [primary, secondary!] : [primary];

  static String stereoPairKeyForDevices(Wearable a, Wearable b) {
    return stereoPairKeyForIds(a.deviceId, b.deviceId);
  }

  static String stereoPairKeyForIds(String aDeviceId, String bDeviceId) {
    final ids = [
      Uri.encodeComponent(aDeviceId),
      Uri.encodeComponent(bDeviceId),
    ]..sort();
    return '${ids.first}|${ids.last}';
  }

  static bool stereoPairKeyContainsDevice(String key, String deviceId) {
    final encoded = Uri.encodeComponent(deviceId);
    final parts = key.split('|');
    return parts.contains(encoded);
  }
}

class _StereoMetadata {
  final Wearable wearable;
  final DevicePosition? position;
  final String? pairedDeviceId;
  final String? firmwareVersion;
  final bool hasFirmwareCapability;

  const _StereoMetadata({
    required this.wearable,
    required this.position,
    required this.pairedDeviceId,
    required this.firmwareVersion,
    required this.hasFirmwareCapability,
  });
}

Future<List<WearableDisplayGroup>> buildWearableDisplayGroups(
  List<Wearable> wearables, {
  required bool Function(Wearable left, Wearable right) shouldCombinePair,
}) async {
  if (wearables.isEmpty) {
    return const [];
  }

  final metadataById = await _buildStereoMetadata(wearables);

  final wearablesById = {
    for (final wearable in wearables) wearable.deviceId: wearable,
  };
  final used = <String>{};
  final groups = <WearableDisplayGroup>[];

  for (final wearable in wearables) {
    if (used.contains(wearable.deviceId)) {
      continue;
    }

    final metadata = metadataById[wearable.deviceId];
    if (metadata == null) {
      used.add(wearable.deviceId);
      groups.add(WearableDisplayGroup.single(wearable: wearable));
      continue;
    }

    final partner = _findPartner(
      current: metadata,
      wearablesById: wearablesById,
      metadataById: metadataById,
      wearablesInOrder: wearables,
      used: used,
    );

    if (partner != null) {
      final left = metadata.position == DevicePosition.left
          ? metadata.wearable
          : partner.wearable;
      final right = metadata.position == DevicePosition.right
          ? metadata.wearable
          : partner.wearable;
      final pairKey = WearableDisplayGroup.stereoPairKeyForDevices(left, right);
      final combine = shouldCombinePair(left, right);

      used.add(metadata.wearable.deviceId);
      used.add(partner.wearable.deviceId);

      if (combine) {
        groups.add(
          WearableDisplayGroup.combined(
            left: left,
            right: right,
            displayName: formatWearableDisplayName(
              _combinedDisplayName(left.name, right.name),
            ),
            stereoPairKey: pairKey,
          ),
        );
      } else {
        groups.add(
          WearableDisplayGroup.single(
            wearable: left,
            position: DevicePosition.left,
            pairCandidate: right,
            stereoPairKey: pairKey,
          ),
        );
        groups.add(
          WearableDisplayGroup.single(
            wearable: right,
            position: DevicePosition.right,
            pairCandidate: left,
            stereoPairKey: pairKey,
          ),
        );
      }

      continue;
    }

    used.add(wearable.deviceId);
    groups.add(
      WearableDisplayGroup.single(
        wearable: wearable,
        position: metadata.position,
      ),
    );
  }

  return groups;
}

Future<Map<String, _StereoMetadata>> _buildStereoMetadata(
  List<Wearable> wearables,
) async {
  final entries = await Future.wait(
    wearables.map((wearable) async {
      if (!wearable.hasCapability<StereoDevice>()) {
        return null;
      }

      final stereo = wearable.requireCapability<StereoDevice>();
      final positionFuture = stereo.position;
      final pairedFuture = stereo.pairedDevice;
      final firmwareFuture = _readFirmwareVersion(wearable);
      final hasFirmwareCapability =
          wearable.hasCapability<DeviceFirmwareVersion>();
      final position = await positionFuture;
      final paired = await pairedFuture;
      final firmwareVersion = await firmwareFuture;
      String? pairedDeviceId;
      if (paired != null) {
        for (final candidate in wearables) {
          if (!candidate.hasCapability<StereoDevice>()) {
            continue;
          }
          if (identical(
            candidate.requireCapability<StereoDevice>(),
            paired,
          )) {
            pairedDeviceId = candidate.deviceId;
            break;
          }
        }
      }

      return MapEntry(
        wearable.deviceId,
        _StereoMetadata(
          wearable: wearable,
          position: position,
          pairedDeviceId: pairedDeviceId,
          firmwareVersion: firmwareVersion,
          hasFirmwareCapability: hasFirmwareCapability,
        ),
      );
    }),
  );

  final map = <String, _StereoMetadata>{};
  for (final entry in entries) {
    if (entry != null) {
      map[entry.key] = entry.value;
    }
  }
  return map;
}

_StereoMetadata? _findPartner({
  required _StereoMetadata current,
  required Map<String, Wearable> wearablesById,
  required Map<String, _StereoMetadata> metadataById,
  required List<Wearable> wearablesInOrder,
  required Set<String> used,
}) {
  final pairedId = current.pairedDeviceId;
  if (pairedId != null && !used.contains(pairedId)) {
    final pairedWearable = wearablesById[pairedId];
    final pairedMetadata =
        pairedWearable == null ? null : metadataById[pairedId];
    if (pairedMetadata != null) {
      if (_canCombine(
        a: current,
        b: pairedMetadata,
        requireMutualPairing: false,
      )) {
        return pairedMetadata;
      }
      // A known stereo partner exists but is not combinable (e.g. firmware
      // mismatch). Do not fall back to other same-name devices.
      return null;
    }
  }

  for (final candidateWearable in wearablesInOrder) {
    if (candidateWearable.deviceId == current.wearable.deviceId) {
      continue;
    }
    if (used.contains(candidateWearable.deviceId)) {
      continue;
    }

    final candidate = metadataById[candidateWearable.deviceId];
    if (candidate == null) {
      continue;
    }
    if (_canCombine(
      a: current,
      b: candidate,
      requireMutualPairing: false,
    )) {
      return candidate;
    }
  }

  return null;
}

bool _canCombine({
  required _StereoMetadata a,
  required _StereoMetadata b,
  required bool requireMutualPairing,
}) {
  final oppositePositions = (a.position == DevicePosition.left &&
          b.position == DevicePosition.right) ||
      (a.position == DevicePosition.right && b.position == DevicePosition.left);
  if (!oppositePositions) {
    return false;
  }

  if (!_stereoNamesMatch(a.wearable.name, b.wearable.name)) {
    return false;
  }

  if (!_firmwareVersionsAreCompatible(a, b)) {
    return false;
  }

  if (!requireMutualPairing) {
    return true;
  }

  return a.pairedDeviceId == b.wearable.deviceId &&
      b.pairedDeviceId == a.wearable.deviceId;
}

String _combinedDisplayName(String leftName, String rightName) {
  final leftBase = _normalizedStereoName(leftName);
  final rightBase = _normalizedStereoName(rightName);

  if (leftBase.isNotEmpty &&
      leftBase.toLowerCase() == rightBase.toLowerCase()) {
    return leftBase;
  }
  return leftName.trim();
}

bool _stereoNamesMatch(String a, String b) {
  final normalizedA = _normalizedStereoName(a);
  final normalizedB = _normalizedStereoName(b);
  return normalizedA.toLowerCase() == normalizedB.toLowerCase();
}

String _normalizedStereoName(String name) {
  var value = name.trim();
  value = value.replaceFirst(
    RegExp(r'\s*\((left|right|l|r)\)$', caseSensitive: false),
    '',
  );
  value = value.replaceFirst(
    RegExp(r'[\s_-]+(left|right|l|r)$', caseSensitive: false),
    '',
  );
  value = value.trim();
  return value.isEmpty ? name.trim() : value;
}

bool _firmwareVersionsAreCompatible(_StereoMetadata a, _StereoMetadata b) {
  // If both devices expose firmware capabilities, we only allow combining when
  // both versions are readable and exactly match.
  if (a.hasFirmwareCapability && b.hasFirmwareCapability) {
    final normalizedA = _normalizeFirmwareVersion(a.firmwareVersion);
    final normalizedB = _normalizeFirmwareVersion(b.firmwareVersion);
    if (normalizedA == null || normalizedB == null) {
      return false;
    }
    return normalizedA == normalizedB;
  }
  return true;
}

String? _normalizeFirmwareVersion(String? version) {
  if (version == null) {
    return null;
  }

  var normalized = version.trim().toLowerCase();
  if (normalized.isEmpty) {
    return null;
  }

  normalized = normalized.replaceFirst(RegExp(r'^v(?=\d)'), '');
  return normalized.isEmpty ? null : normalized;
}

final Expando<Future<String?>> _firmwareVersionFutureCache =
    Expando<Future<String?>>();

Future<String?> _readFirmwareVersion(Wearable wearable) {
  if (!wearable.hasCapability<DeviceFirmwareVersion>()) {
    return Future<String?>.value(null);
  }

  final capability = wearable.requireCapability<DeviceFirmwareVersion>();
  return _firmwareVersionFutureCache[capability] ??= capability
      .readDeviceFirmwareVersion()
      .timeout(const Duration(seconds: 2))
      .then(_normalizeFirmwareVersion)
      .catchError((_) => null);
}
