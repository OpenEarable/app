import 'package:flutter/material.dart';
import 'package:open_earable/ble/ble_controller.dart';
import 'package:open_earable_flutter/src/open_earable_flutter.dart';
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
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  height: 5,
                ),
                ConnectCard(),
                SensorControlCard(),
                //AudioPlayerCard(_openEarable),
                LEDColorCard(),
              ],
            )));
  }
}
