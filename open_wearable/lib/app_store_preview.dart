import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart';
import 'package:open_wearable/models/log_file_manager.dart';
import 'package:open_wearable/models/wearable_connector.dart';
import 'package:open_wearable/theme/app_theme.dart';
import 'package:open_wearable/view_models/app_banner_controller.dart';
import 'package:open_wearable/view_models/sensor_recorder_provider_facade.dart';
import 'package:open_wearable/view_models/wearables_provider.dart';
import 'package:open_wearable/widgets/devices/device_detail/device_detail_page.dart';
import 'package:open_wearable/widgets/home_page.dart';
import 'package:provider/provider.dart';
import 'package:pub_semver/pub_semver.dart' as semver;

/// App shell used only when building App Store screenshots.
///
/// The preview is selected at compile time with `APP_STORE_PREVIEW=true` and
/// never changes the normal Bluetooth connection or sensor-data paths.
class AppStorePreviewApp extends StatefulWidget {
  final LogFileManager logFileManager;

  const AppStorePreviewApp({
    super.key,
    required this.logFileManager,
  });

  @override
  State<AppStorePreviewApp> createState() => _AppStorePreviewAppState();
}

class _AppStorePreviewAppState extends State<AppStorePreviewApp> {
  late final AppStorePreviewWearable _wearable;
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _wearable = AppStorePreviewWearable();
    _router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, __) => const HomePage(),
        ),
        GoRoute(
          path: '/device-detail',
          builder: (_, state) {
            final device = state.extra;
            return DeviceDetailPage(
              device: device is Wearable ? device : _wearable,
            );
          },
        ),
        GoRoute(
          path: '/connect-devices',
          redirect: (_, __) => '/?tab=devices',
        ),
        GoRoute(
          path: '/view',
          builder: (_, state) {
            final view = state.extra;
            return view is Widget
                ? view
                : const HomePage(
                    initialSectionIndex: 2,
                  );
          },
        ),
        GoRoute(
          path: '/settings/general',
          redirect: (_, __) => '/?tab=settings',
        ),
      ],
    );
  }

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) {
            final provider = WearablesProvider();
            provider.addWearable(_wearable);
            return provider;
          },
        ),
        ChangeNotifierProvider(
          create: (_) => FirmwareUpdateRequestProvider(),
        ),
        ChangeNotifierProxyProvider<WearablesProvider, SensorRecorderProvider>(
          create: (_) => SensorRecorderProvider(),
          update: (_, wearablesProvider, recorderProvider) {
            final provider = recorderProvider ?? SensorRecorderProvider();
            provider.synchronizeConnectedWearables(
              wearablesProvider.wearables,
            );
            return provider;
          },
        ),
        Provider<WearableConnector>(
          create: (_) => WearableConnector(),
        ),
        ChangeNotifierProvider(
          create: (_) => AppBannerController(),
        ),
        ChangeNotifierProvider.value(value: widget.logFileManager),
      ],
      child: PlatformProvider(
        settings: PlatformSettingsData(
          platformStyle: const PlatformStyleData(
            ios: PlatformStyle.Material,
            macos: PlatformStyle.Material,
          ),
        ),
        builder: (context) => PlatformTheme(
          materialLightTheme: AppTheme.lightTheme(),
          materialDarkTheme: AppTheme.darkTheme(),
          themeMode: ThemeMode.light,
          builder: (context) => PlatformApp.router(
            title: 'OpenWearables',
            debugShowCheckedModeBanner: false,
            localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
              DefaultMaterialLocalizations.delegate,
              DefaultWidgetsLocalizations.delegate,
              DefaultCupertinoLocalizations.delegate,
            ],
            routerConfig: _router,
          ),
        ),
      ),
    );
  }
}

