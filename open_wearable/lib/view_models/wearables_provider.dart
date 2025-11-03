import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart';
import 'package:open_wearable/view_models/sensor_configuration_provider.dart';

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

class WearablesProvider with ChangeNotifier {
  final List<Wearable> _wearables = [];
  final Map<Wearable, SensorConfigurationProvider> _sensorConfigurationProviders = {};

  List<Wearable> get wearables => _wearables;
  Map<Wearable, SensorConfigurationProvider> get sensorConfigurationProviders => _sensorConfigurationProviders;

  final _unsupportedFirmwareEventsController = StreamController<UnsupportedFirmwareEvent>.broadcast();
  Stream<UnsupportedFirmwareEvent> get unsupportedFirmwareStream => _unsupportedFirmwareEventsController.stream;

  void addWearable(Wearable wearable) {
    // 1) Fast path: ignore duplicates and push into lists/maps synchronously
    if (_wearables.any((w) => w.deviceId == wearable.deviceId)) {
      return;
    }

    _wearables.add(wearable);

    // Init SensorConfigurationProvider synchronously (no awaits here)
    if (wearable is SensorConfigurationManager) {
      _ensureSensorConfigProvider(wearable);
      final notifier = _sensorConfigurationProviders[wearable]!;
      for (final config in (wearable as SensorConfigurationManager).sensorConfigurations) {
        if (notifier.getSelectedConfigurationValue(config) == null && config.values.isNotEmpty) {
          notifier.addSensorConfiguration(config, config.values.first);
        }
      }
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
    if (wearable is StereoDevice) {
      Future.microtask(() => _maybeAutoPairStereoAsync(wearable as StereoDevice));
    }

    // Firmware support check (if applicable)
    if (wearable is DeviceFirmwareVersion) {
      Future.microtask(() => _maybeEmitUnsupportedFirmwareAsync(wearable as DeviceFirmwareVersion));
    }
  }

  // --- Helpers ---------------------------------------------------------------

  void _ensureSensorConfigProvider(Wearable wearable) {
    if (!_sensorConfigurationProviders.containsKey(wearable)) {
      _sensorConfigurationProviders[wearable] = SensorConfigurationProvider(
        sensorConfigurationManager: wearable as SensorConfigurationManager,
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
      final possiblePairs = await WearableManager().findValidPairsFor(stereo, stereoList);

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
  Future<void> _maybeEmitUnsupportedFirmwareAsync(DeviceFirmwareVersion dev) async {
    try {
      // In your abstraction, isFirmwareSupported is a Future<bool> getter.
      final supportStatus = await dev.checkFirmwareSupport();
      switch (supportStatus) {
        case FirmwareSupportStatus.supported:
          // All good, nothing to do.
          break;
        case FirmwareSupportStatus.tooNew:
          _unsupportedFirmwareEventsController.add(FirmwareTooNewEvent(dev as Wearable));
          break;
        case FirmwareSupportStatus.unsupported:
          _unsupportedFirmwareEventsController.add(FirmwareUnsupportedEvent(dev as Wearable));
          break;
        case FirmwareSupportStatus.tooOld:
          _unsupportedFirmwareEventsController.add(FirmwareTooOldEvent(dev as Wearable));
        case FirmwareSupportStatus.unknown:
          logger.w('Firmware support unknown for ${(dev as Wearable).name}');
          break;
      }
    } catch (e, st) {
      logger.w('Firmware check failed for ${(dev as Wearable).name}: $e\n$st');
    }
  }

  void removeWearable(Wearable wearable) {
    _wearables.remove(wearable);
    _sensorConfigurationProviders.remove(wearable);
    notifyListeners();
  }

  SensorConfigurationProvider getSensorConfigurationProvider(Wearable wearable) {
    if (!_sensorConfigurationProviders.containsKey(wearable)) {
      throw Exception('No SensorConfigurationProvider found for the given wearable: ${wearable.name}');
    }
    return _sensorConfigurationProviders[wearable]!;
  }
}
