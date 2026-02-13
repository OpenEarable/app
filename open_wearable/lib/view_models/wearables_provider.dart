import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart' hide logger;
import 'package:open_wearable/models/wearable_display_group.dart';
import 'package:open_wearable/view_models/sensor_configuration_provider.dart';

import '../models/logger.dart';

/// Event for when a newer firmware version is available
class NewFirmwareAvailableEvent extends WearableEvent {
  final String currentVersion;
  final String latestVersion;

  NewFirmwareAvailableEvent({
    required super.wearable,
    required this.currentVersion,
    required this.latestVersion,
  }) : super(
          description:
              'Firmware update available for ${wearable.name}: $currentVersion -> $latestVersion',
        );

  @override
  String toString() =>
      'NewFirmwareAvailableEvent for ${wearable.name}: $currentVersion -> $latestVersion';
}

abstract class UnsupportedFirmwareEvent {
  final Wearable wearable;
  UnsupportedFirmwareEvent(this.wearable);
}

class FirmwareUnsupportedEvent extends UnsupportedFirmwareEvent {
  FirmwareUnsupportedEvent(super.wearable);
}

class FirmwareTooOldEvent extends UnsupportedFirmwareEvent {
  FirmwareTooOldEvent(super.wearable);
}

class FirmwareTooNewEvent extends UnsupportedFirmwareEvent {
  FirmwareTooNewEvent(super.wearable);
}

abstract class WearableEvent {
  final Wearable wearable;
  final String description;

  WearableEvent({required this.wearable, required this.description});
}

class WearableTimeSynchronizedEvent extends WearableEvent {
  WearableTimeSynchronizedEvent({
    required super.wearable,
    String? description,
  }) : super(
          description: description ?? 'Time synchronized for ${wearable.name}',
        );

  @override
  String toString() => 'WearableTimeSynchronizedEvent for ${wearable.name}';
}

class WearableErrorEvent extends WearableEvent {
  final String errorMessage;
  WearableErrorEvent({
    required super.wearable,
    required this.errorMessage,
    String? description,
  }) : super(
          description:
              description ?? 'Error for ${wearable.name}: $errorMessage',
        );

  @override
  String toString() =>
      'WearableErrorEvent for ${wearable.name}: $errorMessage, description: $description';
}

// MARK: WearablesProvider

class WearablesProvider with ChangeNotifier {
  final List<Wearable> _wearables = [];
  final Map<Wearable, SensorConfigurationProvider>
      _sensorConfigurationProviders = {};
  final Set<String> _splitStereoPairKeys = {};

  List<Wearable> get wearables => _wearables;
  Map<Wearable, SensorConfigurationProvider> get sensorConfigurationProviders =>
      _sensorConfigurationProviders;
  bool isStereoPairCombined({
    required Wearable first,
    required Wearable second,
  }) {
    final pairKey = WearableDisplayGroup.stereoPairKeyForDevices(first, second);
    return !_splitStereoPairKeys.contains(pairKey);
  }

  bool isStereoPairKeyCombined(String pairKey) {
    return !_splitStereoPairKeys.contains(pairKey);
  }

  void setStereoPairCombined({
    required Wearable first,
    required Wearable second,
    required bool combined,
  }) {
    final pairKey = WearableDisplayGroup.stereoPairKeyForDevices(first, second);
    setStereoPairKeyCombined(pairKey: pairKey, combined: combined);
  }

  void setStereoPairKeyCombined({
    required String pairKey,
    required bool combined,
  }) {
    final changed = combined
        ? _splitStereoPairKeys.remove(pairKey)
        : _splitStereoPairKeys.add(pairKey);
    if (changed) {
      notifyListeners();
    }
  }

  final _unsupportedFirmwareEventsController =
      StreamController<UnsupportedFirmwareEvent>.broadcast();
  Stream<UnsupportedFirmwareEvent> get unsupportedFirmwareStream =>
      _unsupportedFirmwareEventsController.stream;

  final _wearableEventController = StreamController<WearableEvent>.broadcast();
  Stream<WearableEvent> get wearableEventStream =>
      _wearableEventController.stream;

  final Map<Wearable, StreamSubscription> _capabilitySubscriptions = {};

  // MARK: Internal helpers

  bool _isDuplicateDevice(Wearable wearable) =>
      _wearables.any((w) => w.deviceId == wearable.deviceId);

  void _emitWearableEvent(WearableEvent event) {
    _wearableEventController.add(event);
  }

  void _emitWearableError({
    required Wearable wearable,
    required String errorMessage,
    String? description,
  }) {
    _emitWearableEvent(
      WearableErrorEvent(
        wearable: wearable,
        errorMessage: errorMessage,
        description: description,
      ),
    );
  }

