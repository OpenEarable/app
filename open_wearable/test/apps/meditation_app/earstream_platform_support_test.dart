import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_wearable/apps/meditation_app/model/earstream_platform_support.dart';

void main() {
  group('EarStreAM host-platform support', () {
    for (final platform in <TargetPlatform>[
      TargetPlatform.android,
      TargetPlatform.iOS,
      TargetPlatform.macOS,
      TargetPlatform.windows,
    ]) {
      test('supports ${platform.name}', () {
        expect(
          isEarstreamHostPlatformSupported(
            isWeb: false,
            platform: platform,
          ),
          isTrue,
        );
      });
    }

    for (final platform in <TargetPlatform>[
      TargetPlatform.linux,
      TargetPlatform.fuchsia,
    ]) {
      test('does not support ${platform.name}', () {
        expect(
          isEarstreamHostPlatformSupported(
            isWeb: false,
            platform: platform,
          ),
          isFalse,
        );
      });
    }

    test('does not support web regardless of its reported target platform', () {
      for (final platform in TargetPlatform.values) {
        expect(
          isEarstreamHostPlatformSupported(
            isWeb: true,
            platform: platform,
          ),
          isFalse,
        );
      }
    });
  });
}
