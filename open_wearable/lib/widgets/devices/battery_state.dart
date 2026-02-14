import 'package:flutter/material.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart';

class BatteryStateView extends StatefulWidget {
  final Wearable device;
  final bool showBackground;

  const BatteryStateView({
    super.key,
    required this.device,
    this.showBackground = true,
  });

  @override
  State<BatteryStateView> createState() => _BatteryStateViewState();
}

class _BatteryStateViewState extends State<BatteryStateView> {
  bool _hasBatteryLevel = false;
  bool _hasPowerStatus = false;
  Stream<int>? _batteryPercentageStream;
  Stream<BatteryPowerStatus>? _powerStatusStream;

  @override
  void initState() {
    super.initState();
    _resolveBatteryStreams();
  }

  @override
  void didUpdateWidget(covariant BatteryStateView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.device != widget.device) {
      _resolveBatteryStreams();
    }
  }

  void _resolveBatteryStreams() {
    _hasBatteryLevel = widget.device.hasCapability<BatteryLevelStatus>();
    _hasPowerStatus = widget.device.hasCapability<BatteryLevelStatusService>();

    _batteryPercentageStream = _hasBatteryLevel
        ? widget.device
            .requireCapability<BatteryLevelStatus>()
            .batteryPercentageStream
        : null;

    _powerStatusStream = _hasPowerStatus
        ? widget.device
            .requireCapability<BatteryLevelStatusService>()
            .powerStatusStream
        : null;
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasBatteryLevel && !_hasPowerStatus) {
      return const SizedBox.shrink();
    }

    if (_hasBatteryLevel && _hasPowerStatus) {
      return StreamBuilder<int>(
        stream: _batteryPercentageStream,
        builder: (context, batterySnapshot) {
          return StreamBuilder<BatteryPowerStatus>(
            stream: _powerStatusStream,
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
