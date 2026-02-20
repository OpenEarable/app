import 'package:flutter/services.dart';

class AppBackgroundExecutionBridge {
  static const MethodChannel _channel = MethodChannel(
    'edu.kit.teco.open_wearable/lifecycle',
  );

  static Future<void> beginSensorShutdownWindow() async {
    try {
      await _channel.invokeMethod<void>('beginBackgroundExecution');
    } catch (_) {
      // Best-effort bridge. Missing plugin / unsupported platform is fine.
    }
  }

  static Future<void> endSensorShutdownWindow() async {
    try {
      await _channel.invokeMethod<void>('endBackgroundExecution');
    } catch (_) {
      // Best-effort bridge. Missing plugin / unsupported platform is fine.
    }
  }
}
