import 'package:flutter/foundation.dart';

/// Platform availability for app-local microphone capture.
///
/// macOS is disabled because the current recorder plugin can hang while
/// stopping file-backed microphone sessions on that platform.
class AudioInputAvailability {
  /// Whether local microphone selection, monitoring, and recording are enabled.
  static bool get isSupported {
    if (kIsWeb) {
      return true;
    }
    return defaultTargetPlatform != TargetPlatform.macOS;
  }
}
