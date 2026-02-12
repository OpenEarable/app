import 'package:flutter_test/flutter_test.dart';
import 'package:open_wearable/view_models/sensor_configuration_storage.dart';

void main() {
  group('SensorConfigurationStorage scope helpers', () {
    test('normalizes device names and firmware versions for scope keys', () {
      expect(
        SensorConfigurationStorage.normalizeDeviceNameForScope(
          ' OpenRing Pro (Left) ',
        ),
        'openring_pro__left_',
      );
      expect(
        SensorConfigurationStorage.normalizeFirmwareVersionForScope(
          ' V1.2.3-beta ',
        ),
        '1_2_3-beta',
      );
    });

    test('builds name and firmware scopes', () {
      final nameScope =
          SensorConfigurationStorage.deviceNameScope('OpenRing 2');
      final firmwareScope = SensorConfigurationStorage.deviceNameFirmwareScope(
        deviceName: 'OpenRing 2',
        firmwareVersion: 'v1.0.0',
      );

      expect(nameScope, 'name_openring_2');
      expect(firmwareScope, 'name_openring_2__fw_1_0_0');
    });

    test('returns null firmware scope when firmware version is missing', () {
      expect(
        SensorConfigurationStorage.deviceNameFirmwareScope(
          deviceName: 'OpenRing 2',
          firmwareVersion: null,
        ),
        isNull,
      );
      expect(
        SensorConfigurationStorage.deviceNameFirmwareScope(
          deviceName: 'OpenRing 2',
          firmwareVersion: '   ',
        ),
        isNull,
      );
    });
  });

  group('DeviceProfileScopeMatch', () {
    test('matches firmware-scoped keys when firmware is available', () {
      final match = DeviceProfileScopeMatch.forDevice(
        deviceName: 'OpenRing 2',
        firmwareVersion: 'v1.0.0',
      );
      final firmwareKey = SensorConfigurationStorage.buildScopedKey(
        scope: match.saveScope,
        name: 'Default',
      );
      final nameOnlyKey = SensorConfigurationStorage.buildScopedKey(
        scope: SensorConfigurationStorage.deviceNameScope('OpenRing 2'),
        name: 'Default',
      );

      expect(match.saveScope, 'name_openring_2__fw_1_0_0');
      expect(match.matchesScopedKey(firmwareKey), isTrue);
      expect(match.matchesScopedKey(nameOnlyKey), isFalse);
    });

    test('matches name-scoped keys when firmware is unavailable', () {
      final match = DeviceProfileScopeMatch.forDevice(
        deviceName: 'OpenRing 2',
        firmwareVersion: null,
      );
      final nameOnlyKey = SensorConfigurationStorage.buildScopedKey(
        scope: match.saveScope,
        name: 'Default',
      );
      final otherNameKey = SensorConfigurationStorage.buildScopedKey(
        scope: SensorConfigurationStorage.deviceNameScope('OpenRing X'),
        name: 'Default',
      );

      expect(match.saveScope, 'name_openring_2');
      expect(match.matchesScopedKey(nameOnlyKey), isTrue);
      expect(match.matchesScopedKey(otherNameKey), isFalse);
    });

    test('does not match legacy id-scoped keys', () {
      final match = DeviceProfileScopeMatch.forDevice(
        deviceName: 'OpenRing 2',
        firmwareVersion: '1.0.0',
      );
      final legacyScopedKey = SensorConfigurationStorage.buildScopedKey(
        scope: 'device_1234',
        name: 'OldProfile',
      );

      expect(match.matchesScopedKey(legacyScopedKey), isFalse);
      expect(match.allowsKey(legacyScopedKey), isFalse);
    });

    test('allows legacy unscoped keys but rejects wrong scoped keys', () {
      final match = DeviceProfileScopeMatch.forDevice(
        deviceName: 'OpenRing 2',
        firmwareVersion: '1.0.0',
      );
      final wrongScopedKey = SensorConfigurationStorage.buildScopedKey(
        scope: SensorConfigurationStorage.deviceNameFirmwareScope(
          deviceName: 'OpenRing X',
          firmwareVersion: '1.0.0',
        )!,
        name: 'Profile',
      );

      expect(match.allowsKey('legacy_shared_profile'), isTrue);
      expect(match.allowsKey(wrongScopedKey), isFalse);
    });
  });
}
