import 'package:open_earable_flutter/open_earable_flutter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_wearable/apps/models/app_compatibility.dart';

class _FakeSensor extends Sensor<SensorDoubleValue> {
  const _FakeSensor({
    required super.sensorName,
    required super.chartTitle,
  }) : super(shortChartTitle: 'fake');

  @override
  List<String> get axisNames => const ['x'];

  @override
  List<String> get axisUnits => const ['u'];

  @override
  Stream<SensorDoubleValue> get sensorStream => Stream.empty();
}

class _FakeSensorManager implements SensorManager {
  @override
  final List<Sensor> sensors;

  const _FakeSensorManager(this.sensors);
}

class _FakeCapability {
  final String mode;

  const _FakeCapability(this.mode);
}

class _FakeWearable extends Wearable {
  @override
  final String deviceId;

  _FakeWearable({
    required super.name,
    required this.deviceId,
  }) : super(disconnectNotifier: WearableDisconnectNotifier());

  @override
  Future<void> disconnect() async {}
}

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
    final wearable = _FakeWearable(
      name: 'bcl-0001',
      deviceId: 'ring-1',
    );

    expect(
      wearableIsCompatibleWithApp(
        wearable: wearable,
        supportedDevices: const [
          AppSupportOption(
            label: 'OpenRing',
            requirement: AppRequirement.nameStartsWith('OpenRing'),
          ),
        ],
      ),
      isTrue,
    );
  });

  test('hasConnectedWearableForOption supports OpenRing prefixes', () {
    final wearable = _FakeWearable(
      name: 'bcl-0012',
      deviceId: 'ring-2',
    );

    expect(
      hasConnectedWearableForOption(
        supportedDevice: const AppSupportOption(
          label: 'OpenRing',
          requirement: AppRequirement.nameStartsWith('OpenRing'),
        ),
        connectedWearables: [wearable],
      ),
      isTrue,
    );
  });

  test('supports composite requirements with capability presence', () {
    final compatibleWearable = _FakeWearable(
      name: 'OpenEarable-2',
      deviceId: 'oe-1',
    )..registerCapability(const _FakeCapability('tracking'));
    final incompatibleWearable = _FakeWearable(
      name: 'OpenEarable-2',
      deviceId: 'oe-2',
    );

    final supportedDevice = AppSupportOption(
      label: 'Tracking Earable',
      requirement: AppRequirement.allOf([
        AppRequirement.nameStartsWith('OpenEarable'),
        AppRequirement.hasCapability<_FakeCapability>(),
      ]),
    );

    expect(
      wearableIsCompatibleWithApp(
        wearable: compatibleWearable,
        supportedDevices: [supportedDevice],
      ),
      isTrue,
    );
    expect(
      wearableIsCompatibleWithApp(
        wearable: incompatibleWearable,
        supportedDevices: [supportedDevice],
      ),
      isFalse,
    );
  });

  test('supports matching specific capability property values', () {
    final leftWearable = _FakeWearable(
      name: 'OpenEarable-Left',
      deviceId: 'oe-left',
    )..registerCapability(const _FakeCapability('left'));
    final rightWearable = _FakeWearable(
      name: 'OpenEarable-Right',
      deviceId: 'oe-right',
    )..registerCapability(const _FakeCapability('right'));

    final supportedDevice = AppSupportOption(
      label: 'Left tracker',
      requirement: AppRequirement.capability<_FakeCapability>(
        _matchesLeftCapability,
      ),
    );

    expect(
      wearableIsCompatibleWithApp(
        wearable: leftWearable,
        supportedDevices: [supportedDevice],
      ),
      isTrue,
    );
    expect(
      wearableIsCompatibleWithApp(
        wearable: rightWearable,
        supportedDevices: [supportedDevice],
      ),
      isFalse,
    );
  });

  test('supports matching sensors without explicit SensorManager requirement',
      () {
    final compatibleWearable = _FakeWearable(
      name: 'OpenEarable-2',
      deviceId: 'oe-3',
    )..registerCapability<SensorManager>(
        const _FakeSensorManager([
          _FakeSensor(
            sensorName: 'accel',
            chartTitle: 'Acceleration',
          ),
        ]),
      );
    final incompatibleWearable = _FakeWearable(
      name: 'OpenEarable-2',
      deviceId: 'oe-4',
    )..registerCapability<SensorManager>(
        const _FakeSensorManager([
          _FakeSensor(
            sensorName: 'gyroscope',
            chartTitle: 'Gyro',
          ),
        ]),
      );

    final supportedDevice = AppSupportOption(
      label: 'OpenEarable',
      requirement: AppRequirement.allOf([
        AppRequirement.nameStartsWith('OpenEarable'),
        AppRequirement.hasSensorByAliases(['accelerometer', 'accel', 'acc']),
      ]),
    );

    expect(
      wearableIsCompatibleWithApp(
        wearable: compatibleWearable,
        supportedDevices: [supportedDevice],
      ),
      isTrue,
    );
    expect(
      wearableIsCompatibleWithApp(
        wearable: incompatibleWearable,
        supportedDevices: [supportedDevice],
      ),
      isFalse,
    );
  });
}

bool _matchesLeftCapability(_FakeCapability capability, Wearable wearable) {
  return capability.mode == 'left';
}
