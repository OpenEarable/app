import 'dart:async';

import 'package:flutter/material.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart';

class BatteryStateView extends StatefulWidget {
  final Wearable device;
  final bool showBackground;
  final bool liveUpdates;

  const BatteryStateView({
    super.key,
    required this.device,
    this.showBackground = true,
    this.liveUpdates = false,
  });

  @override
  State<BatteryStateView> createState() => _BatteryStateViewState();
}

class _BatteryStateViewState extends State<BatteryStateView> {
  static final Map<String, int> _batteryCacheByDeviceId = <String, int>{};
  static final Map<String, BatteryPowerStatus> _powerCacheByDeviceId =
      <String, BatteryPowerStatus>{};
  static final Set<String> _primedDeviceIds = <String>{};
  static final Map<String, int> _primeAttemptsByDeviceId = <String, int>{};
  static final Map<String, Future<void>> _primeTasksByDeviceId =
      <String, Future<void>>{};
  static const int _maxPrimeAttempts = 3;

  bool _hasBatteryLevel = false;
  bool _hasPowerStatus = false;
  bool _isDisconnected = false;
  bool _isPriming = false;
  Stream<int>? _batteryPercentageStream;
  Stream<BatteryPowerStatus>? _powerStatusStream;
  StreamSubscription<List<Type>>? _capabilitySubscription;
  int _disconnectListenerGeneration = 0;

  @override
  void initState() {
    super.initState();
    _attachDisconnectListener();
    _attachCapabilityListener();
    _resolveBatteryStreams();
  }

  @override
  void didUpdateWidget(covariant BatteryStateView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final deviceChanged = oldWidget.device != widget.device;
    final liveUpdatesChanged = oldWidget.liveUpdates != widget.liveUpdates;
    if (deviceChanged || liveUpdatesChanged) {
      _isDisconnected = false;
      if (deviceChanged) {
        _attachDisconnectListener();
      }
      _attachCapabilityListener();
      _resolveBatteryStreams();
    }
  }

  String get _deviceKey => widget.device.deviceId;

  void _attachDisconnectListener() {
    final listenerGeneration = ++_disconnectListenerGeneration;
    final keyAtListenerRegistration = _deviceKey;
    widget.device.addDisconnectListener(() {
      if (!mounted ||
          listenerGeneration != _disconnectListenerGeneration ||
          _deviceKey != keyAtListenerRegistration) {
        return;
      }
      setState(() {
        _isDisconnected = true;
        _primeAttemptsByDeviceId.remove(keyAtListenerRegistration);
        _batteryPercentageStream = null;
        _powerStatusStream = null;
      });
    });
  }

  void _attachCapabilityListener() {
    _capabilitySubscription?.cancel();
    _capabilitySubscription =
        widget.device.capabilityRegistered.listen((addedCapabilities) {
      if (!mounted || _isDisconnected) {
        return;
      }

      final hasBatteryCapability =
          addedCapabilities.contains(BatteryLevelStatus) ||
              addedCapabilities.contains(BatteryLevelStatusService);
      if (!hasBatteryCapability) {
        return;
      }

      _primeAttemptsByDeviceId.remove(_deviceKey);
      setState(_resolveBatteryStreams);
    });
  }

  int _cacheBatteryLevel(int value) {
    _batteryCacheByDeviceId[_deviceKey] = value;
    return value;
  }

  BatteryPowerStatus _cachePowerStatus(BatteryPowerStatus value) {
    _powerCacheByDeviceId[_deviceKey] = value;
    return value;
  }

  void _resolveBatteryStreams() {
    if (_isDisconnected) {
      _hasBatteryLevel = false;
      _hasPowerStatus = false;
      _isPriming = false;
      _batteryPercentageStream = null;
      _powerStatusStream = null;
      return;
    }

    _hasBatteryLevel = widget.device.hasCapability<BatteryLevelStatus>();
    _hasPowerStatus = widget.device.hasCapability<BatteryLevelStatusService>();

    if (!widget.liveUpdates) {
      _batteryPercentageStream = null;
      _powerStatusStream = null;
      _primeBatteryCacheOnce();
      return;
    }

    _batteryPercentageStream = _hasBatteryLevel
        ? widget.device
            .requireCapability<BatteryLevelStatus>()
            .batteryPercentageStream
            .map(_cacheBatteryLevel)
        : null;

    _powerStatusStream = _hasPowerStatus
        ? widget.device
            .requireCapability<BatteryLevelStatusService>()
            .powerStatusStream
            .map(_cachePowerStatus)
        : null;

    _primeBatteryCacheOnce();
  }

