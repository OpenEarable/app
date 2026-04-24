import 'dart:async';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart'
    hide Version, logger;
import 'package:pub_semver/pub_semver.dart';
import 'package:sensors_plus/sensors_plus.dart';

import 'logger.dart';

/// Represents the phone, tablet, desktop, or browser running the app as a
/// wearable-like device with locally available sensors.
class ThisDeviceWearable extends Wearable
    implements
        SensorManager,
        SensorConfigurationManager,
        DeviceFirmwareVersion {
  @override
  final List<Sensor> sensors = [];

  @override
  final List<SensorConfiguration> sensorConfigurations = [];

  final StreamController<Map<SensorConfiguration, SensorConfigurationValue>>
      _sensorConfigurationController = StreamController.broadcast();

  @override
  Stream<Map<SensorConfiguration, SensorConfigurationValue>>
      get sensorConfigurationStream => _sensorConfigurationController.stream;

  final DeviceProfile deviceProfile;

  final WearableDisconnectNotifier _disconnectNotifier;

  /// Creates a host-device wearable from an already resolved device profile.
  ThisDeviceWearable._({
    required super.disconnectNotifier,
    required this.deviceProfile,
  })  : _disconnectNotifier = disconnectNotifier,
        super(name: deviceProfile.displayName);

  /// Builds the host-device wearable and registers every sensor that produces
  /// at least one sample on the current platform.
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
    _disconnectNotifier.notifyListeners();
  }

  @override
  String? getWearableIconPath({
    bool darkmode = false,
    WearableIconVariant variant = WearableIconVariant.single,
  }) {
    return null;
  }

  void _emitSensorConfigurationChange(
    SensorConfiguration configuration,
    SensorConfigurationValue value,
  ) {
    _sensorConfigurationController.add({configuration: value});
  }

  Future<void> _initSensors() async {
    await _registerSensorIfAvailable<GyroscopeEvent>(
      sensorName: 'Gyroscope',
      chartTitle: 'Gyroscope',
      shortChartTitle: 'Gyro',
      axisNames: ['X', 'Y', 'Z'],
      axisUnits: ['rad/s', 'rad/s', 'rad/s'],
      valueExtractor: (event) => SensorDoubleValue(
        values: [event.x, event.y, event.z],
        timestamp: event.timestamp.millisecondsSinceEpoch,
      ),
      sensorStreamProvider: gyroscopeEventStream,
    );
    await _registerSensorIfAvailable<AccelerometerEvent>(
      sensorName: 'Accelerometer',
      chartTitle: 'Accelerometer',
      shortChartTitle: 'Accel',
      axisNames: ['X', 'Y', 'Z'],
      axisUnits: ['m/s²', 'm/s²', 'm/s²'],
      valueExtractor: (event) => SensorDoubleValue(
        values: [event.x, event.y, event.z],
        timestamp: event.timestamp.millisecondsSinceEpoch,
      ),
      sensorStreamProvider: accelerometerEventStream,
    );
    await _registerSensorIfAvailable<UserAccelerometerEvent>(
      sensorName: 'User Accelerometer',
      chartTitle: 'User Accelerometer',
      shortChartTitle: 'User Accel',
      axisNames: ['X', 'Y', 'Z'],
      axisUnits: ['m/s²', 'm/s²', 'm/s²'],
      valueExtractor: (event) => SensorDoubleValue(
        values: [event.x, event.y, event.z],
        timestamp: event.timestamp.millisecondsSinceEpoch,
      ),
      sensorStreamProvider: userAccelerometerEventStream,
    );
    await _registerSensorIfAvailable<MagnetometerEvent>(
      sensorName: 'Magnetometer',
      chartTitle: 'Magnetometer',
      shortChartTitle: 'Mag',
      axisNames: ['X', 'Y', 'Z'],
      axisUnits: ['µT', 'µT', 'µT'],
      valueExtractor: (event) => SensorDoubleValue(
        values: [event.x, event.y, event.z],
        timestamp: event.timestamp.millisecondsSinceEpoch,
      ),
      sensorStreamProvider: magnetometerEventStream,
    );
    await _registerSensorIfAvailable<BarometerEvent>(
      sensorName: 'Barometer',
      chartTitle: 'Barometer',
      shortChartTitle: 'Baro',
      axisNames: ['Pressure'],
      axisUnits: ['hPa'],
      valueExtractor: (event) => SensorDoubleValue(
        values: [event.pressure],
        timestamp: event.timestamp.millisecondsSinceEpoch,
      ),
      sensorStreamProvider: barometerEventStream,
    );
  }

  Future<void> _registerSensorIfAvailable<SensorEvent>({
    required String sensorName,
    required String chartTitle,
    required String shortChartTitle,
    required List<String> axisNames,
    required List<String> axisUnits,
    required SensorDoubleValue Function(SensorEvent event) valueExtractor,
    required Stream<SensorEvent> Function({required Duration samplingPeriod})
        sensorStreamProvider,
  }) async {
    final availabilityProbe = sensorStreamProvider(
      samplingPeriod: SensorInterval.normalInterval,
    );
    if (!await _isSensorAvailable<SensorEvent>(availabilityProbe)) {
      logger.w("Sensor '$sensorName' is not available on this device.");
      return;
    }

    final config = DeviceSensorConfiguration(
      name: sensorName,
      onChange: _emitSensorConfigurationChange,
    );
    sensorConfigurations.add(config);
    _emitSensorConfigurationChange(config, config.currentValue);
    sensors.add(
      ThisDeviceSensor<SensorEvent>(
        config: config,
        sensorName: sensorName,
        chartTitle: chartTitle,
        shortChartTitle: shortChartTitle,
        axisNames: axisNames,
        axisUnits: axisUnits,
        valueExtractor: valueExtractor,
        sensorStreamProvider: sensorStreamProvider,
      ),
    );
  }

  /// Returns whether the platform emitted a sample before the availability
  /// timeout. Missing hardware, unsupported platforms, and permission failures
  /// are treated as unavailable so the app does not show dead sensors.
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

