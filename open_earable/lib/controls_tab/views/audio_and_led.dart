import 'package:flutter/material.dart';
import 'package:open_earable/ble/ble_controller.dart';
import 'package:open_earable/controls_tab/views/audio_player.dart';
import 'package:open_earable/controls_tab/views/led_color.dart';
import 'package:provider/provider.dart';

class AudioAndLed extends StatelessWidget {
  const AudioAndLed({super.key});

  @override
  Widget build(BuildContext context) {
    return Selector<BluetoothController, bool>(
      selector: (context, controller) => controller.isV2,
      builder: (context, isV2, child) {
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (!isV2) AudioPlayerCard(),
            LedColorCard(),
          ],
        );
      },
    );
  }
}
