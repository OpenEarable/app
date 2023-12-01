import 'package:flutter/material.dart';
import 'package:open_earable_flutter/src/open_earable_flutter.dart';
import 'cards/sensor_configuration.dart';
import 'cards/connect.dart';
import 'cards/led_color.dart';
import 'cards/audio_player.dart';
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
  bool connected = false;
  int earableSOC = 0;
  bool earableCharging = false;

  @override
  void dispose() {
    super.dispose();
    _connectionStateSubscription?.cancel();
    _batteryLevelSubscription?.cancel();
  }

  @override
  void initState() {
    _connectionStateSubscription =
        _openEarable.bleManager.connectionStateStream.listen((connected) {
      setState(() {
        this.connected = connected;

        if (connected) {
          getNameAndSOC();
        }
      });
    });
    setState(() {
      connected = _openEarable.bleManager.connected;
      if (connected) {
        getNameAndSOC();
      }
      super.initState();
    });
  }

  void getNameAndSOC() {
    _batteryLevelSubscription = _openEarable.sensorManager
        .getBatteryLevelStream()
        .listen((batteryLevel) {
      setState(() {
        earableSOC = batteryLevel[0].toInt();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
        child: GestureDetector(
            onTap: () => FocusScope.of(context).unfocus(),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  height: 5,
                ),
                ConnectCard(_openEarable, earableSOC),
                SensorConfigurationCard(_openEarable),
                AudioPlayerCard(_openEarable),
                LEDColorCard(_openEarable),
              ],
            )));
  }
}
