import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart';
import 'package:open_wearable/widgets/devices/device_detail/device_detail_page.dart';

Future<void> showDeviceDetailDialog(
  BuildContext context, {
  required Wearable device,
}) {
  return showGeneralDialog<void>(
    context: context,
    pageBuilder: (dialogContext, animation1, animation2) {
      final mediaQuery = MediaQuery.of(dialogContext);
      final size = mediaQuery.size;
      final availableWidth = math.max(320.0, size.width - 48);
      final availableHeight = math.max(400.0, size.height - 48);

      return SafeArea(
        child: Center(
          child: SizedBox(
            width: math.min(980.0, availableWidth),
            height: math.min(size.height * 0.9, availableHeight),
            child: DeviceDetailPage(device: device),
          ),
        ),
      );
    },
  );
}
