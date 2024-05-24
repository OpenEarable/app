import 'package:flutter/material.dart';
import 'package:open_earable/ble/ble_controller.dart';
import 'package:open_earable/controls_tab/models/open_earable_settings_v2.dart';
import 'package:provider/provider.dart';

class EarableNotConnectedWarning extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.warning,
                size: 48,
                color: Colors.red,
              ),
              SizedBox(height: 16),
              Center(
                child: Text(
                  "Not connected to\nOpenEarable " +
                      (OpenEarableSettingsV2().selectedButtonIndex == 0
                          ? "(left)"
                          : "(right)"),
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