  void _primeBatteryCacheOnce() {
    final key = _deviceKey;
    final device = widget.device;
    final hasBatteryLevel = _hasBatteryLevel;
    final hasPowerStatus = _hasPowerStatus;
    final attempts = _primeAttemptsByDeviceId[key] ?? 0;
    if (_isDisconnected ||
        _primedDeviceIds.contains(key) ||
        _primeTasksByDeviceId.containsKey(key) ||
        attempts >= _maxPrimeAttempts ||
        (!hasBatteryLevel && !hasPowerStatus)) {
      return;
    }

    _primeAttemptsByDeviceId[key] = attempts + 1;
    _isPriming = true;
    if (mounted) {
      setState(() {});
    }

    final task = _primeBatteryCache(
      device: device,
      hasBatteryLevel: hasBatteryLevel,
      hasPowerStatus: hasPowerStatus,
    ).then((loadedAnyValue) {
      if (loadedAnyValue) {
        _primedDeviceIds.add(key);
        _primeAttemptsByDeviceId.remove(key);
        return;
      }
      _schedulePrimeRetry(key);
    }).whenComplete(() {
      _primeTasksByDeviceId.remove(key);
      if (!mounted || _deviceKey != key) {
        return;
      }
      _isPriming = false;
      setState(() {});
    });

    _primeTasksByDeviceId[key] = task;
  }

  void _schedulePrimeRetry(String key) {
    final attempts = _primeAttemptsByDeviceId[key] ?? 0;
    if (attempts >= _maxPrimeAttempts ||
        _primedDeviceIds.contains(key) ||
        _batteryCacheByDeviceId[key] != null ||
        _powerCacheByDeviceId[key] != null) {
      return;
    }

    final delay = Duration(milliseconds: 500 * attempts);
    Future<void>.delayed(delay, () {
      if (!mounted || _isDisconnected || _deviceKey != key) {
        return;
      }
      setState(_resolveBatteryStreams);
    });
  }

  Future<bool> _primeBatteryCache({
    required Wearable device,
    required bool hasBatteryLevel,
    required bool hasPowerStatus,
  }) async {
    var loadedAnyValue = false;

    if (hasBatteryLevel) {
      try {
        final level = await device
            .requireCapability<BatteryLevelStatus>()
            .readBatteryPercentage()
            .timeout(const Duration(seconds: 2));
        _cacheBatteryLevel(level);
        loadedAnyValue = true;
      } catch (_) {
        // Keep quiet: fallback to stream updates.
      }
    }

    if (hasPowerStatus) {
      try {
        final status = await device
            .requireCapability<BatteryLevelStatusService>()
            .readPowerStatus()
            .timeout(const Duration(seconds: 2));
        _cachePowerStatus(status);
        loadedAnyValue = true;
      } catch (_) {
        // Keep quiet: fallback to stream updates.
      }
    }

    return loadedAnyValue;
  }