  void _scheduleMicrotask(FutureOr<void> Function() work) {
    Future.microtask(() async {
      try {
        await work();
      } catch (e, st) {
        logger.w('WearablesProvider microtask failed: $e\n$st');
      }
    });
  }

  Future<String> _wearableNameWithSide(Wearable wearable) async {
    if (!wearable.hasCapability<StereoDevice>()) {
      return wearable.name;
    }

    try {
      final position = await wearable.requireCapability<StereoDevice>().position;
      return switch (position) {
        DevicePosition.left => '${wearable.name} (Left)',
        DevicePosition.right => '${wearable.name} (Right)',
        _ => wearable.name,
      };
    } catch (_) {
      return wearable.name;
    }
  }

  Future<void> _syncTimeAndEmit({
    required Wearable wearable,
    required bool fromCapabilityChange,
  }) async {
    final wearableLabel = await _wearableNameWithSide(wearable);
    final successDescription = fromCapabilityChange
        ? 'Time synchronized for $wearableLabel after capability update'
        : 'Time synchronized for $wearableLabel';
    final failureDescription = fromCapabilityChange
        ? 'Failed to synchronize time for $wearableLabel after capability update'
        : 'Failed to synchronize time for $wearableLabel';

    try {
      logger.d('Synchronizing time for wearable ${wearable.name}');
      await (wearable.requireCapability<TimeSynchronizable>())
          .synchronizeTime();
      logger.d('Time synchronized for wearable ${wearable.name}');
      _emitWearableEvent(
        WearableTimeSynchronizedEvent(
          wearable: wearable,
          description: successDescription,
        ),
      );
    } catch (e, st) {
      logger.w(
        'Failed to synchronize time for wearable ${wearable.name}: $e\n$st',
      );
      _emitWearableError(
        wearable: wearable,
        errorMessage: 'Failed to synchronize time with $wearableLabel: $e',
        description: failureDescription,
      );
    }
  }

  void addWearable(Wearable wearable) {
    // 1) Fast path: ignore duplicates and push into lists/maps synchronously
    if (_isDuplicateDevice(wearable)) return;

    _wearables.add(wearable);

    _capabilitySubscriptions[wearable] =
        wearable.capabilityRegistered.listen((addedCapabilities) {
      _handleCapabilitiesChanged(
        wearable: wearable,
        addedCapabilites: addedCapabilities,
      );
    });

    // Init SensorConfigurationProvider synchronously (no awaits here)
    if (wearable.hasCapability<SensorConfigurationManager>()) {
      _ensureSensorConfigProvider(wearable);
      final notifier = _sensorConfigurationProviders[wearable]!;
      for (final config
          in (wearable.requireCapability<SensorConfigurationManager>())
              .sensorConfigurations) {
        if (notifier.getSelectedConfigurationValue(config) == null &&
            config.values.isNotEmpty) {
          notifier.addSensorConfiguration(config, config.values.first);
        }
      }
    }
    if (wearable.hasCapability<TimeSynchronizable>()) {
      _scheduleMicrotask(
        () => _syncTimeAndEmit(
          wearable: wearable,
          fromCapabilityChange: false,
        ),
      );
    }

    // Disconnect listener (sync)
    wearable.addDisconnectListener(() {
      removeWearable(wearable);
      notifyListeners();
    });

    // Notify ASAP so UI updates with the newly connected device
    notifyListeners();

    // 2) Slow/async work: run in microtasks so it doesn't block the add
    // Stereo pairing (if applicable)
    if (wearable.hasCapability<StereoDevice>()) {
      _scheduleMicrotask(
        () => _maybeAutoPairStereoAsync(
          wearable.requireCapability<StereoDevice>(),
        ),
      );
    }

    // Firmware support check (if applicable)
    if (wearable.hasCapability<DeviceFirmwareVersion>()) {
      _scheduleMicrotask(
        () => _maybeEmitUnsupportedFirmwareAsync(
          wearable.requireCapability<DeviceFirmwareVersion>(),
        ),
      );
    }

    // Check for newer firmware (if applicable)
    if (wearable.hasCapability<DeviceFirmwareVersion>()) {
      _scheduleMicrotask(
        () => _checkForNewerFirmwareAsync(
          wearable.requireCapability<DeviceFirmwareVersion>(),
        ),
      );
    }
  }

  // MARK: Helpers

  void _ensureSensorConfigProvider(Wearable wearable) {
    if (!_sensorConfigurationProviders.containsKey(wearable)) {
      _sensorConfigurationProviders[wearable] = SensorConfigurationProvider(
        sensorConfigurationManager:
            wearable.requireCapability<SensorConfigurationManager>(),
      );
    }
  }

