import 'package:flutter/material.dart';
import 'package:open_earable/ble/ble_controller.dart';
import 'package:open_earable/controls_tab/views/connect.dart';
import 'package:open_earable/controls_tab/views/sensor_control/sensor_control.dart';
import 'package:open_earable/controls_tab/views/v1_connect.dart';
import 'package:open_earable/controls_tab/views/v1_sensor_configuration.dart';
import 'package:provider/provider.dart';

class ConnectAndConfigure extends StatelessWidget {
  const ConnectAndConfigure({super.key});

  @override
  Widget build(BuildContext context) {
    return Selector<BluetoothController, bool>(
      selector: (context, controller) => controller.isV2,
      builder: (context, isV2, child) {
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            isV2 ? ConnectCard() : V1ConnectCard(),
            isV2 ? SensorControlCard() : V1SensorConfigurationCard(),
          ],
        );
      },
    );
  }
}