/// A deterministic OpenEarable V2-style device for screenshot builds.
class AppStorePreviewWearable extends Wearable
    implements
        SensorManager,
        SensorConfigurationManager,
        BatteryLevelStatus,
        DeviceFirmwareVersion,
        DeviceHardwareVersion,
        DeviceIdentifier,
        RgbLed,
        StatusLed,
        AudioModeManager,
        MicrophoneManager<PreviewMicrophone>,
        PowerSavingModeManager {
  static const _sampleInterval = Duration(milliseconds: 20);
  static final _disconnectNotifier = WearableDisconnectNotifier();
  final List<Sensor> _sensors;
  final StreamController<Map<SensorConfiguration, SensorConfigurationValue>>
      _sensorConfigurationController = StreamController.broadcast();
  final Map<SensorConfiguration, SensorConfigurationValue>
      _configurationValues = {};
  late final List<SensorConfiguration> _sensorConfigurations;

  @override
  final Set<AudioMode> availableAudioModes = const {
    NormalMode(),
    TransparencyMode(),
    NoiseCancellationMode(),
  };

  @override
  final Set<PreviewMicrophone> availableMicrophones = {
    const PreviewMicrophone('INNER'),
    const PreviewMicrophone('OUTER'),
  };

  final List<PowerSavingMode> _powerSavingModes = const [
    PowerSavingMode(id: 0, name: 'Disabled'),
    PowerSavingMode(id: 1, name: '30 minutes'),
    PowerSavingMode(id: 2, name: '15 minutes'),
    PowerSavingMode(id: 3, name: '5 minutes'),
  ];

  late AudioMode _audioMode = const NormalMode();
  late PreviewMicrophone _microphone = const PreviewMicrophone('INNER');
  late PowerSavingMode _powerSavingMode = _powerSavingModes.first;

  AppStorePreviewWearable()
      : _sensors = _buildSensors(),
        super(
          // Matches the firmware's `OpenEarable-%04X` advertising format.
          name: 'OpenEarable-7E42',
          disconnectNotifier: _disconnectNotifier,
        ) {
    _sensorConfigurations = _buildSensorConfigurations();
    for (final configuration in _sensorConfigurations) {
      final dynamic previewConfiguration = configuration;
      _configurationValues[configuration] =
          previewConfiguration.currentValue as SensorConfigurationValue;
    }
    _sensorConfigurationController.onListen = _publishConfigurationState;
  }

  List<SensorConfiguration> _buildSensorConfigurations() {
    return [
      _configuration(
        name: '9-Axis IMU',
        frequencies: const [25, 50, 100, 200, 400],
        initialFrequency: 100,
      ),
      _configuration(
        name: 'Microphones',
        frequencies: const [8000, 16000, 24000, 32000],
        initialFrequency: 16000,
      ),
      _configuration(
        name: 'Pulse Oximeter',
        frequencies: const [10, 25, 50, 100, 200],
        initialFrequency: 50,
      ),
      _configuration(
        name: 'Skin Temperature Sensor',
        frequencies: const [1, 2, 5, 10],
        initialFrequency: 5,
      ),
      _configuration(
        name: 'Ear Canal Pressure Sensor',
        frequencies: const [1, 5, 10, 25, 50],
        initialFrequency: 25,
      ),
      _configuration(
        name: 'Bone Conduction Accelerometer',
        frequencies: const [100, 200, 400, 800, 1600],
        initialFrequency: 400,
      ),
    ];
  }

  _PreviewSensorConfiguration _configuration({
    required String name,
    required List<double> frequencies,
    required double initialFrequency,
  }) {
    final values = <_PreviewSensorConfigurationValue>[
      _PreviewSensorConfigurationValue(frequencyHz: 0),
      for (final frequency in frequencies) ...[
        _PreviewSensorConfigurationValue(frequencyHz: frequency),
        _PreviewSensorConfigurationValue(
          frequencyHz: frequency,
          options: {const StreamSensorConfigOption()},
        ),
        _PreviewSensorConfigurationValue(
          frequencyHz: frequency,
          options: {const RecordSensorConfigOption()},
        ),
        _PreviewSensorConfigurationValue(
          frequencyHz: frequency,
          options: {
            const StreamSensorConfigOption(),
            const RecordSensorConfigOption(),
          },
        ),
      ],
    ];
    final initialValue = values.firstWhere(
      (value) =>
          value.frequencyHz == initialFrequency &&
          value.options.any((option) => option is StreamSensorConfigOption),
    );

    return _PreviewSensorConfiguration(
      name: name,
      values: values,
      initialValue: initialValue,
      onChanged: _onSensorConfigurationChanged,
    );
  }

  void _onSensorConfigurationChanged(
    SensorConfiguration configuration,
    SensorConfigurationValue value,
  ) {
    _configurationValues[configuration] = value;
    _publishConfigurationState();
  }

  void _publishConfigurationState() {
    if (!_sensorConfigurationController.isClosed) {
      _sensorConfigurationController.add(Map.of(_configurationValues));
    }
  }

  static List<Sensor> _buildSensors() {
    return [
      _PreviewSensor(
        sensorName: 'Accelerometer',
        chartTitle: 'Accelerometer',
        shortChartTitle: 'Accel.',
        axisNames: const ['X', 'Y', 'Z'],
        axisUnits: const ['m/s²', 'm/s²', 'm/s²'],
        sampleValues: _accelerometerValues,
      ),
      _PreviewSensor(
        sensorName: 'Gyroscope',
        chartTitle: 'Gyroscope',
        shortChartTitle: 'Gyro.',
        axisNames: const ['X', 'Y', 'Z'],
        axisUnits: const ['°/s', '°/s', '°/s'],
        sampleValues: _gyroscopeValues,
      ),
      _PreviewSensor(
        sensorName: 'Magnetometer',
        chartTitle: 'Magnetometer',
        shortChartTitle: 'Mag.',
        axisNames: const ['X', 'Y', 'Z'],
        axisUnits: const ['µT', 'µT', 'µT'],
        sampleValues: _magnetometerValues,
      ),
      _PreviewSensor(
        sensorName: 'Pressure',
        chartTitle: 'Pressure',
        shortChartTitle: 'Pressure',
        axisNames: const ['Pressure'],
        axisUnits: const ['hPa'],
        sampleValues: (seconds) => [_pressureValue(seconds)],
      ),
      _PreviewSensor(
        sensorName: 'Skin Temperature',
        chartTitle: 'Skin Temperature',
        shortChartTitle: 'Skin temp.',
        axisNames: const ['Temperature'],
        axisUnits: const ['°C'],
        sampleValues: (seconds) => [_skinTemperatureValue(seconds)],
      ),
      _PreviewSensor(
        sensorName: 'Barometer Temperature',
        chartTitle: 'Barometer Temperature',
        shortChartTitle: 'Baro temp.',
        axisNames: const ['Temperature'],
        axisUnits: const ['°C'],
        sampleValues: (seconds) => [_barometerTemperatureValue(seconds)],
      ),
      _PreviewSensor(
        sensorName: 'Bone Conduction Accelerometer',
        chartTitle: 'Bone Conduction',
        shortChartTitle: 'Bone accel.',
        axisNames: const ['X', 'Y', 'Z'],
        axisUnits: const ['g', 'g', 'g'],
        sampleValues: _boneConductionValues,
      ),
      _PreviewSensor(
        sensorName: 'PPG RED',
        chartTitle: 'PPG - RED',
        shortChartTitle: 'PPG RED',
        axisNames: const ['RED'],
        axisUnits: const ['ADC'],
        sampleValues: _ppgRedValues,
      ),
      _PreviewSensor(
        sensorName: 'PPG IR',
        chartTitle: 'PPG - IR',
        shortChartTitle: 'PPG IR',
        axisNames: const ['IR'],
        axisUnits: const ['ADC'],
        sampleValues: _ppgIrValues,
      ),
      _PreviewSensor(
        sensorName: 'PPG GREEN',
        chartTitle: 'PPG - GREEN',
        shortChartTitle: 'PPG GREEN',
        axisNames: const ['GREEN'],
        axisUnits: const ['ADC'],
        sampleValues: _ppgGreenValues,
      ),
      _PreviewSensor(
        sensorName: 'PPG AMBIENT',
        chartTitle: 'PPG - AMBIENT',
        shortChartTitle: 'PPG AMBIENT',
        axisNames: const ['AMBIENT'],
        axisUnits: const ['ADC'],
        sampleValues: _ppgAmbientValues,
      ),
    ];
  }

  /// Simulates gravity-compensated acceleration for a device mounted a short
  /// distance from the head's rotation center. At rest, all axes sit near 0.
  static List<double> _accelerometerValues(double seconds) {
    const derivativeWindowSeconds = 0.12;
    const leverArm = [0.08, -0.06, 0.10];
    final angularVelocity = _angularVelocityAt(seconds);
    final beforeVelocity =
        _angularVelocityAt(seconds - derivativeWindowSeconds);
    final afterVelocity = _angularVelocityAt(seconds + derivativeWindowSeconds);
    final angularAcceleration = [
      (afterVelocity[0] - beforeVelocity[0]) / (2 * derivativeWindowSeconds),
      (afterVelocity[1] - beforeVelocity[1]) / (2 * derivativeWindowSeconds),
      (afterVelocity[2] - beforeVelocity[2]) / (2 * derivativeWindowSeconds),
    ];
    final tangentialAcceleration = _cross(angularAcceleration, leverArm);
    final centripetalAcceleration =
        _cross(angularVelocity, _cross(angularVelocity, leverArm));

    return [
      tangentialAcceleration[0] +
          centripetalAcceleration[0] +
          _accelerometerMeasurementNoise(seconds, 40),
      tangentialAcceleration[1] +
          centripetalAcceleration[1] +
          _accelerometerMeasurementNoise(seconds, 41),
      tangentialAcceleration[2] +
          centripetalAcceleration[2] +
          _accelerometerMeasurementNoise(seconds, 42),
    ];
  }

  static double _accelerometerMeasurementNoise(double seconds, int seed) {
    return 0.055 * _smoothRandom(seconds, seed, 13) +
        0.025 * _smoothRandom(seconds, seed + 10, 19);
  }

  /// These sensors are effectively stationary in the preview. Only a small
  /// sample-level measurement error is visible instead of simulated movement.
  static double _pressureValue(double seconds) {
    return 1012.8 + 0.0015 * _stationarySensorNoise(seconds, 9);
  }

  static double _skinTemperatureValue(double seconds) {
    return 34.2 + 0.008 * _stationarySensorNoise(seconds, 50);
  }

  static double _barometerTemperatureValue(double seconds) {
    return 32.8 + 0.006 * _stationarySensorNoise(seconds, 52);
  }

  static double _stationarySensorNoise(double seconds, int seed) {
    return _smoothRandom(seconds, seed, 1.0);
  }

  /// Bone-conduction acceleration includes the same head movement measured by
  /// the IMU, expressed in g, together with the higher-frequency local
  /// vibrations captured at the device contact point.
  static List<double> _boneConductionValues(double seconds) {
    const gravity = 9.80665;
    final headMotion = _accelerometerValues(seconds);

    return [
      headMotion[0] / gravity + 0.018 * _sensorNoise(seconds, 60),
      headMotion[1] / gravity + 0.015 * _sensorNoise(seconds, 61),
      headMotion[2] / gravity + 0.020 * _sensorNoise(seconds, 62),
    ];
  }

  /// Rotates a stable local Earth-field vector into device coordinates using
  /// the same roll, pitch, and yaw that drive the other motion sensors.
  static List<double> _magnetometerValues(double seconds) {
    const earthField = [21.5, -3.0, 43.0];
    final orientation = _orientationAt(seconds);
    final cosYaw = math.cos(orientation.yaw);
    final sinYaw = math.sin(orientation.yaw);
    final cosPitch = math.cos(orientation.pitch);
    final sinPitch = math.sin(orientation.pitch);
    final cosRoll = math.cos(orientation.roll);
    final sinRoll = math.sin(orientation.roll);

    final yawX = cosYaw * earthField[0] + sinYaw * earthField[1];
    final yawY = -sinYaw * earthField[0] + cosYaw * earthField[1];
    final pitchX = cosPitch * yawX - sinPitch * earthField[2];
    final pitchZ = sinPitch * yawX + cosPitch * earthField[2];

    return [
      pitchX + 0.25 * _smoothRandom(seconds, 6, 10),
      cosRoll * yawY + sinRoll * pitchZ + 0.25 * _smoothRandom(seconds, 7, 10),
      -sinRoll * yawY + cosRoll * pitchZ + 0.25 * _smoothRandom(seconds, 8, 10),
    ];
  }

  /// Calculates angular velocity from the same roll/pitch used by the
  /// accelerometer. The components are expressed in the device coordinate
  /// system and converted from radians to degrees per second.
  static List<double> _gyroscopeValues(double seconds) {
    const radiansToDegrees = 180 / math.pi;
    final angularVelocity = _angularVelocityAt(seconds);

    return [
      angularVelocity[0] * radiansToDegrees +
          0.25 * _smoothRandom(seconds, 20, 3.5),
      angularVelocity[1] * radiansToDegrees +
          0.25 * _smoothRandom(seconds, 21, 3.5),
      angularVelocity[2] * radiansToDegrees +
          0.25 * _smoothRandom(seconds, 22, 3.5),
    ];
  }

  static List<double> _angularVelocityAt(double seconds) {
    const derivativeWindowSeconds = 0.12;
    final before = _orientationAt(seconds - derivativeWindowSeconds);
    final current = _orientationAt(seconds);
    final after = _orientationAt(seconds + derivativeWindowSeconds);
    final rollRate = (after.roll - before.roll) / (2 * derivativeWindowSeconds);
    final pitchRate =
        (after.pitch - before.pitch) / (2 * derivativeWindowSeconds);
    final yawRate = (after.yaw - before.yaw) / (2 * derivativeWindowSeconds);

    return [
      rollRate - yawRate * math.sin(current.pitch),
      pitchRate * math.cos(current.roll) +
          yawRate * math.sin(current.roll) * math.cos(current.pitch),
      -pitchRate * math.sin(current.roll) +
          yawRate * math.cos(current.roll) * math.cos(current.pitch),
    ];
  }

  static List<double> _cross(List<double> first, List<double> second) {
    return [
      first[1] * second[2] - first[2] * second[1],
      first[2] * second[0] - first[0] * second[2],
      first[0] * second[1] - first[1] * second[0],
    ];
  }

  static _PreviewOrientation _orientationAt(double seconds) {
    return _PreviewOrientation(
      pitch: 0.52 +
          0.34 * _smoothRandom(seconds, 0, 0.34) +
          0.08 * _smoothRandom(seconds, 10, 2.2) +
          0.020 * _smoothRandom(seconds, 30, 6.5),
      roll: 0.72 +
          0.36 * _smoothRandom(seconds, 1, 0.28) +
          0.07 * _smoothRandom(seconds, 11, 2.7) +
          0.024 * _smoothRandom(seconds, 31, 6),
      yaw: 0.25 +
          0.50 * _smoothRandom(seconds, 2, 0.12) +
          0.16 * _smoothRandom(seconds, 12, 0.85) +
          0.020 * _smoothRandom(seconds, 32, 4),
    );
  }

  /// Produces band-limited, deterministic noise so screenshots are repeatable
  /// without making the live traces look periodic.
  static double _sensorNoise(double seconds, int seed) {
    return 0.50 * _smoothRandom(seconds, seed, 0.45) +
        0.31 * _smoothRandom(seconds, seed + 17, 2.6) +
        0.19 * _smoothRandom(seconds, seed + 31, 14.5);
  }

  static double _smoothRandom(double seconds, int seed, double frequency) {
    final position = seconds * frequency;
    final leftIndex = position.floor();
    final fraction = position - leftIndex;
    final easedFraction = fraction * fraction * (3 - 2 * fraction);
    final start = _randomAt(leftIndex, seed);
    final end = _randomAt(leftIndex + 1, seed);
    return start + (end - start) * easedFraction;
  }

  static double _randomAt(int index, int seed) {
    var value = index ^ (seed * 0x9E3779B9);
    value = (value ^ (value >> 16)) * 0x45D9F3B;
    value = (value ^ (value >> 16)) * 0x45D9F3B;
    value ^= value >> 16;
    return (value & 0x7FFFFFFF) / 0x3FFFFFFF - 1;
  }

  static List<double> _ppgValues(double seconds) {
    final heartbeatPosition =
        seconds * 1.16 + 0.07 * _smoothRandom(seconds, 41, 0.2);
    final phase = heartbeatPosition - heartbeatPosition.floor();
    final systolicPeak = math.exp(-math.pow((phase - 0.17) / 0.07, 2));
    final dicroticWave = 0.32 * math.exp(-math.pow((phase - 0.48) / 0.11, 2));
    final pulse = systolicPeak + dicroticWave;
    final contact = 1 + 0.035 * _smoothRandom(seconds, 42, 0.12);
    final motionArtifact = 1800 * _sensorNoise(seconds, 43);

    return [
      228000 +
          34000 * contact * pulse +
          motionArtifact +
          950 * _sensorNoise(seconds, 44),
      194000 +
          31000 * contact * pulse +
          0.85 * motionArtifact +
          800 * _sensorNoise(seconds, 45),
      126000 +
          17500 * contact * pulse +
          0.70 * motionArtifact +
          700 * _sensorNoise(seconds, 46),
      4800 +
          900 * _smoothRandom(seconds, 47, 0.08) +
          550 * _sensorNoise(seconds, 48),
    ];
  }

  static List<double> _ppgRedValues(double seconds) => [_ppgValues(seconds)[0]];

  static List<double> _ppgIrValues(double seconds) => [_ppgValues(seconds)[1]];

  static List<double> _ppgGreenValues(double seconds) =>
      [_ppgValues(seconds)[2]];

  static List<double> _ppgAmbientValues(double seconds) =>
      [_ppgValues(seconds)[3]];

  @override
  String get deviceId => 'F4:12:FA:00:7E:42';

  @override
  List<Sensor> get sensors => _sensors;

  @override
  List<SensorConfiguration> get sensorConfigurations => _sensorConfigurations;

  @override
  Stream<Map<SensorConfiguration, SensorConfigurationValue>>
      get sensorConfigurationStream => _sensorConfigurationController.stream;

  @override
  Future<String?> readDeviceIdentifier() async => 'OE2-7E42';

  @override
  Future<void> writeLedColor({
    required int r,
    required int g,
    required int b,
  }) async {}

  @override
  Future<void> showStatus(bool status) async {}

  @override
  void setAudioMode(AudioMode audioMode) {
    _audioMode = audioMode;
  }

  @override
  Future<AudioMode> getAudioMode() async => _audioMode;

  @override
  void setMicrophone(PreviewMicrophone microphone) {
    _microphone = microphone;
  }

  @override
  Future<PreviewMicrophone> getMicrophone() async => _microphone;

  @override
  Future<List<PowerSavingMode>> readSupportedPowerSavingModes() async =>
      _powerSavingModes;

  @override
  Future<PowerSavingMode> readPowerSavingMode() async => _powerSavingMode;

  @override
  Future<void> setPowerSavingMode(PowerSavingMode mode) async {
    _powerSavingMode = mode;
  }

  @override
  Future<int> readBatteryPercentage() async => 87;

  @override
  Stream<int> get batteryPercentageStream => Stream<int>.value(87);

  @override
  Future<String?> readDeviceFirmwareVersion() async => '2.2.0';

  @override
  Future<semver.Version?> readFirmwareVersionNumber() async =>
      semver.Version(2, 2, 0);

  @override
  semver.VersionConstraint get supportedFirmwareRange =>
      semver.VersionConstraint.any;

  @override
  Future<FirmwareSupportStatus> checkFirmwareSupport() async =>
      FirmwareSupportStatus.supported;

  @override
  Future<String?> readDeviceHardwareVersion() async => 'V2.1';

  @override
  Future<void> disconnect() async {
    _disconnectNotifier.notifyListeners();
  }

  @override
  String? getWearableIconPath({
    bool darkmode = false,
    WearableIconVariant variant = WearableIconVariant.single,
  }) {
    const basePath =
        'packages/open_earable_flutter/assets/wearable_icons/open_earable_v2';
    if (darkmode) {
      return '$basePath/icon_no_text_white.svg';
    }
    return '$basePath/icon_no_text.svg';
  }
}

