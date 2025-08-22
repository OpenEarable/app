import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart';

class StereoPosLabel extends StatelessWidget {
  final StereoDevice device;

  const StereoPosLabel({super.key, required this.device});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: device.position,
      builder: (context, snapshot) {
        if (snapshot.connectionState ==
            ConnectionState.waiting) {
          return PlatformCircularProgressIndicator();
        }
        if (snapshot.hasError) {
          logger.e("Error fetching device position: ${snapshot.error}");
          return PlatformText("Error: ${snapshot.error}");
        }
        if (!snapshot.hasData) {
          return PlatformText("N/A");
        }
        if (snapshot.data == null) {
          return PlatformText("N/A");
        }
        switch (snapshot.data) {
          case DevicePosition.left:
            return PlatformText("Left");
          case DevicePosition.right:
            return PlatformText("Right");
          default:
            return PlatformText("Unknown");
        }
      },
    );
  }
}