/// Static metadata for the device running the app.
class DeviceProfile {
  final String displayName;
  final String deviceId;
  final String? model;
  final String? manufacturer;
  final String? osVersion;
  final String? platform;

  /// Creates a host device metadata snapshot.
  const DeviceProfile({
    required this.displayName,
    required this.deviceId,
    this.model,
    this.manufacturer,
    this.osVersion,
    this.platform,
  });

  /// Reads platform-specific device information and falls back to a generic
  /// profile when a platform does not expose one.
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

/// Adapts a `sensors_plus` event stream to the OpenEarable sensor interface.
class ThisDeviceSensor<SensorEvent> extends Sensor<SensorDoubleValue> {
  final DeviceSensorConfiguration config;
  late final StreamController<SensorDoubleValue> _controller;
  StreamSubscription<SensorEvent>? _subscription;
  final Stream<SensorEvent> Function({required Duration samplingPeriod})
      _sensorStreamProvider;
  final SensorDoubleValue Function(SensorEvent event) _valueExtractor;

  /// Creates a sensor adapter for a single host-device sensor stream.
  ThisDeviceSensor({
    required super.sensorName,
    required super.chartTitle,
    required super.shortChartTitle,
    required this.config,
    required List<String> axisNames,
    required List<String> axisUnits,
    required SensorDoubleValue Function(SensorEvent event) valueExtractor,
    required Stream<SensorEvent> Function({required Duration samplingPeriod})
        sensorStreamProvider,
  })  : _axisNames = axisNames,
        _axisUnits = axisUnits,
        _valueExtractor = valueExtractor,
        _sensorStreamProvider = sensorStreamProvider {
    _controller = StreamController<SensorDoubleValue>.broadcast(
      onListen: _updateSubscription,
      onCancel: _updateSubscription,
    );
    config.changes.listen((value) {
      _updateSubscription();
    });
  }

