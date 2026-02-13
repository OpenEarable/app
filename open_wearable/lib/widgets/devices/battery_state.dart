import 'package:flutter/material.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart';

class BatteryStateView extends StatelessWidget {
  final Wearable _device;

  const BatteryStateView({super.key, required Wearable device})
      : _device = device;

  @override
  Widget build(BuildContext context) {
    final hasBatteryLevel = _device.hasCapability<BatteryLevelStatus>();
    final hasPowerStatus = _device.hasCapability<BatteryLevelStatusService>();

    if (!hasBatteryLevel && !hasPowerStatus) {
      return const SizedBox.shrink();
    }

    if (hasBatteryLevel && hasPowerStatus) {
      return StreamBuilder<int>(
        stream: _device
            .requireCapability<BatteryLevelStatus>()
            .batteryPercentageStream,
        builder: (context, batterySnapshot) {
          return StreamBuilder<BatteryPowerStatus>(
            stream: _device
                .requireCapability<BatteryLevelStatusService>()
                .powerStatusStream,
            builder: (context, powerSnapshot) {
              return _BatteryBadge(
                batteryLevel: batterySnapshot.data,
                powerStatus: powerSnapshot.data,
                isLoading: !batterySnapshot.hasData && !powerSnapshot.hasData,
              );
            },
          );
        },
      );
    }

    if (hasPowerStatus) {
      return StreamBuilder<BatteryPowerStatus>(
        stream: _device
            .requireCapability<BatteryLevelStatusService>()
            .powerStatusStream,
        builder: (context, snapshot) {
          return _BatteryBadge(
            batteryLevel: null,
            powerStatus: snapshot.data,
            isLoading: !snapshot.hasData,
          );
        },
      );
    }

    return StreamBuilder<int>(
      stream: _device
          .requireCapability<BatteryLevelStatus>()
          .batteryPercentageStream,
      builder: (context, snapshot) {
        return _BatteryBadge(
          batteryLevel: snapshot.data,
          isLoading: !snapshot.hasData,
        );
      },
    );
  }
}

class _BatteryBadge extends StatelessWidget {
  final int? batteryLevel;
  final BatteryPowerStatus? powerStatus;
  final bool isLoading;

  const _BatteryBadge({
    required this.batteryLevel,
    this.powerStatus,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final normalizedLevel = batteryLevel?.clamp(0, 100);

    final batteryPresent = powerStatus?.batteryPresent ?? true;
    final charging = powerStatus?.chargeState == ChargeState.charging;
    final Color foregroundColor = colors.primary;

    final Color backgroundColor = foregroundColor.withValues(alpha: 0.12);
    final Color borderColor = foregroundColor.withValues(alpha: 0.24);

    final IconData icon;
    final String label;

    if (!batteryPresent) {
      icon = Icons.battery_unknown_rounded;
      label = "No battery";
    } else if (charging) {
      icon = Icons.battery_charging_full_rounded;
      label = normalizedLevel == null ? "Charging" : "$normalizedLevel%";
    } else if (normalizedLevel != null) {
      icon = _batteryIconForPercent(normalizedLevel);
      label = "$normalizedLevel%";
    } else {
      icon = _batteryIconForChargeLevel(powerStatus?.chargeLevel);
      label = switch (powerStatus?.chargeLevel) {
        BatteryChargeLevel.critical => "Critical",
        BatteryChargeLevel.low => "Low",
        BatteryChargeLevel.good => "Battery",
        _ => "--",
      };
    }

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
          if (isLoading)
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: foregroundColor,
              ),
            )
          else
            Icon(icon, size: 15, color: foregroundColor),
          const SizedBox(width: 6),
          Text(
            label,
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
