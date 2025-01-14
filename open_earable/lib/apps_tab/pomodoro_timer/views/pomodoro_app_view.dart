import 'package:flutter/material.dart';
import 'package:open_earable/apps_tab/pomodoro_timer/views/new_pomodoro_body.dart';
import 'package:open_earable/apps_tab/pomodoro_timer/views/pomodoro_app_settings.dart';
import 'package:open_earable/apps_tab/pomodoro_timer/views/pomodoro_app_settings_view.dart';
import 'package:open_earable/apps_tab/pomodoro_timer/views/pomodoro_info_view.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart';
import 'package:provider/provider.dart';

import '../../../ble/ble_controller.dart';
import '../../../shared/earable_not_connected_warning.dart';

/// The main view for the Pomodoro Timer app.
class PomodoroAppView extends StatelessWidget {
  final OpenEarable openEarable;
  PomodoroAppView(this.openEarable, {super.key});
  final PomodoroAppSettings pomodoroAppSettings = PomodoroAppSettings();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Pomodoro Timer'),
        actions: [
          IconButton(
            icon: Icon(Icons.info),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => PomodoroInfoView(),
                ),
              );
            },
          ),
          IconButton(
            icon: Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => PomodoroAppSettingsView(pomodoroAppSettings),
                ),
              );
            },
          ),
        ],
      ),
      body: !Provider.of<BluetoothController>(context).connected
          ? EarableNotConnectedWarning()
          : Column(
        children: [
          PomodoroAppBody(openEarable, pomodoroAppSettings),
        ],
      ),
    );
  }
}
