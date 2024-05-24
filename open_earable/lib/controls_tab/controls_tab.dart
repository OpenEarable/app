import 'package:flutter/material.dart';
import 'package:open_earable/ble/ble_controller.dart';
import 'package:open_earable/controls_tab/views/audio_player.dart';
import 'package:open_earable/controls_tab/views/v1_connect.dart';
import 'package:open_earable/controls_tab/views/v1_sensor_configuration.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import 'views/sensor_control/sensor_control.dart';
import 'views/connect.dart';
import 'views/led_color.dart';
import 'dart:async';

class ControlTab extends StatefulWidget {
  @override
  _ControlTabState createState() => _ControlTabState();
}

class _ControlTabState extends State<ControlTab> {
  StreamSubscription<bool>? _connectionStateSubscription;
  StreamSubscription<dynamic>? _batteryLevelSubscription;
  bool earableCharging = false;

  @override
  void dispose() {
    super.dispose();
    _connectionStateSubscription?.cancel();
    _batteryLevelSubscription?.cancel();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
        child: GestureDetector(
            onTap: () => Platform.isIOS
                ? FocusScope.of(context).requestFocus(FocusNode())
                : FocusScope.of(context).unfocus(),
            child: Selector<BluetoothController, bool>(
                selector: (context, controller) => controller.isV2,
                builder: (context, isV2, child) {
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        height: 5,
                      ),
                      isV2 ? ConnectCard() : V1ConnectCard(),
                      isV2 ? SensorControlCard() : V1SensorConfigurationCard(),
                      if (!isV2)
                        AudioPlayerCard(Provider.of<BluetoothController>(
                                context,
                                listen: false)
                            .openEarableLeft),
                      LEDColorCard(),
                    ],
                  );
                })));
  }
}
