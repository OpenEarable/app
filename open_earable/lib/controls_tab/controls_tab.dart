import 'package:flutter/material.dart';
import 'package:open_earable_flutter/src/open_earable_flutter.dart';
import 'dart:io';
import 'views/sensor_control.dart';
import 'views/connect.dart';
import 'views/led_color.dart';
import 'dart:async';

class ControlTab extends StatefulWidget {
  final OpenEarable _openEarable;
  ControlTab(this._openEarable);
  @override
  _ControlTabState createState() => _ControlTabState(_openEarable);
}

class _ControlTabState extends State<ControlTab> {
  final OpenEarable _openEarable;
  _ControlTabState(this._openEarable);

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
                ConnectCard(_openEarable),
                SensorControlCard(_openEarable),
                //AudioPlayerCard(_openEarable),
                LEDColorCard(_openEarable),
              ],
            )));
  }
}
