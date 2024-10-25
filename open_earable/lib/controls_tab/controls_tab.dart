import 'package:flutter/material.dart';
import 'package:open_earable/ble/ble_controller.dart';
import 'package:open_earable/controls_tab/views/audio_and_led.dart';
import 'package:open_earable/controls_tab/views/connect_and_configure.dart';
import 'package:provider/provider.dart';
import 'dart:async';

class ControlTab extends StatefulWidget {
  const ControlTab({super.key});

  @override
  State<ControlTab> createState() => _ControlTabState();
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
        onTap: () => FocusScope.of(context).unfocus(),
        child: Selector<BluetoothController, bool>(
          selector: (context, controller) => controller.isV2,
          builder: (context, isV2, child) {
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  height: 5,
                ),
                ConnectAndConfigure(),
                AudioAndLed(),
              ],
            );
          },
        ),
      ),
    );
  }
}