class _PreviewSensorConfiguration
    extends SensorFrequencyConfiguration<_PreviewSensorConfigurationValue>
    implements
        ConfigurableSensorConfiguration<_PreviewSensorConfigurationValue> {
  final void Function(SensorConfiguration, SensorConfigurationValue) _onChanged;
  _PreviewSensorConfigurationValue _currentValue;

  @override
  final Set<SensorConfigurationOption> availableOptions = {
    const StreamSensorConfigOption(),
    const RecordSensorConfigOption(),
  };

  _PreviewSensorConfiguration({
    required super.name,
    required super.values,
    required _PreviewSensorConfigurationValue initialValue,
    required void Function(SensorConfiguration, SensorConfigurationValue)
        onChanged,
  })  : _currentValue = initialValue,
        _onChanged = onChanged,
        super(offValue: values.first);

  _PreviewSensorConfigurationValue get currentValue => _currentValue;

  @override
  void setConfiguration(_PreviewSensorConfigurationValue configuration) {
    _currentValue = configuration;
    _onChanged(this, configuration);
  }
}

class _PreviewSensorConfigurationValue extends SensorFrequencyConfigurationValue
    implements ConfigurableSensorConfigurationValue {
  @override
  final Set<SensorConfigurationOption> options;

  _PreviewSensorConfigurationValue({
    required super.frequencyHz,
    this.options = const {},
  }) : super(key: '$frequencyHz Hz');

  @override
  _PreviewSensorConfigurationValue withoutOptions() {
    return _PreviewSensorConfigurationValue(frequencyHz: frequencyHz);
  }

  @override
  bool operator ==(Object other) {
    return other is _PreviewSensorConfigurationValue &&
        other.frequencyHz == frequencyHz &&
        _sameOptionNames(other.options, options);
  }

  @override
  int get hashCode => Object.hash(
        frequencyHz,
        options.map((option) => option.name).toSet().join('|'),
      );

  static bool _sameOptionNames(
    Set<SensorConfigurationOption> first,
    Set<SensorConfigurationOption> second,
  ) {
    return first.length == second.length && first.containsAll(second);
  }
}