  final List<String> _axisNames;
  @override
  List<String> get axisNames => _axisNames;

  final List<String> _axisUnits;
  @override
  List<String> get axisUnits => _axisUnits;

  @override
  Stream<SensorDoubleValue> get sensorStream => _controller.stream;

  void _updateSubscription() {
    if (!_controller.hasListener) {
      _cancelSubscription();
      return;
    }

    final value = config.currentValue;
    if (value.isOff) {
      _cancelSubscription();
      return;
    }

    final samplingPeriod = value.frequencyHz > 0
        ? Duration(milliseconds: (1000 / value.frequencyHz).round())
        : SensorInterval.normalInterval;

    _cancelSubscription();
    _subscription =
        _sensorStreamProvider(samplingPeriod: samplingPeriod).listen(
      (event) {
        _controller.add(
          _valueExtractor(event),
        );
      },
      onError: _controller.addError,
    );
  }

  void _cancelSubscription() {
    _subscription?.cancel();
    _subscription = null;
  }
}

/// Frequency configuration shared by host-device sensor streams.
class DeviceSensorConfiguration
    extends SensorFrequencyConfiguration<DeviceSensorFrequencyValue> {
  final void Function(
    SensorConfiguration configuration,
    SensorConfigurationValue value,
  ) onChange;

  DeviceSensorFrequencyValue _currentValue;

  /// Creates a frequency configuration with the standard host-device values.
  DeviceSensorConfiguration({
    required super.name,
    required this.onChange,
  })  : _currentValue = DeviceSensorFrequencyValue.off(),
        super(
          values: DeviceSensorFrequencyValue.defaults(),
          offValue: DeviceSensorFrequencyValue.off(),
        );

  DeviceSensorFrequencyValue get currentValue => _currentValue;

  /// Emits every frequency value applied to this host-device sensor.
  Stream<DeviceSensorFrequencyValue> get changes => _changesController.stream;

  final StreamController<DeviceSensorFrequencyValue> _changesController =
      StreamController.broadcast();

  @override
  void setConfiguration(DeviceSensorFrequencyValue configuration) {
    _currentValue = configuration;
    onChange(this, configuration);
    _changesController.add(configuration);
  }
}

/// Sampling frequency option for host-device sensors.
class DeviceSensorFrequencyValue extends SensorFrequencyConfigurationValue {
  DeviceSensorFrequencyValue({
    required super.frequencyHz,
    String? key,
  }) : super(
          key: key ?? _formatKey(frequencyHz),
        );

  /// Whether this value disables sampling for the sensor.
  bool get isOff => frequencyHz <= 0;

  /// Creates the disabled sampling option.
  static DeviceSensorFrequencyValue off() {
    return DeviceSensorFrequencyValue(
      frequencyHz: 0,
      key: 'Off',
    );
  }

  /// Creates the default interactive sampling option.
  static DeviceSensorFrequencyValue normal() {
    return DeviceSensorFrequencyValue(
      frequencyHz: 5,
    );
  }

  /// Returns the standard frequency choices shown for host-device sensors.
  static List<DeviceSensorFrequencyValue> defaults() {
    return [
      off(),
      fromHz(1),
      normal(),
      fromHz(10),
      fromHz(15),
      fromHz(20),
      fromHz(30),
      fromHz(50),
      fromHz(60),
      fromHz(100),
      fromHz(200),
    ];
  }

  /// Creates a sampling option for the provided frequency.
  static DeviceSensorFrequencyValue fromHz(double frequencyHz) {
    return DeviceSensorFrequencyValue(
      frequencyHz: frequencyHz,
    );
  }

  static String _formatKey(double frequencyHz) {
    if (frequencyHz == frequencyHz.roundToDouble()) {
      return '${frequencyHz.toInt()} Hz';
    }
    return '${frequencyHz.toStringAsFixed(2)} Hz';
  }
}
