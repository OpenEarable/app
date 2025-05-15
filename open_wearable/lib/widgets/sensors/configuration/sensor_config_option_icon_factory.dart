import 'package:flutter/material.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart';

IconData? getSensorConfigurationOptionIcon(SensorConfigurationOption option) {
  if (option is RecordSensorConfigOption) {
    return Icons.sd_card;
  } else if (option is StreamSensorConfigOption) {
    return Icons.bluetooth;
  }

  return null;
}
