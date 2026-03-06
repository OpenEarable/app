import 'dart:async';

import 'package:open_earable_flutter/open_earable_flutter.dart';
import 'package:open_wearable/models/device_name_formatter.dart';

/// Metadata returned when a post-update verification check is armed.
class ArmedFotaPostUpdateVerification {
  final String verificationId;
  final String wearableName;
  final String? sideLabel;

  const ArmedFotaPostUpdateVerification({
    required this.verificationId,
    required this.wearableName,
    this.sideLabel,
  });
}

/// Result of matching a newly connected wearable against pending FOTA
/// verification expectations.
class FotaPostUpdateVerificationResult {
  final String verificationId;
  final String wearableName;
  final String? sideLabel;
  final String? expectedFirmwareVersion;
  final String? detectedFirmwareVersion;
  final bool success;
  final String message;

  const FotaPostUpdateVerificationResult({
    required this.verificationId,
    required this.wearableName,
    required this.sideLabel,
    required this.expectedFirmwareVersion,
    required this.detectedFirmwareVersion,
    required this.success,
    required this.message,
  });
}

/// Coordinates post-FOTA verification matching across reconnect events.
///
/// Needs:
/// - Update request metadata and connected wearable capability reads.
///
/// Does:
/// - Arms verifications after update start/success.
/// - Matches newly connected devices by id/name/side.
/// - Compares detected firmware against expected version.
///
/// Provides:
/// - Verification arming metadata for UI banners.
/// - Verification results consumed by toasts/banners in app lifecycle logic.
class FotaPostUpdateVerificationCoordinator {
  FotaPostUpdateVerificationCoordinator._();

  static final FotaPostUpdateVerificationCoordinator instance =
      FotaPostUpdateVerificationCoordinator._();

  static const Duration _maxPendingAge = Duration(minutes: 20);

  final Map<String, _PendingPostUpdateVerification> _pendingById = {};
  int _nextVerificationId = 0;

  Future<ArmedFotaPostUpdateVerification?> armFromUpdateRequest({
    required FirmwareUpdateRequest request,
    Wearable? selectedWearable,
    String? preResolvedWearableName,
    String? preResolvedSideLabel,
  }) async {
    _cleanupExpired();

    final rawName = selectedWearable?.name ??
        request.peripheral?.name ??
        preResolvedWearableName;
    final displayName = _displayName(preResolvedWearableName ?? rawName);
    final expectedName = _normalizeName(
      rawName,
    );
    final expectedDeviceId = _normalizeId(
      selectedWearable?.deviceId ?? request.peripheral?.identifier,
    );
    final expectedSideLabel = _normalizeSideLabel(
      preResolvedSideLabel ??
          await _resolveWearableSideLabel(selectedWearable) ??
          _resolveSideLabelFromName(selectedWearable?.name) ??
          _resolveSideLabelFromName(request.peripheral?.name),
    );
    final expectedFirmwareVersion =
        _extractExpectedFirmwareVersion(request.firmware);

    if (expectedName == null && expectedDeviceId == null) {
      return null;
    }

    final verificationId =
        'fota_${DateTime.now().millisecondsSinceEpoch}_${_nextVerificationId++}';

    _removeConflictingPending(
      expectedDeviceId: expectedDeviceId,
      expectedName: expectedName,
      expectedSideLabel: expectedSideLabel,
    );

    _pendingById[verificationId] = _PendingPostUpdateVerification(
      verificationId: verificationId,
      expectedWearableName: expectedName,
      displayWearableName: displayName,
      expectedDeviceId: expectedDeviceId,
      expectedSideLabel: expectedSideLabel,
      expectedFirmwareVersion: expectedFirmwareVersion,
      armedAt: DateTime.now(),
    );

    return ArmedFotaPostUpdateVerification(
      verificationId: verificationId,
      wearableName: displayName ?? 'OpenEarable',
      sideLabel: expectedSideLabel,
    );
  }

