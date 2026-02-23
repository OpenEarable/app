import 'package:flutter/services.dart';

/// Best-effort platform bridge for temporary background execution windows.
///
/// Used when the app needs short background time for sensor shutdown or
/// recorder-related handoff.
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