class PreviewMicrophone extends Microphone {
  const PreviewMicrophone(String key) : super(key: key);
}

class _PreviewOrientation {
  final double pitch;
  final double roll;
  final double yaw;

  const _PreviewOrientation({
    required this.pitch,
    required this.roll,
    required this.yaw,
  });
}

class _PreviewSensor extends Sensor<SensorDoubleValue> {
  static const _historySamples = 250;
  final List<String> _axisNames;
  final List<String> _axisUnits;
  final List<double> Function(double seconds) _sampleValues;

  _PreviewSensor({
    required super.sensorName,
    required super.chartTitle,
    required super.shortChartTitle,
    required List<String> axisNames,
    required List<String> axisUnits,
    required List<double> Function(double seconds) sampleValues,
  })  : _axisNames = axisNames,
        _axisUnits = axisUnits,
        _sampleValues = sampleValues,
        super(timestampExponent: -3);

  @override
  List<String> get axisNames => _axisNames;

  @override
  List<String> get axisUnits => _axisUnits;

  @override
  Stream<SensorDoubleValue> get sensorStream async* {
    final startedAt = DateTime.now().millisecondsSinceEpoch;

    // Seed the five-second window so a screenshot is ready on the first frame.
    for (var index = _historySamples; index >= 0; index--) {
      final timestamp = startedAt -
          index * AppStorePreviewWearable._sampleInterval.inMilliseconds;
      yield _valueAt(timestamp);
    }

    var sampleIndex = 1;
    while (true) {
      await Future<void>.delayed(AppStorePreviewWearable._sampleInterval);
      final timestamp = startedAt +
          sampleIndex * AppStorePreviewWearable._sampleInterval.inMilliseconds;
      sampleIndex++;
      yield _valueAt(timestamp);
    }
  }

  SensorDoubleValue _valueAt(int timestamp) {
    return SensorDoubleValue(
      values: _sampleValues(timestamp / Duration.millisecondsPerSecond),
      timestamp: timestamp,
    );
  }
}
