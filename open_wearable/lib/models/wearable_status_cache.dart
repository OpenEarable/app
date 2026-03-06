import 'package:open_earable_flutter/open_earable_flutter.dart';

/// Caches stable wearable metadata per device id so views can share it.
///
/// Needs:
/// - Wearable capabilities for stereo position, firmware, and hardware reads.
///
/// Does:
/// - De-duplicates concurrent metadata reads per device id.
/// - Stores successful results for reuse across pages/widgets.
///
/// Provides:
/// - `ensure*` futures and `cached*` getters for fast repeated UI access.
class WearableStatusCache {
  WearableStatusCache._();

  static final WearableStatusCache instance = WearableStatusCache._();

  final Map<String, DevicePosition?> _stereoPositionByDeviceId = {};
  final Map<String, Future<DevicePosition?>> _stereoPositionFutureByDeviceId =
      {};

  final Map<String, Object?> _firmwareVersionByDeviceId = {};
  final Map<String, Future<Object?>> _firmwareVersionFutureByDeviceId = {};

  final Map<String, FirmwareSupportStatus> _firmwareSupportByDeviceId = {};
  final Map<String, Future<FirmwareSupportStatus>>
      _firmwareSupportFutureByDeviceId = {};

  final Map<String, Object?> _hardwareVersionByDeviceId = {};
  final Map<String, Future<Object?>> _hardwareVersionFutureByDeviceId = {};

  DevicePosition? cachedStereoPositionFor(String deviceId) =>
      _stereoPositionByDeviceId[deviceId];

  Object? cachedFirmwareVersionFor(String deviceId) =>
      _firmwareVersionByDeviceId[deviceId];

  FirmwareSupportStatus? cachedFirmwareSupportFor(String deviceId) =>
      _firmwareSupportByDeviceId[deviceId];

  Object? cachedHardwareVersionFor(String deviceId) =>
      _hardwareVersionByDeviceId[deviceId];

  Future<DevicePosition?>? ensureStereoPosition(Wearable wearable) {
    if (!wearable.hasCapability<StereoDevice>()) {
      return null;
    }

    final deviceId = wearable.deviceId;
    if (_stereoPositionByDeviceId.containsKey(deviceId)) {
      return Future<DevicePosition?>.value(_stereoPositionByDeviceId[deviceId]);
    }

    final inFlight = _stereoPositionFutureByDeviceId[deviceId];
    if (inFlight != null) {
      return inFlight;
    }

    final stereoDevice = wearable.requireCapability<StereoDevice>();
    final future = stereoDevice.position.then((position) {
      _stereoPositionByDeviceId[deviceId] = position;
      return position;
    }).catchError((Object error, StackTrace stackTrace) {
      _stereoPositionFutureByDeviceId.remove(deviceId);
      throw error;
    });

    _stereoPositionFutureByDeviceId[deviceId] = future;
    return future;
  }

  Future<Object?>? ensureFirmwareVersion(Wearable wearable) {
    if (!wearable.hasCapability<DeviceFirmwareVersion>()) {
      return null;
    }

    final deviceId = wearable.deviceId;
    if (_firmwareVersionByDeviceId.containsKey(deviceId)) {
      return Future<Object?>.value(_firmwareVersionByDeviceId[deviceId]);
    }

    final inFlight = _firmwareVersionFutureByDeviceId[deviceId];
    if (inFlight != null) {
      return inFlight;
    }

    final capability = wearable.requireCapability<DeviceFirmwareVersion>();
    final future = capability.readDeviceFirmwareVersion().then((version) {
      _firmwareVersionByDeviceId[deviceId] = version;
      return version;
    }).catchError((Object error, StackTrace stackTrace) {
      _firmwareVersionFutureByDeviceId.remove(deviceId);
      throw error;
    });

    _firmwareVersionFutureByDeviceId[deviceId] = future;
    return future;
  }

  Future<FirmwareSupportStatus>? ensureFirmwareSupport(Wearable wearable) {
    if (!wearable.hasCapability<DeviceFirmwareVersion>()) {
      return null;
    }

    final deviceId = wearable.deviceId;
    if (_firmwareSupportByDeviceId.containsKey(deviceId)) {
      return Future<FirmwareSupportStatus>.value(
        _firmwareSupportByDeviceId[deviceId],
      );
    }

    final inFlight = _firmwareSupportFutureByDeviceId[deviceId];
    if (inFlight != null) {
      return inFlight;
    }

    final capability = wearable.requireCapability<DeviceFirmwareVersion>();
    final future = capability.checkFirmwareSupport().then((supportStatus) {
      _firmwareSupportByDeviceId[deviceId] = supportStatus;
      return supportStatus;
    }).catchError((Object error, StackTrace stackTrace) {
      _firmwareSupportFutureByDeviceId.remove(deviceId);
      throw error;
    });

    _firmwareSupportFutureByDeviceId[deviceId] = future;
    return future;
  }

  Future<Object?>? ensureHardwareVersion(Wearable wearable) {
    if (!wearable.hasCapability<DeviceHardwareVersion>()) {
      return null;
    }

    final deviceId = wearable.deviceId;
    if (_hardwareVersionByDeviceId.containsKey(deviceId)) {
      return Future<Object?>.value(_hardwareVersionByDeviceId[deviceId]);
    }

    final inFlight = _hardwareVersionFutureByDeviceId[deviceId];
    if (inFlight != null) {
      return inFlight;
    }

    final capability = wearable.requireCapability<DeviceHardwareVersion>();
    final future = capability.readDeviceHardwareVersion().then((version) {
      _hardwareVersionByDeviceId[deviceId] = version;
      return version;
    }).catchError((Object error, StackTrace stackTrace) {
      _hardwareVersionFutureByDeviceId.remove(deviceId);
      throw error;
    });

    _hardwareVersionFutureByDeviceId[deviceId] = future;
    return future;
  }
}
