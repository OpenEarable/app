import 'package:flutter/foundation.dart';

/// Whether EarStreAM can uphold its audio, credential-storage, and cloud
/// contracts on the current OpenWearables host platform.
///
/// Linux is excluded because `flutter_tts` has no Linux implementation. Web is
/// excluded because EarStreAM's third-party cloud APIs are called directly and
/// do not provide a dependable browser CORS contract. Keeping the in-app out
/// of the catalogue on those platforms is safer than exposing a local-only or
/// cloud choice that may fail after a session has started.
bool isEarstreamHostPlatformSupported({
  bool? isWeb,
  TargetPlatform? platform,
}) {
  if (isWeb ?? kIsWeb) return false;

  return switch (platform ?? defaultTargetPlatform) {
    TargetPlatform.android ||
    TargetPlatform.iOS ||
    TargetPlatform.macOS ||
    TargetPlatform.windows =>
      true,
    TargetPlatform.linux || TargetPlatform.fuchsia => false,
  };
}
