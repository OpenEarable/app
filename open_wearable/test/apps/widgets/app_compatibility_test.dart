import 'package:flutter_test/flutter_test.dart';
import 'package:open_wearable/apps/widgets/app_compatibility.dart';

void main() {
  group('wearableNameStartsWithPrefix', () {
    test('matches OpenRing prefixes for raw bcl names', () {
      expect(wearableNameStartsWithPrefix('bcl-1234', 'OpenRing'), isTrue);
      expect(wearableNameStartsWithPrefix('BCL_9876', 'openring'), isTrue);
    });

    test('still matches raw names directly', () {
      expect(
        wearableNameStartsWithPrefix('OpenEarable-2-L', 'OpenEarable'),
        isTrue,
      );
    });
  });

  test('wearableIsCompatibleWithApp accepts OpenRing with bcl name', () {
    expect(
      wearableIsCompatibleWithApp(
        wearableName: 'bcl-0001',
        supportedDevicePrefixes: const ['OpenRing'],
      ),
      isTrue,
    );
  });

  test('hasConnectedWearableForPrefix supports OpenRing prefixes', () {
    expect(
      hasConnectedWearableForPrefix(
        devicePrefix: 'OpenRing',
        connectedWearableNames: const ['bcl-0012'],
      ),
      isTrue,
    );
  });
}
