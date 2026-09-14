import 'package:flutter_test/flutter_test.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart';
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

  group('wearableSatisfiesAppRequirements', () {
    test('accepts a supported wearable with all required capabilities', () {
      final wearable = _FakeWearable(name: 'OpenEarable-2-L');
      wearable.registerCapability<_ExampleCapability>(
        const _ExampleCapability(),
      );

      expect(
        wearableSatisfiesAppRequirements(
          wearable: wearable,
          supportedDevicePrefixes: const ['OpenEarable'],
          requiredCapabilities: [
            WearableCapabilityRequirement.capability<_ExampleCapability>(
              label: 'example capability',
            ),
          ],
        ),
        isTrue,
      );
    });

    test('rejects a supported wearable missing a required capability', () {
      final wearable = _FakeWearable(name: 'OpenEarable-2-L');

      final requirement =
          WearableCapabilityRequirement.capability<_ExampleCapability>(
        label: 'example capability',
      );

      expect(
        wearableSatisfiesAppRequirements(
          wearable: wearable,
          supportedDevicePrefixes: const ['OpenEarable'],
          requiredCapabilities: [requirement],
        ),
        isFalse,
      );
      expect(
        missingWearableCapabilityRequirements(
          wearable: wearable,
          requirements: [requirement],
        ),
        [requirement],
      );
    });
  });
}

class _FakeWearable extends Wearable {
  _FakeWearable({required super.name})
      : super(disconnectNotifier: WearableDisconnectNotifier());

  @override
  String get deviceId => 'fake-device';

  @override
  Future<void> disconnect() async {}
}

class _ExampleCapability {
  const _ExampleCapability();
}
