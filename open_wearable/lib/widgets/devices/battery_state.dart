import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart';

class BatteryStateView extends StatelessWidget {
  final Wearable _device;

  const BatteryStateView({super.key, required Wearable device}) : _device = device;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_device is BatteryLevelService)
          StreamBuilder(
            stream: (_device as BatteryLevelService).batteryPercentageStream,
            builder: (context, snapshot) {
              if (snapshot.hasData) {
                return Text("${snapshot.data}%");
              } else {
                return PlatformCircularProgressIndicator();
              }
            },
          ),
        if (_device is BatteryLevelStatusService)
          StreamBuilder(
            stream: (_device as BatteryLevelStatusService).powerStatusStream,
            builder: (context, snapshot) {
              if (snapshot.hasData) {
                if (!snapshot.data!.batteryPresent) {
                  return Icon(Icons.battery_unknown_rounded);
                }

                if (snapshot.data!.chargeState == ChargeState.charging) {
                  return Icon(Icons.battery_charging_full_rounded);
                }

                switch (snapshot.data!.chargeLevel) {
                case BatteryChargeLevel.good:
                  return Icon(Icons.battery_full);
                case BatteryChargeLevel.low:
                  return Icon(Icons.battery_3_bar_rounded);
                case BatteryChargeLevel.critical:
                  return Icon(Icons.battery_1_bar_rounded);
                case BatteryChargeLevel.unknown:
                  return Icon(Icons.battery_unknown);
                }
              } else {
                return PlatformCircularProgressIndicator();
              }
            },
          )
        else if (_device is BatteryLevelService)
          StreamBuilder(
            stream: (_device as BatteryLevelService).batteryPercentageStream,
            builder: (context, snapshot) {
              if (snapshot.hasData) {
                return Icon(getBatteryIcon(snapshot.data!));
              } else {
                return PlatformCircularProgressIndicator();
              }
            },
          ),
      ],
    );
  }

  IconData getBatteryIcon(int batteryLevel) {
    int batteryBars = (batteryLevel / 12.5).toInt();

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
    }

    return Icons.battery_unknown_rounded;
  }
}