  Future<FotaPostUpdateVerificationResult?> verifyOnWearableConnected(
    Wearable wearable,
  ) async {
    _cleanupExpired();
    if (_pendingById.isEmpty) {
      return null;
    }

    final connectedName = _normalizeName(wearable.name);
    final connectedDeviceId = _normalizeId(wearable.deviceId);
    final connectedSideLabel = _normalizeSideLabel(
      await _resolveWearableSideLabel(wearable) ??
          _resolveSideLabelFromName(wearable.name),
    );

    final pending = _selectMatchingPending(
      connectedName: connectedName,
      connectedDeviceId: connectedDeviceId,
      connectedSideLabel: connectedSideLabel,
    );

    if (pending == null) {
      return null;
    }

    final detectedFirmwareVersion =
        await _readNormalizedFirmwareVersion(wearable);
    final expectedFirmwareVersion = pending.expectedFirmwareVersion;

    final success = expectedFirmwareVersion != null &&
        detectedFirmwareVersion != null &&
        _firmwareVersionsMatch(
          expectedFirmwareVersion,
          detectedFirmwareVersion,
        );

    _pendingById.remove(pending.verificationId);

    final displayName = pending.displayWearableName ??
        _displayName(wearable.name) ??
        wearable.name;
    final sideLabel = pending.expectedSideLabel ?? connectedSideLabel;

    return FotaPostUpdateVerificationResult(
      verificationId: pending.verificationId,
      wearableName: displayName,
      sideLabel: sideLabel,
      expectedFirmwareVersion: expectedFirmwareVersion,
      detectedFirmwareVersion: detectedFirmwareVersion,
      success: success,
      message: _buildMessage(
        success: success,
        wearableName: displayName,
        sideLabel: sideLabel,
        expectedFirmwareVersion: expectedFirmwareVersion,
        detectedFirmwareVersion: detectedFirmwareVersion,
      ),
    );
  }

  _PendingPostUpdateVerification? _selectMatchingPending({
    required String? connectedName,
    required String? connectedDeviceId,
    required String? connectedSideLabel,
  }) {
    _PendingPostUpdateVerification? best;
    var bestScore = -1;

    for (final pending in _pendingById.values) {
      final score = _matchScore(
        pending: pending,
        connectedName: connectedName,
        connectedDeviceId: connectedDeviceId,
        connectedSideLabel: connectedSideLabel,
      );
      if (score < 0) {
        continue;
      }
      if (score > bestScore) {
        best = pending;
        bestScore = score;
        continue;
      }
      if (score == bestScore && best != null) {
        // Ambiguous match: do not dismiss any verification banner.
        best = null;
      }
    }

    return best;
  }

  int _matchScore({
    required _PendingPostUpdateVerification pending,
    required String? connectedName,
    required String? connectedDeviceId,
    required String? connectedSideLabel,
  }) {
    final expectedId = pending.expectedDeviceId;
    final expectedName = pending.expectedWearableName;
    final expectedSide = pending.expectedSideLabel;

    final exactIdMatch = expectedId != null &&
        connectedDeviceId != null &&
        expectedId == connectedDeviceId;

    if (expectedId != null && !exactIdMatch) {
      // With known ids, allow a fallback by name for non-stereo devices.
      // Stereo devices additionally require a side match.
      final nameMatch = _namesMatch(expectedName, connectedName);
      final sideMatch = expectedSide != null &&
          connectedSideLabel != null &&
          expectedSide == connectedSideLabel;
      final connectedAppearsStereo = connectedSideLabel != null;
      if (!nameMatch) {
        return -1;
      }
      if (expectedSide != null && !sideMatch) {
        return -1;
      }
      if (expectedSide == null && connectedAppearsStereo) {
        return -1;
      }
    }

    if (!exactIdMatch && !_namesMatch(expectedName, connectedName)) {
      return -1;
    }

    if (!exactIdMatch && expectedSide != null) {
      if (connectedSideLabel == null || connectedSideLabel != expectedSide) {
        return -1;
      }
    }

    var score = 0;
    if (exactIdMatch) {
      score += 100;
    }
    if (expectedName != null &&
        connectedName != null &&
        expectedName == connectedName) {
      score += 20;
    }
    if (expectedSide != null &&
        connectedSideLabel != null &&
        expectedSide == connectedSideLabel) {
      score += 30;
    }
    if (expectedId == null && expectedName != null && expectedSide == null) {
      score += 5;
    }

    return score;
  }