  /// Attempts to pair a stereo device with a matching partner among the
  /// already-known wearables. Runs asynchronously and logs results.
  /// Non-blocking for the caller.
  Future<void> _maybeAutoPairStereoAsync(StereoDevice stereo) async {
    try {
      final alreadyPaired = await stereo.pairedDevice;
      if (alreadyPaired != null) return;

      final stereoList = _wearables.whereType<StereoDevice>().toList();
      final possiblePairs =
          await WearableManager().findValidPairsFor(stereo, stereoList);

      logger.d('possible pairs for ${stereo.toString()}: $possiblePairs');

      if (possiblePairs.isNotEmpty) {
        await stereo.pair(possiblePairs.first);
        final partner = await stereo.pairedDevice;
        logger.i('Paired ${(stereo as Wearable).name} with $partner');
      }
    } catch (e, st) {
      logger.w('Auto-pair failed for ${(stereo as Wearable).name}: $e\n$st');
    }
  }

  /// Checks firmware support and emits the event if unsupported.
  /// Non-blocking for the caller.
  Future<void> _maybeEmitUnsupportedFirmwareAsync(
    DeviceFirmwareVersion dev,
  ) async {
    try {
      final wearable = dev as Wearable;
      // In your abstraction, isFirmwareSupported is a Future<bool> getter.
      final supportStatus = await dev.checkFirmwareSupport();
      switch (supportStatus) {
        case FirmwareSupportStatus.supported:
          // All good, nothing to do.
          break;
        case FirmwareSupportStatus.tooNew:
          _unsupportedFirmwareEventsController
              .add(FirmwareTooNewEvent(wearable));
          break;
        case FirmwareSupportStatus.unsupported:
          _unsupportedFirmwareEventsController
              .add(FirmwareUnsupportedEvent(wearable));
          break;
        case FirmwareSupportStatus.tooOld:
          _unsupportedFirmwareEventsController
              .add(FirmwareTooOldEvent(wearable));
        case FirmwareSupportStatus.unknown:
          logger.w('Firmware support unknown for ${wearable.name}');
          break;
      }
    } catch (e, st) {
      final wearable = dev as Wearable;
      logger.w('Firmware check failed for ${wearable.name}: $e\n$st');
    }
  }

  /// Checks if a newer firmware version is available and emits event if so.
  /// Non-blocking for the caller.
  Future<void> _checkForNewerFirmwareAsync(DeviceFirmwareVersion dev) async {
    try {
      logger.d('Checking for newer firmware for ${(dev as Wearable).name}');

      final currentVersion = await dev.readDeviceFirmwareVersion();
      if (currentVersion == null || currentVersion.isEmpty) {
        logger
            .d('Could not read firmware version for ${(dev as Wearable).name}');
        return;
      }

      final firmwareImageRepository = FirmwareImageRepository();
      final latestVersion = await firmwareImageRepository
          .getLatestFirmwareVersion()
          .then((version) => version.toString());

      if (firmwareImageRepository.isNewerVersion(
        latestVersion,
        currentVersion,
      )) {
        logger.i(
          'Newer firmware available for ${(dev as Wearable).name}: $currentVersion -> $latestVersion',
        );
        _wearableEventController.add(
          NewFirmwareAvailableEvent(
            wearable: dev as Wearable,
            currentVersion: currentVersion,
            latestVersion: latestVersion,
          ),
        );
      } else {
        logger.d(
          'Firmware is up to date for ${(dev as Wearable).name}: $currentVersion',
        );
      }
    } catch (e, st) {
      logger.w(
        'Firmware version check failed for ${(dev as Wearable).name}: $e\n$st',
      );
    }
  }

  void removeWearable(Wearable wearable) {
    _splitStereoPairKeys.removeWhere(
      (key) => WearableDisplayGroup.stereoPairKeyContainsDevice(
        key,
        wearable.deviceId,
      ),
    );
    _wearables.remove(wearable);
    _sensorConfigurationProviders.remove(wearable);
    _capabilitySubscriptions.remove(wearable)?.cancel();
    notifyListeners();
  }

  SensorConfigurationProvider getSensorConfigurationProvider(
    Wearable wearable,
  ) {
    if (!_sensorConfigurationProviders.containsKey(wearable)) {
      throw Exception(
        'No SensorConfigurationProvider found for the given wearable: ${wearable.name}',
      );
    }
    return _sensorConfigurationProviders[wearable]!;
  }

  void _handleCapabilitiesChanged({
    required Wearable wearable,
    required List<Type> addedCapabilites,
  }) {
    if (addedCapabilites.contains(SensorConfigurationManager)) {
      _ensureSensorConfigProvider(wearable);
    }
    if (addedCapabilites.contains(TimeSynchronizable)) {
      _scheduleMicrotask(
        () => _syncTimeAndEmit(
          wearable: wearable,
          fromCapabilityChange: true,
        ),
      );
    }
  }
}
