import 'dart:async';

import 'package:flutter/services.dart';

class AppBackgroundExecutionBridge {
  static const MethodChannel _channel = MethodChannel(
    'edu.kit.teco.open_wearable/lifecycle',
  );
  static bool _methodCallHandlerInitialized = false;
  static FutureOr<void> Function(String source)? _onAppTerminating;

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

  static void setAppTerminatingHandler(
    FutureOr<void> Function(String source)? handler,
  ) {
    _onAppTerminating = handler;
    if (!_methodCallHandlerInitialized) {
      _channel.setMethodCallHandler(_handleMethodCall);
      _methodCallHandlerInitialized = true;
    }
  }

  static Future<void> _handleMethodCall(MethodCall call) async {
    if (call.method != 'appTerminating') {
      return;
    }

    final dynamic args = call.arguments;
    final source =
        args is Map ? args['source']?.toString() ?? 'unknown' : 'unknown';
    await _onAppTerminating?.call(source);
  }
}
