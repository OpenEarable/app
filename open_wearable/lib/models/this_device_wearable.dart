import 'dart:async';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart' hide Version, logger;
import 'package:pub_semver/pub_semver.dart';
import 'package:sensors_plus/sensors_plus.dart';

import 'logger.dart';

class ThisDeviceWearable extends Wearable
    implements SensorManager, DeviceFirmwareVersion {
  @override
  final List<Sensor> sensors = [];

  final DeviceProfile deviceProfile;

  ThisDeviceWearable._({
    required super.disconnectNotifier,
    required this.deviceProfile,
  }) : super(name: deviceProfile.displayName);

  static Future<ThisDeviceWearable> create({
    required WearableDisconnectNotifier disconnectNotifier,
  }) async {
    final profile = await DeviceProfile.fetch();
    logger.d('Fetched device profile: $profile');
    final wearable = ThisDeviceWearable._(
      disconnectNotifier: disconnectNotifier,
      deviceProfile: profile,
    );
    await wearable._initSensors();
    return wearable;
  }

  @override
  String get deviceId => deviceProfile.deviceId;

  @override
  Future<void> disconnect() async {
    // TODO: Call disconnect listeners
    return Future.value();
  }

  @override
  String? getWearableIconPath({bool darkmode = false}) {
    return null;
  }

  Future<void> _initSensors() async {
    if (await _isSensorAvailable<GyroscopeEvent>(gyroscopeEventStream())) {
      sensors.add(MockGyroSensor());
    }
    if (await _isSensorAvailable<AccelerometerEvent>(
      accelerometerEventStream(),
    )) {
      sensors.add(MockAccelerometer());
    }
  }

  static Future<bool> _isSensorAvailable<T>(Stream<T> stream) async {
    try {
      await stream.first.timeout(const Duration(milliseconds: 800));
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<FirmwareSupportStatus> checkFirmwareSupport() {
    return Future.value(FirmwareSupportStatus.supported);
  }

  @override
  Future<String?> readDeviceFirmwareVersion() {
    return deviceProfile.osVersion != null
        ? Future.value(deviceProfile.osVersion)
        : Future.error('OS version not available');
  }

  @override
  Future<Version?> readFirmwareVersionNumber() {
    if (deviceProfile.osVersion == null) {
      return Future.error('OS version not available');
    }
    try {
      final version = Version.parse(deviceProfile.osVersion!);
      return Future.value(version);
    } catch (e) {
      return Future.error('Failed to parse OS version: $e');
    }
  }

  @override
  VersionConstraint get supportedFirmwareRange => VersionConstraint.any;
}

class DeviceProfile {
  final String displayName;
  final String deviceId;
  final String? model;
  final String? manufacturer;
  final String? osVersion;
  final String? platform;

  const DeviceProfile({
    required this.displayName,
    required this.deviceId,
    this.model,
    this.manufacturer,
    this.osVersion,
    this.platform,
  });

  static Future<DeviceProfile> fetch() async {
    final deviceInfo = DeviceInfoPlugin();
    try {
      if (kIsWeb) {
        final info = await deviceInfo.webBrowserInfo;
        logger.d("Fetched web browser info: $info");
        final browserName = info.browserName.name;
        final displayName = _firstNonEmpty(
          [info.platform, browserName, info.appName],
          'Web Browser',
        );
        final deviceId = _firstNonEmpty(
          [info.userAgent, info.appVersion],
          'WEB-DEVICE',
        );
        return DeviceProfile(
          displayName: displayName,
          deviceId: deviceId,
          model: browserName,
          manufacturer: info.vendor,
          osVersion: info.appVersion,
          platform: 'web',
        );
      }

      switch (defaultTargetPlatform) {
        case TargetPlatform.android:
          final info = await deviceInfo.androidInfo;
          logger.d("Fetched Android device info: $info");
          final displayName = _firstNonEmpty(
            [
              _joinNonEmpty([info.brand, info.model]),
              info.model,
              info.device,
              info.product,
            ],
            'Android Device',
          );
          final deviceId = _firstNonEmpty(
            [info.id, info.device, info.product, info.model],
            'ANDROID-DEVICE',
          );
          final osVersion = _joinNonEmpty(
            [
              'Android',
              info.version.release,
              'SDK ${info.version.sdkInt}',
            ],
          );
          return DeviceProfile(
            displayName: displayName,
            deviceId: deviceId,
            model: info.model,
            manufacturer: info.manufacturer,
            osVersion: osVersion,
            platform: 'android',
          );
        case TargetPlatform.iOS:
          final info = await deviceInfo.iosInfo;
          logger.d("Fetched iOS device info: $info");
          final displayName = _firstNonEmpty(
            [info.name, info.localizedModel, info.model],
            'iOS Device',
          );
          final deviceId = _firstNonEmpty(
            [info.identifierForVendor, info.name, info.model],
            'IOS-DEVICE',
          );
          final osVersion = _joinNonEmpty(
            [info.systemName, info.systemVersion],
          );
          return DeviceProfile(
            displayName: displayName,
            deviceId: deviceId,
            model: info.model,
            manufacturer: 'Apple',
            osVersion: osVersion,
            platform: 'ios',
          );
        case TargetPlatform.macOS:
          final info = await deviceInfo.macOsInfo;
          logger.d("Fetched macOS device info: $info");
          final displayName = _firstNonEmpty(
            [info.computerName, info.model],
            'macOS Device',
          );
          final deviceId = _firstNonEmpty(
            [info.computerName, info.model],
            'MAC-DEVICE',
          );
          final osVersion = _joinNonEmpty(
            ['macOS', info.osRelease],
          );
          return DeviceProfile(
            displayName: displayName,
            deviceId: deviceId,
            model: info.model,
            manufacturer: 'Apple',
            osVersion: osVersion,
            platform: 'macos',
          );
        case TargetPlatform.windows:
          final info = await deviceInfo.windowsInfo;
          logger.d("Fetched Windows device info: $info");
          final displayName = _firstNonEmpty(
            [info.computerName, info.productName],
            'Windows Device',
          );
          final deviceId = _firstNonEmpty(
            [info.deviceId, info.computerName, info.productName],
            'WINDOWS-DEVICE',
          );
          final osVersion = _joinNonEmpty(
            ['Windows', info.displayVersion, info.buildNumber.toString()],
          );
          return DeviceProfile(
            displayName: displayName,
            deviceId: deviceId,
            model: info.productName,
            manufacturer: 'Microsoft',
            osVersion: osVersion,
            platform: 'windows',
          );
        case TargetPlatform.linux:
          final info = await deviceInfo.linuxInfo;
          logger.d("Fetched Linux device info: $info");
          final displayName = _firstNonEmpty(
            [info.prettyName, info.name],
            'Linux Device',
          );
          final deviceId = _firstNonEmpty(
            [info.machineId, info.prettyName, info.name],
            'LINUX-DEVICE',
          );
          final osVersion = _joinNonEmpty(
            [info.name, info.version],
          );
          return DeviceProfile(
            displayName: displayName,
            deviceId: deviceId,
            model: info.prettyName,
            manufacturer: null,
            osVersion: osVersion,
            platform: 'linux',
          );
        case TargetPlatform.fuchsia:
          break;
      }
    } catch (_) {
      // Fall back to default profile below.
    }

    return const DeviceProfile(
      displayName: 'This Device',
      deviceId: 'THIS-DEVICE-001',
      platform: 'unknown',
    );
  }

  @override
  String toString() {
    return 'DeviceProfile(displayName: $displayName, deviceId: $deviceId, model: $model, manufacturer: $manufacturer, osVersion: $osVersion, platform: $platform)';
  }
}

String _firstNonEmpty(List<String?> candidates, String fallback) {
  for (final candidate in candidates) {
    if (candidate == null) continue;
    final trimmed = candidate.trim();
    if (trimmed.isNotEmpty) return trimmed;
  }
  return fallback;
}

String? _joinNonEmpty(List<String?> parts) {
  final cleaned = <String>[];
  for (final part in parts) {
    if (part == null) continue;
    final trimmed = part.trim();
    if (trimmed.isNotEmpty) cleaned.add(trimmed);
  }
  if (cleaned.isEmpty) return null;
  return cleaned.join(' ');
}

class MockGyroSensor extends Sensor<SensorDoubleValue> {
  MockGyroSensor()
      : super(
          sensorName: "Gyroscope",
          chartTitle: "Gyroscope",
          shortChartTitle: "Gyro",
          relatedConfigurations: [],
        );

  @override
  List<String> get axisNames => ['X', 'Y', 'Z'];

  @override
  List<String> get axisUnits => ['rad/s', 'rad/s', 'rad/s'];

  @override
  Stream<SensorDoubleValue> get sensorStream {
    return gyroscopeEventStream().map((event) {
      return SensorDoubleValue(
        values: [event.x, event.y, event.z],
        timestamp: DateTime.now().millisecondsSinceEpoch,
      );
    });
  }
}

class MockAccelerometer extends Sensor<SensorDoubleValue> {
  MockAccelerometer()
      : super(
          sensorName: "Accelerometer",
          chartTitle: "Accelerometer",
          shortChartTitle: "Accel",
          relatedConfigurations: [
            MockConfigurableSensorConfiguration(
                name: "Sensor Rate",
                availableOptions: {
                  StreamSensorConfigOption(),
                },
                values: [
                  MockConfigurableSensorConfigurationValue(
                      key: "30Hz",
                      options: {
                        StreamSensorConfigOption(),
                      },),
                ],),
          ],
        );

  @override
  List<String> get axisNames => ['X', 'Y', 'Z'];

  @override
  List<String> get axisUnits => ['m/s²', 'm/s²', 'm/s²'];

  @override
  Stream<SensorDoubleValue> get sensorStream {
    return accelerometerEventStream().map((event) {
      return SensorDoubleValue(
        values: [event.x, event.y, event.z],
        timestamp: DateTime.now().millisecondsSinceEpoch,
      );
    });
  }
}

class MockConfigurableSensorConfiguration
    extends ConfigurableSensorConfiguration<
        MockConfigurableSensorConfigurationValue> {
  MockConfigurableSensorConfiguration({
    required super.name,
    required super.values,
    super.availableOptions,
  });

  @override
  void setConfiguration(
      MockConfigurableSensorConfigurationValue configuration,) {
    // no-op
  }
}

class MockConfigurableSensorConfigurationValue
    extends ConfigurableSensorConfigurationValue {
  MockConfigurableSensorConfigurationValue({
    required super.key,
    super.options,
  });

  @override
  MockConfigurableSensorConfigurationValue withoutOptions() {
    return MockConfigurableSensorConfigurationValue(key: key);
  }
}
