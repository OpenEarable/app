import 'package:flutter/material.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart' hide logger;
import 'package:open_wearable/widgets/devices/stereo_position_badge.dart';

class StereoPosLabel extends StatelessWidget {
  final StereoDevice device;

  const StereoPosLabel({super.key, required this.device});

  @override
  Widget build(BuildContext context) {
    return StereoPositionBadge(device: device);
  }
}