  bool _namesMatch(String? expected, String? connected) {
    if (expected == null) {
      return true;
    }
    if (connected == null) {
      return false;
    }
    return expected == connected;
  }

  Future<String?> _readNormalizedFirmwareVersion(Wearable wearable) async {
    DeviceFirmwareVersion? firmwareCap =
        wearable.getCapability<DeviceFirmwareVersion>();

    if (firmwareCap == null) {
      try {
        await wearable
            .capabilityAvailable<DeviceFirmwareVersion>()
            .first
            .timeout(const Duration(seconds: 3));
      } catch (_) {
        // Ignore timeout/errors and check capability below.
      }
      firmwareCap = wearable.getCapability<DeviceFirmwareVersion>();
    }

    if (firmwareCap == null) {
      return null;
    }

    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        final version = await firmwareCap
            .readDeviceFirmwareVersion()
            .timeout(const Duration(seconds: 4));
        final normalized = _normalizeVersion(version);
        if (normalized != null) {
          return normalized;
        }
      } catch (_) {
        // Retry below.
      }

      if (attempt < 2) {
        await Future.delayed(const Duration(milliseconds: 600));
      }
    }

    return null;
  }

  Future<String?> _resolveWearableSideLabel(Wearable? wearable) async {
    if (wearable == null) {
      return null;
    }

    final fallback = _resolveSideLabelFromName(wearable.name);

    StereoDevice? stereoDevice = wearable.getCapability<StereoDevice>();
    if (stereoDevice == null) {
      for (var attempt = 0; attempt < 4 && stereoDevice == null; attempt++) {
        try {
          await wearable
              .capabilityAvailable<StereoDevice>()
              .first
              .timeout(const Duration(seconds: 1));
        } catch (_) {
          // Ignore timeout/errors and retry below.
        }
        stereoDevice = wearable.getCapability<StereoDevice>();
        if (stereoDevice == null && attempt < 3) {
          await Future.delayed(const Duration(milliseconds: 250));
        }
      }
    }

    if (stereoDevice == null) {
      return fallback;
    }

    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        final position =
            await stereoDevice.position.timeout(const Duration(seconds: 2));
        return switch (position) {
          DevicePosition.left => 'L',
          DevicePosition.right => 'R',
          _ => fallback,
        };
      } catch (_) {
        if (attempt < 2) {
          await Future.delayed(const Duration(milliseconds: 350));
        }
      }
    }

    return fallback;
  }

  void _cleanupExpired() {
    if (_pendingById.isEmpty) {
      return;
    }

    final now = DateTime.now();
    _pendingById.removeWhere(
      (_, pending) => now.difference(pending.armedAt) > _maxPendingAge,
    );
  }

  void _removeConflictingPending({
    required String? expectedDeviceId,
    required String? expectedName,
    required String? expectedSideLabel,
  }) {
    if (_pendingById.isEmpty) {
      return;
    }

    _pendingById.removeWhere((_, pending) {
      if (expectedDeviceId != null &&
          pending.expectedDeviceId == expectedDeviceId) {
        return true;
      }

      final sameName = pending.expectedWearableName == expectedName;
      final sameSide = pending.expectedSideLabel == expectedSideLabel;
      if (expectedDeviceId == null &&
          expectedName != null &&
          sameName &&
          sameSide) {
        return true;
      }

      return false;
    });
  }

  String? _extractExpectedFirmwareVersion(SelectedFirmware? firmware) {
    if (firmware is RemoteFirmware) {
      return _normalizeVersion(firmware.version);
    }

    if (firmware is LocalFirmware) {
      final match =
          RegExp(r'(\d+\.\d+\.\d+(?:[-+][\w.-]+)?)').firstMatch(firmware.name);
      return _normalizeVersion(match?.group(1));
    }

    return null;
  }

  bool _firmwareVersionsMatch(String expected, String actual) {
    if (actual == expected) {
      return true;
    }
    return actual.contains(expected) || expected.contains(actual);
  }

  String _buildMessage({
    required bool success,
    required String wearableName,
    required String? sideLabel,
    required String? expectedFirmwareVersion,
    required String? detectedFirmwareVersion,
  }) {
    final sideSuffix = sideLabel == null ? '' : ' ($sideLabel)';

    if (success) {
      final versionSuffix = detectedFirmwareVersion == null
          ? ''
          : ' (version $detectedFirmwareVersion)';
      return 'Verification completed for $wearableName$sideSuffix. '
          'Update verified$versionSuffix.';
    }

    if (detectedFirmwareVersion == null) {
      return 'Verification failed for $wearableName$sideSuffix. '
          'Firmware version could not be read.';
    }

    if (expectedFirmwareVersion == null) {
      return 'Verification failed for $wearableName$sideSuffix. '
          'Expected firmware version is unknown (detected $detectedFirmwareVersion).';
    }

    return 'Verification failed for $wearableName$sideSuffix. '
        'Expected $expectedFirmwareVersion but detected $detectedFirmwareVersion.';
  }

  String? _normalizeName(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }

    final normalized = trimmed
        .toLowerCase()
        .replaceFirst(RegExp(r'\s*\((left|right|l|r)\)$'), '')
        .replaceFirst(RegExp(r'[\s_-]+(left|right|l|r)$'), '')
        .trim();
    if (normalized.isEmpty) {
      return trimmed.toLowerCase();
    }
    return normalized;
  }

  String? _displayName(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }
    return formatWearableDisplayName(trimmed);
  }

  String? _normalizeId(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }
    return trimmed.toLowerCase();
  }

  String? _normalizeVersion(String? value) {
    final cleaned = value?.replaceAll('\x00', '').trim();
    if (cleaned == null || cleaned.isEmpty) {
      return null;
    }
    return cleaned;
  }

  String? _normalizeSideLabel(String? sideLabel) {
    if (sideLabel == null || sideLabel.isEmpty) {
      return null;
    }
    final upper = sideLabel.toUpperCase();
    if (upper == 'L' || upper == 'LEFT') {
      return 'L';
    }
    if (upper == 'R' || upper == 'RIGHT') {
      return 'R';
    }
    return null;
  }

  String? _resolveSideLabelFromName(String? deviceName) {
    final value = deviceName?.trim().toLowerCase();
    if (value == null || value.isEmpty) {
      return null;
    }

    if (value.endsWith('-l') ||
        value.endsWith('_l') ||
        value.endsWith('(l)') ||
        value.endsWith('(left)') ||
        value.endsWith(' left') ||
        value.endsWith(' l')) {
      return 'L';
    }

    if (value.endsWith('-r') ||
        value.endsWith('_r') ||
        value.endsWith('(r)') ||
        value.endsWith('(right)') ||
        value.endsWith(' right') ||
        value.endsWith(' r')) {
      return 'R';
    }

    return null;
  }
}

class _PendingPostUpdateVerification {
  final String verificationId;
  final String? expectedWearableName;
  final String? displayWearableName;
  final String? expectedDeviceId;
  final String? expectedSideLabel;
  final String? expectedFirmwareVersion;
  final DateTime armedAt;

  const _PendingPostUpdateVerification({
    required this.verificationId,
    required this.expectedWearableName,
    required this.displayWearableName,
    required this.expectedDeviceId,
    required this.expectedSideLabel,
    required this.expectedFirmwareVersion,
    required this.armedAt,
  });
}
