import 'package:flutter/material.dart';
import 'package:open_earable_flutter/src/open_earable_flutter.dart';
import 'views/sensor_configuration.dart';
import 'views/connect.dart';
import 'views/led_color.dart';
import 'views/audio_player.dart';
import 'dart:async';
import 'models/open_earable_settings.dart';

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
  void didChangeDependencies() {
    super.didChangeDependencies();
    _connectionStateSubscription =
        _openEarable.bleManager.connectionStateStream.listen((connected) {
      OpenEarableSettings().resetState();
      setState(() {
        this.connected = connected;

        if (connected) {
          getNameAndSOC();
        }
      });
    });
  }

  @override
  void initState() {
    super.initState();
    connected = _openEarable.bleManager.connected;
    if (connected) {
      getNameAndSOC();
    }
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