  @override
  void dispose() {
    _capabilitySubscription?.cancel();
    _capabilitySubscription = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cachedBattery = _batteryCacheByDeviceId[_deviceKey];
    final cachedPower = _powerCacheByDeviceId[_deviceKey];

    if (!_hasBatteryLevel &&
        !_hasPowerStatus &&
        cachedBattery == null &&
        cachedPower == null) {
      return const SizedBox.shrink();
    }

    if (!widget.liveUpdates || _isDisconnected) {
      if (cachedBattery == null && cachedPower == null && !_isPriming) {
        return const SizedBox.shrink();
      }
      return _BatteryBadge(
        batteryLevel: cachedBattery,
        powerStatus: cachedPower,
        isLoading: _isPriming && cachedBattery == null && cachedPower == null,
        showBackground: widget.showBackground,
      );
    }

    if (_hasBatteryLevel && _hasPowerStatus) {
      return StreamBuilder<int>(
        stream: _batteryPercentageStream,
        initialData: cachedBattery,
        builder: (context, batterySnapshot) {
          return StreamBuilder<BatteryPowerStatus>(
            stream: _powerStatusStream,
            initialData: cachedPower,
            builder: (context, powerSnapshot) {
              return _BatteryBadge(
                batteryLevel: batterySnapshot.data,
                powerStatus: powerSnapshot.data,
                isLoading: !batterySnapshot.hasData && !powerSnapshot.hasData,
                showBackground: widget.showBackground,
              );
            },
          );
        },
      );
    }

    if (_hasPowerStatus) {
      return StreamBuilder<BatteryPowerStatus>(
        stream: _powerStatusStream,
        initialData: cachedPower,
        builder: (context, snapshot) {
          return _BatteryBadge(
            batteryLevel: null,
            powerStatus: snapshot.data,
            isLoading: !snapshot.hasData,
            showBackground: widget.showBackground,
          );
        },
      );
    }

    return StreamBuilder<int>(
      stream: _batteryPercentageStream,
      initialData: cachedBattery,
      builder: (context, snapshot) {
        return _BatteryBadge(
          batteryLevel: snapshot.data,
          isLoading: !snapshot.hasData,
          showBackground: widget.showBackground,
        );
      },
    );
  }
}

class _BatteryBadge extends StatelessWidget {
  final int? batteryLevel;
  final BatteryPowerStatus? powerStatus;
  final bool isLoading;
  final bool showBackground;

  const _BatteryBadge({
    required this.batteryLevel,
    this.powerStatus,
    this.isLoading = false,
    this.showBackground = true,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final normalizedLevel = batteryLevel?.clamp(0, 100);

    final batteryPresent = powerStatus?.batteryPresent ?? true;
    final charging = powerStatus?.chargeState == ChargeState.charging;
    final Color foregroundColor = colors.primary;

    final Color backgroundColor =
        showBackground ? colors.surface : Colors.transparent;
    final Color borderColor = foregroundColor.withValues(alpha: 0.42);

    final IconData icon;
    final String label;

    if (normalizedLevel != null) {
      icon = charging
          ? Icons.battery_charging_full_rounded
          : _batteryIconForPercent(normalizedLevel);
      label = "$normalizedLevel%";
    } else if (!batteryPresent) {
      icon = Icons.battery_unknown_rounded;
      label = "No battery";
    } else if (charging) {
      icon = Icons.battery_charging_full_rounded;
      label = "Charging";
    } else {
      icon = _batteryIconForChargeLevel(powerStatus?.chargeLevel);
      label = switch (powerStatus?.chargeLevel) {
        BatteryChargeLevel.critical => "Critical",
        BatteryChargeLevel.low => "Low",
        BatteryChargeLevel.good => "Battery",
        _ => "--",
      };
    }

    final showLoadingPlaceholder =
        isLoading && batteryLevel == null && powerStatus == null;
    final displayIcon =
        showLoadingPlaceholder ? Icons.battery_unknown_rounded : icon;
    final displayLabel = showLoadingPlaceholder ? "..." : label;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(displayIcon, size: 15, color: foregroundColor),
          const SizedBox(width: 6),
          Text(
            displayLabel,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: foregroundColor,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.1,
                ),
          ),
        ],
      ),
    );
  }
}

IconData _batteryIconForChargeLevel(BatteryChargeLevel? chargeLevel) {
  return switch (chargeLevel) {
    BatteryChargeLevel.good => Icons.battery_full_rounded,
    BatteryChargeLevel.low => Icons.battery_3_bar_rounded,
    BatteryChargeLevel.critical => Icons.battery_1_bar_rounded,
    _ => Icons.battery_unknown_rounded,
  };
}

IconData _batteryIconForPercent(int batteryLevel) {
  final batteryBars = (batteryLevel / 12.5).toInt();

  switch (batteryBars) {
    case 0:
      return Icons.battery_0_bar_rounded;
    case 1:
      return Icons.battery_1_bar_rounded;
    case 2:
      return Icons.battery_2_bar_rounded;
    case 3:
      return Icons.battery_3_bar_rounded;
    case 4:
      return Icons.battery_4_bar_rounded;
    case 5:
      return Icons.battery_5_bar_rounded;
    case 6:
      return Icons.battery_6_bar_rounded;
    case 7:
    case 8:
      return Icons.battery_full_rounded;
    default:
      return Icons.battery_unknown_rounded;
  }
}
