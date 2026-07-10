import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
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

const String previewPostureImuModeRandomLabel = 'Random motion';
const String previewPostureImuModeFixedLabel = 'Fixed 3 deg / 23 deg';
const double previewPostureFixedRollDegrees = 3;
const double previewPostureFixedPitchDegrees = 23;

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
        StereoDevice,
        RgbLed,
        StatusLed,
        AudioModeManager,
        MicrophoneManager<PreviewMicrophone>,
        PowerSavingModeManager {
  static const _sampleInterval = Duration(milliseconds: 20);
  static const _slowSensorInterval = Duration(milliseconds: 200);
  static const int _simulatedFirmwareDeviceId = 0x00007E42;
  static const String _simulatedAppleDeviceId =
      '2303BBB4-CDF7-4AF2-8E7C-000000007E42';
  static const String _simulatedOtherPlatformDeviceId = 'F4:12:FA:00:7E:42';
  static final _fallbackFirmwareVersion = _PreviewFirmwareVersion(
    label: '2.3.0',
    version: semver.Version(2, 3, 0),
  );
  static final Future<_PreviewFirmwareVersion> _firmwareVersionFuture =
      _loadFirmwareVersion();
  static final _disconnectNotifier = WearableDisconnectNotifier();
  static final ValueNotifier<bool> _postureImuFixedModeNotifier =
      ValueNotifier(false);
  static bool _isPostureImuFixedModeEnabled = false;
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
          name: _simulatedBluetoothName,
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

  static bool get isPostureImuFixedModeEnabled => _isPostureImuFixedModeEnabled;

  static ValueNotifier<bool> get postureImuFixedModeNotifier =>
      _postureImuFixedModeNotifier;

  static void setPostureImuFixedModeEnabled(bool isEnabled) {
    _isPostureImuFixedModeEnabled = isEnabled;
    if (_postureImuFixedModeNotifier.value != isEnabled) {
      _postureImuFixedModeNotifier.value = isEnabled;
    }
  }

  static Future<_PreviewFirmwareVersion> _loadFirmwareVersion() async {
    try {
      final latestVersion =
          await FirmwareImageRepository().getLatestFirmwareVersion();
      return _PreviewFirmwareVersion(
        label: latestVersion,
        version: semver.Version.parse(latestVersion),
      );
    } catch (_) {
      return _fallbackFirmwareVersion;
    }
  }

  static String get _simulatedBluetoothName =>
      'OpenEarable-${(_simulatedFirmwareDeviceId & 0xFFFF).toRadixString(16).toUpperCase().padLeft(4, '0')}';

  static String get _simulatedDeviceIdentifierLabel =>
      '0x${_simulatedFirmwareDeviceId.toRadixString(16).toUpperCase().padLeft(8, '0')}';

  static String get _simulatedPlatformDeviceId {
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return _simulatedAppleDeviceId;
      default:
        return _simulatedOtherPlatformDeviceId;
    }
  }

  static bool get _supportsPreviewMicrophoneStreaming =>
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.windows;

  List<SensorConfiguration> _buildSensorConfigurations() {
    return [
      _configuration(
        name: '9-Axis IMU',
        frequencies: const [25, 50, 100, 200, 400, 800],
        initialFrequency: 50,
      ),
      _configuration(
        name: 'Pulse Oximeter',
        frequencies: const [
          25,
          50,
          84,
          100,
          200,
          400,
          8,
          16,
          32,
          64,
          128,
          256,
          512,
          1024,
          2048,
          4096,
        ],
        initialFrequency: 50,
      ),
      _configuration(
        name: 'Skin Temperature Sensor',
        frequencies: const [0.5, 1, 2, 4, 8, 16, 32, 64],
        initialFrequency: 8,
      ),
      _configuration(
        name: 'Ear Canal Pressure Sensor',
        frequencies: const [
          0.1,
          0.2,
          0.39,
          0.78,
          1.5,
          3.1,
          6.25,
          12.5,
          25,
          50,
          100,
        ],
        initialFrequency: 6.25,
      ),
      _configuration(
        name: 'Bone Conduction Accelerometer',
        frequencies: const [12.5, 25, 50, 100, 200, 400, 800, 1600, 3200, 6400],
        initialFrequency: 50,
      ),
      _configuration(
        name: 'Microphones',
        frequencies: const [
          2000,
          3000,
          4000,
          6000,
          8000,
          12000,
          16000,
          24000,
          48000,
        ],
        initialFrequency: 48000,
        supportsStreaming: _supportsPreviewMicrophoneStreaming,
      ),
    ];
  }

  _PreviewSensorConfiguration _configuration({
    required String name,
    required List<double> frequencies,
    required double initialFrequency,
    bool supportsStreaming = true,
  }) {
    final values = <_PreviewSensorConfigurationValue>[
      _PreviewSensorConfigurationValue(frequencyHz: 0),
      for (final frequency in frequencies) ...[
        _PreviewSensorConfigurationValue(frequencyHz: frequency),
        if (supportsStreaming)
          _PreviewSensorConfigurationValue(
            frequencyHz: frequency,
            options: {const StreamSensorConfigOption()},
          ),
        _PreviewSensorConfigurationValue(
          frequencyHz: frequency,
          options: {const RecordSensorConfigOption()},
        ),
        if (supportsStreaming)
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
          value.options.any(
            (option) => supportsStreaming
                ? option is StreamSensorConfigOption
                : option is RecordSensorConfigOption,
          ),
    );

    return _PreviewSensorConfiguration(
      name: name,
      values: values,
      initialValue: initialValue,
      availableOptions: {
        if (supportsStreaming) const StreamSensorConfigOption(),
        const RecordSensorConfigOption(),
      },
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
        sensorName: 'ACCELEROMETER',
        chartTitle: 'ACCELEROMETER',
        shortChartTitle: 'Accel.',
        axisNames: const ['X', 'Y', 'Z'],
        axisUnits: const ['m/s²', 'm/s²', 'm/s²'],
        sampleValues: _accelerometerValues,
      ),
      _PreviewSensor(
        sensorName: 'GYROSCOPE',
        chartTitle: 'GYROSCOPE',
        shortChartTitle: 'Gyro.',
        axisNames: const ['X', 'Y', 'Z'],
        axisUnits: const ['°/s', '°/s', '°/s'],
        sampleValues: _gyroscopeValues,
      ),
      _PreviewSensor(
        sensorName: 'MAGNETOMETER',
        chartTitle: 'MAGNETOMETER',
        shortChartTitle: 'Mag.',
        axisNames: const ['X', 'Y', 'Z'],
        axisUnits: const ['µT', 'µT', 'µT'],
        sampleValues: _magnetometerValues,
      ),
      _PreviewSensor(
        sensorName: 'PHOTOPLETHYSMOGRAPH',
        chartTitle: 'photoplethysmography',
        shortChartTitle: 'PPG',
        axisNames: const ['RED', 'IR', 'GREEN', 'AMBIENT'],
        axisUnits: const ['ADC', 'ADC', 'ADC', 'ADC'],
        sampleValues: _ppgValues,
      ),
      _PreviewSensor(
        sensorName: 'OPTICAL_TEMPERATURE_SENSOR',
        chartTitle: 'OPTICAL_TEMPERATURE_SENSOR',
        shortChartTitle: 'Skin temp.',
        axisNames: const ['Temperature'],
        axisUnits: const ['°C'],
        sampleValues: (seconds) => [_skinTemperatureValue(seconds)],
        sampleInterval: _slowSensorInterval,
      ),
      _PreviewSensor(
        sensorName: 'TEMPERATURE_SENSOR',
        chartTitle: 'TEMPERATURE_SENSOR',
        shortChartTitle: 'Baro temp.',
        axisNames: const ['Temperature'],
        axisUnits: const ['°C'],
        sampleValues: (seconds) => [_barometerTemperatureValue(seconds)],
        sampleInterval: _slowSensorInterval,
      ),
      _PreviewSensor(
        sensorName: 'BAROMETER',
        chartTitle: 'BAROMETER',
        shortChartTitle: 'BAROMETER',
        axisNames: const ['Pressure'],
        axisUnits: const ['Pa'],
        sampleValues: (seconds) => [_pressureValue(seconds)],
        sampleInterval: _slowSensorInterval,
      ),
      _PreviewSensor(
        sensorName: 'ACCELEROMETER',
        chartTitle: 'ACCELEROMETER',
        shortChartTitle: 'Bone accel.',
        axisNames: const ['X', 'Y', 'Z'],
        axisUnits: const ['g', 'g', 'g'],
        sampleValues: _boneConductionValues,
      ),
    ];
  }

  /// Simulates gravity-compensated acceleration for a device mounted a short
  /// distance from the head's rotation center. At rest, all axes sit near 0.
  static List<double> _accelerometerValues(double seconds) {
    if (_isPostureImuFixedModeEnabled) {
      return _fixedPostureTrackerAccelerometerValues();
    }

    const derivativeWindowSeconds = 0.09;
    const leverArm = [0.035, -0.028, 0.045];
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
    final linearAcceleration = _linearAccelerationAt(seconds);

    return [
      linearAcceleration[0] +
          tangentialAcceleration[0] +
          0.72 * centripetalAcceleration[0] +
          _accelerometerMeasurementNoise(seconds, 40),
      linearAcceleration[1] +
          tangentialAcceleration[1] +
          0.72 * centripetalAcceleration[1] +
          _accelerometerMeasurementNoise(seconds, 41),
      linearAcceleration[2] +
          tangentialAcceleration[2] +
          0.72 * centripetalAcceleration[2] +
          _accelerometerMeasurementNoise(seconds, 42),
    ];
  }

  static double _accelerometerMeasurementNoise(double seconds, int seed) {
    return 0.055 * _smoothRandom(seconds, seed, 8) +
        0.030 * _smoothRandom(seconds, seed + 10, 14) +
        0.016 * _smoothRandom(seconds, seed + 20, 28);
  }

  /// The posture tracker derives roll/pitch directly from the accelerometer
  /// and assumes a left-ear reference roll of -90 deg during calibration.
  /// Feed it a gravity vector that resolves to the requested displayed angles
  /// without changing the tracker implementation itself.
  static List<double> _fixedPostureTrackerAccelerometerValues() {
    const gravity = 9.80665;
    final targetTrackerRollRadians =
        previewPostureFixedRollDegrees * math.pi / 180;
    final targetTrackerPitchRadians =
        previewPostureFixedPitchDegrees * math.pi / 180;

    // EarableAttitudeTracker reports:
    // displayedRoll = -rawRoll + pi/2 for the simulated left device
    // displayedPitch = rawPitch
    final rawRollRadians = math.pi / 2 - targetTrackerRollRadians;
    final rawPitchRadians = targetTrackerPitchRadians;

    final ax = -math.sin(rawPitchRadians);
    final ay = math.sin(rawRollRadians) * math.cos(rawPitchRadians);
    final az = math.cos(rawRollRadians) * math.cos(rawPitchRadians);

    return [
      gravity * ax,
      gravity * ay,
      -gravity * az,
    ];
  }

  /// Produces smooth head-translation sway that dominates the preview
  /// accelerometer more than the rotational lever-arm component does.
  static List<double> _linearAccelerationAt(double seconds) {
    final motionSeconds = _imuMotionTime(seconds);
    final settle =
        _motionEvent(motionSeconds, 0.34, 1.04, edgeSeconds: 0.12, seed: 100);
    final lean =
        _motionEvent(motionSeconds, 1.18, 1.92, edgeSeconds: 0.10, seed: 101);
    final nod =
        _motionEvent(motionSeconds, 1.92, 2.42, edgeSeconds: 0.08, seed: 102);
    final rebound =
        _motionEvent(motionSeconds, 2.48, 3.10, edgeSeconds: 0.09, seed: 103);
    final sweep =
        _motionEvent(motionSeconds, 3.00, 4.04, edgeSeconds: 0.10, seed: 104);
    final glance =
        _motionEvent(motionSeconds, 4.06, 4.54, edgeSeconds: 0.06, seed: 105);
    final correction =
        _motionEvent(motionSeconds, 4.44, 5.10, edgeSeconds: 0.07, seed: 106);
    final surge =
        _motionEvent(motionSeconds, 2.66, 3.42, edgeSeconds: 0.07, seed: 107);
    final settleTail =
        _motionEvent(motionSeconds, 4.72, 5.42, edgeSeconds: 0.08, seed: 108);
    final lowBand = [
      _smoothRandom(motionSeconds, 90, 0.24),
      _smoothRandom(motionSeconds, 91, 0.26),
      _smoothRandom(motionSeconds, 92, 0.22),
    ];
    final midBand = [
      _smoothRandom(motionSeconds, 93, 0.96),
      _smoothRandom(motionSeconds, 94, 1.08),
      _smoothRandom(motionSeconds, 95, 0.88),
    ];
    final texture = [
      _smoothRandom(motionSeconds, 96, 2.9),
      _smoothRandom(motionSeconds, 97, 3.2),
      _smoothRandom(motionSeconds, 98, 2.7),
    ];

    return [
      5.6 * settle -
          5.0 * lean +
          2.8 * nod +
          2.4 * rebound +
          4.4 * sweep -
          5.8 * correction -
          2.0 * surge +
          2.4 * settleTail +
          1.6 * lowBand[0] +
          1.3 * midBand[0] +
          0.8 * texture[0] -
          0.32 * (lowBand[1] - midBand[2]),
      -4.0 * settle +
          3.8 * lean -
          6.2 * nod +
          3.6 * rebound -
          4.1 * sweep +
          1.8 * glance +
          2.3 * surge -
          1.5 * settleTail +
          1.3 * lowBand[1] +
          1.1 * midBand[1] +
          0.9 * texture[1] +
          0.28 * (midBand[0] + texture[2]),
      -5.0 * settle +
          7.2 * lean +
          8.0 * nod -
          5.2 * rebound -
          5.0 * sweep +
          4.8 * glance +
          5.4 * correction +
          2.0 * surge +
          2.0 * settleTail +
          1.8 * lowBand[2] +
          1.5 * midBand[2] +
          1.0 * texture[2] -
          0.30 * (midBand[0] + lowBand[1]),
    ];
  }

  /// These sensors are effectively stationary in the preview. Only a small
  /// sample-level measurement error is visible instead of simulated movement.
  static double _pressureValue(double seconds) {
    return 101235.5234375 + _pressureSensorNoise(seconds, 9);
  }

  static double _skinTemperatureValue(double seconds) {
    return 34.20 + _temperatureSensorNoise(seconds, 50, scale: 0.028);
  }

  static double _barometerTemperatureValue(double seconds) {
    return 32.80 + _temperatureSensorNoise(seconds, 52, scale: 0.022);
  }

  /// Barometers usually show tiny quantized step changes around a stable
  /// atmospheric baseline. The device samples discretely, but the chart should
  /// connect those points instead of rendering a staircase.
  static double _pressureSensorNoise(double seconds, int seed) {
    final jagged = _sampledLine(seconds, seed, 8.0);
    final slowDrift = 1.8 * _smoothRandom(seconds, seed + 21, 0.045) +
        0.9 * _smoothRandom(seconds, seed + 31, 0.11);
    final combined = 10.5 * jagged + slowDrift;

    return (combined / 0.125).roundToDouble() * 0.125;
  }

  /// Temperature channels are sampled at a low rate, but the chart should
  /// connect successive samples directly. Keep the jagged look while allowing
  /// a very slow baseline wander over time.
  static double _temperatureSensorNoise(
    double seconds,
    int seed, {
    required double scale,
  }) {
    final jagged = _sampledLine(seconds, seed, 8.0);
    final slowDrift = 0.40 * _smoothRandom(seconds, seed + 23, 0.040) +
        0.22 * _smoothRandom(seconds, seed + 33, 0.085);
    final combined = 0.90 * jagged + 0.10 * slowDrift;

    return (combined * scale / 0.001).roundToDouble() * 0.001;
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
    if (_isPostureImuFixedModeEnabled) {
      return [4600.0, 1750.0, 3825.0];
    }

    const earthField = [34.0, -12.0, 25.0];
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
    final rotatedY = cosRoll * yawY + sinRoll * pitchZ;
    final rotatedZ = -sinRoll * yawY + cosRoll * pitchZ;
    final crossAxisX = 0.55 * rotatedY - 0.28 * rotatedZ;
    final crossAxisY = 0.42 * pitchX + 0.24 * rotatedZ;

    final sharedDrift = 28 * _smoothRandom(seconds, 6, 0.24) +
        12 * _smoothRandom(seconds, 16, 1.3);
    final xTexture = 14 * _smoothRandom(seconds, 26, 2.8) +
        8 * _smoothRandom(seconds, 36, 5.4);
    final yTexture = 12 * _smoothRandom(seconds, 27, 2.6) +
        7 * _smoothRandom(seconds, 37, 4.8);
    final zTexture = 5 * _smoothRandom(seconds, 28, 2.4) +
        3 * _smoothRandom(seconds, 38, 4.0);

    return [
      4550 + 7.2 * pitchX + 5.0 * crossAxisX + sharedDrift + xTexture,
      1710 + 7.6 * rotatedY + 4.2 * crossAxisY + 0.62 * sharedDrift + yTexture,
      3835 + 1.5 * rotatedZ + 0.12 * pitchX + 0.20 * sharedDrift + zTexture,
    ];
  }

  /// Calculates angular velocity from the same roll/pitch used by the
  /// accelerometer. The components are expressed in the device coordinate
  /// system and converted from radians to degrees per second.
  static List<double> _gyroscopeValues(double seconds) {
    if (_isPostureImuFixedModeEnabled) {
      return [0.0, 0.0, 0.0];
    }

    const radiansToDegrees = 180 / math.pi;
    final angularVelocity = _angularVelocityAt(seconds);
    final spikes = _gyroscopeSpikes(seconds);
    final wobble = [
      14 * _smoothRandom(seconds, 200, 1.8) +
          10 * _smoothRandom(seconds, 210, 4.8),
      13 * _smoothRandom(seconds, 201, 1.8) +
          10 * _smoothRandom(seconds, 211, 4.8),
      14 * _smoothRandom(seconds, 202, 1.7) +
          10 * _smoothRandom(seconds, 212, 4.6),
    ];

    return [
      angularVelocity[0] * radiansToDegrees +
          spikes[0] +
          wobble[0] +
          _gyroscopeNoise(seconds, 20),
      angularVelocity[1] * radiansToDegrees +
          spikes[1] +
          wobble[1] +
          _gyroscopeNoise(seconds, 21),
      angularVelocity[2] * radiansToDegrees +
          spikes[2] +
          wobble[2] +
          _gyroscopeNoise(seconds, 22),
    ];
  }

  static double _gyroscopeNoise(double seconds, int seed) {
    return 11.0 * _smoothRandom(seconds, seed, 5.8) +
        13.0 * _smoothRandom(seconds, seed + 10, 17.0) +
        10.5 * _smoothRandom(seconds, seed + 20, 36) +
        5.0 * _smoothRandom(seconds, seed + 30, 62);
  }

  static List<double> _gyroscopeSpikes(double seconds) {
    final impulseA = _spikeEvent(seconds, 0.88, widthSeconds: 0.028, seed: 120);
    final impulseB = _spikeEvent(seconds, 1.98, widthSeconds: 0.024, seed: 121);
    final impulseC = _spikeEvent(seconds, 2.82, widthSeconds: 0.026, seed: 122);
    final impulseD = _spikeEvent(seconds, 3.96, widthSeconds: 0.030, seed: 123);
    final impulseE = _spikeEvent(seconds, 4.48, widthSeconds: 0.021, seed: 124);
    final impulseF = _spikeEvent(seconds, 4.92, widthSeconds: 0.023, seed: 125);

    return [
      50 * impulseA +
          58 * impulseB -
          42 * impulseC +
          38 * impulseD -
          46 * impulseE +
          34 * impulseF,
      -42 * impulseA -
          36 * impulseB +
          44 * impulseC +
          34 * impulseD +
          40 * impulseE -
          32 * impulseF,
      44 * impulseA -
          34 * impulseB +
          50 * impulseC +
          40 * impulseD +
          48 * impulseE -
          34 * impulseF,
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
    if (_isPostureImuFixedModeEnabled) {
      return _PreviewOrientation(
        pitch: previewPostureFixedPitchDegrees * math.pi / 180,
        roll: previewPostureFixedRollDegrees * math.pi / 180,
        yaw: 0.0,
      );
    }

    final motionSeconds = _imuMotionTime(seconds);
    final yawSweep =
        _motionEvent(motionSeconds, 0.50, 1.20, edgeSeconds: 0.08, seed: 130);
    final rollSettle =
        _motionEvent(motionSeconds, 1.14, 1.82, edgeSeconds: 0.08, seed: 131);
    final nodForward =
        _motionEvent(motionSeconds, 1.90, 2.36, edgeSeconds: 0.07, seed: 132);
    final nodRecover =
        _motionEvent(motionSeconds, 2.34, 2.92, edgeSeconds: 0.07, seed: 133);
    final yawReturn =
        _motionEvent(motionSeconds, 3.00, 3.86, edgeSeconds: 0.08, seed: 134);
    final quickGlance =
        _motionEvent(motionSeconds, 4.02, 4.42, edgeSeconds: 0.05, seed: 135);
    final glanceRecover =
        _motionEvent(motionSeconds, 4.38, 4.82, edgeSeconds: 0.05, seed: 136);
    final microTilt =
        _motionEvent(motionSeconds, 2.62, 3.16, edgeSeconds: 0.06, seed: 137);
    final rollSweep =
        _motionEvent(motionSeconds, 0.92, 1.62, edgeSeconds: 0.08, seed: 138);
    final pitchSweep =
        _motionEvent(motionSeconds, 3.44, 4.16, edgeSeconds: 0.08, seed: 139);
    final corkscrew =
        _motionEvent(motionSeconds, 1.56, 2.74, edgeSeconds: 0.09, seed: 140);
    final yawDip =
        _motionEvent(motionSeconds, 4.66, 5.22, edgeSeconds: 0.06, seed: 141);
    final settleDrift = _smoothRandom(motionSeconds, 70, 0.20);
    final postureDrift = _smoothRandom(motionSeconds, 71, 0.31);
    final midDrift = _smoothRandom(motionSeconds, 72, 1.05);
    final texture = _smoothRandom(motionSeconds, 73, 3.1);

    return _PreviewOrientation(
      pitch: 0.11 +
          0.038 * settleDrift +
          0.022 * postureDrift +
          0.018 * midDrift +
          0.010 * texture +
          0.42 * nodForward -
          0.36 * nodRecover +
          0.18 * pitchSweep -
          0.12 * quickGlance +
          0.14 * yawSweep -
          0.10 * yawReturn +
          0.16 * microTilt +
          0.20 * corkscrew -
          0.10 * rollSweep,
      roll: -0.03 +
          0.040 * settleDrift -
          0.024 * postureDrift +
          0.016 * midDrift +
          0.010 * texture +
          0.28 * yawSweep -
          0.24 * yawReturn +
          0.30 * rollSettle +
          0.24 * rollSweep -
          0.18 * glanceRecover -
          0.14 * microTilt +
          0.08 * nodForward -
          0.12 * pitchSweep +
          0.18 * corkscrew,
      yaw: 0.01 +
          0.030 * settleDrift +
          0.020 * midDrift +
          0.54 * yawSweep -
          0.46 * yawReturn +
          0.28 * quickGlance -
          0.24 * glanceRecover +
          0.18 * rollSettle +
          0.16 * microTilt +
          0.20 * rollSweep +
          0.16 * pitchSweep +
          0.22 * corkscrew -
          0.18 * yawDip,
    );
  }

  static double _imuMotionTime(double seconds) => seconds * 1.12;

  /// Returns a smooth, deterministic movement event whose timing and amplitude
  /// shift slightly from cycle to cycle so the preview does not loop obviously.
  static double _motionEvent(
    double seconds,
    double startSeconds,
    double endSeconds, {
    required double edgeSeconds,
    required int seed,
  }) {
    const cycleSeconds = 5.8;
    final cycleIndex = (seconds / cycleSeconds).floor();
    final phase = seconds - cycleIndex * cycleSeconds;
    final startJitter = 0.14 * _randomAt(cycleIndex, seed);
    final endJitter = 0.14 * _randomAt(cycleIndex, seed + 17);
    final edgeScale = 1 + 0.18 * _randomAt(cycleIndex, seed + 31);
    final amplitude = 1 + 0.28 * _randomAt(cycleIndex, seed + 43);
    final start = _sigmoid(
      (phase - (startSeconds + startJitter)) / (edgeSeconds * edgeScale),
    );
    final end = _sigmoid(
      (phase - (endSeconds + endJitter)) / (edgeSeconds * edgeScale),
    );
    return amplitude * (start - end);
  }

  static double _sigmoid(double value) => 1 / (1 + math.exp(-2 * value));

  static double _spikeEvent(
    double seconds,
    double centerSeconds, {
    required double widthSeconds,
    required int seed,
  }) {
    const cycleSeconds = 5.8;
    final cycleIndex = (seconds / cycleSeconds).floor();
    final phase = seconds - cycleIndex * cycleSeconds;
    final centerJitter = 0.12 * _randomAt(cycleIndex, seed);
    final amplitude = 1 + 0.35 * _randomAt(cycleIndex, seed + 9);
    final widthScale = 1 + 0.22 * _randomAt(cycleIndex, seed + 21);
    final normalized =
        (phase - (centerSeconds + centerJitter)) / (widthSeconds * widthScale);
    return amplitude * normalized * math.exp(-0.5 * normalized * normalized);
  }

  static double _sampledLine(double seconds, int seed, double sampleRateHz) {
    final position = seconds * sampleRateHz;
    final leftIndex = position.floor();
    final fraction = position - leftIndex;
    final start = _randomAt(leftIndex, seed);
    final end = _randomAt(leftIndex + 1, seed);
    return start + (end - start) * fraction;
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

  // Keep the simulated waveform aligned with the heart tracker default so the
  // preview chart cadence matches the BPM the app reports.
  static const double _previewHeartRateBpm = 75.0;
  static const double _ppgHeartRateHz = _previewHeartRateBpm / 60.0;

  // Averaged from the provided OpenEarable PPG recording. The optical raw
  // values dip quickly at the pulse peak and recover slowly, while the larger
  // raw min/max range comes from slow contact/baseline movement.
  static const List<double> _ppgPulseAbsorptionTemplate = [
    0.09,
    0.07,
    0.05,
    0.03,
    0.02,
    0.05,
    0.18,
    0.34,
    0.52,
    0.68,
    0.83,
    0.92,
    0.96,
    0.94,
    0.87,
    0.77,
    0.64,
    0.54,
    0.46,
    0.42,
    0.44,
    0.50,
    0.57,
    0.63,
    0.67,
    0.65,
    0.60,
    0.54,
    0.49,
    0.45,
    0.41,
    0.37,
    0.34,
    0.31,
    0.29,
    0.27,
    0.25,
    0.23,
    0.22,
    0.21,
    0.20,
    0.19,
    0.18,
    0.17,
    0.16,
    0.15,
    0.13,
    0.11,
  ];

  static List<double> _ppgValues(double seconds) {
    final heartbeatPosition = seconds * _ppgHeartRateHz +
        0.008 * math.sin(2 * math.pi * 0.070 * seconds + 1.2) +
        0.004 * _smoothRandom(seconds, 41, 0.16);
    final phase = heartbeatPosition - heartbeatPosition.floor();
    final pulseAbsorption =
        _templateValueAt(phase, _ppgPulseAbsorptionTemplate);

    final baselineDrift = 0.68 * _smoothRandom(seconds, 42, 0.045) +
        0.32 * math.sin(2 * math.pi * 0.075 * seconds + 0.45);
    final respirationDrift = math.sin(2 * math.pi * 0.18 * seconds + 0.60);
    final beatScale = 1 +
        0.070 * _smoothRandom(heartbeatPosition, 43, 0.50) +
        0.035 * math.sin(2 * math.pi * 0.11 * seconds - 0.35);
    final sharedFineNoise = 20 * _sampledLine(seconds, 53, 50.0) +
        8 * _smoothRandom(seconds, 63, 1.4);

    return [
      128600 +
          760 * baselineDrift +
          90 * respirationDrift -
          2920 * pulseAbsorption * beatScale +
          sharedFineNoise +
          14 * _sampledLine(seconds, 44, 50.0),
      53500 +
          3050 * baselineDrift +
          220 * respirationDrift -
          3450 * pulseAbsorption * beatScale +
          0.65 * sharedFineNoise +
          18 * _sampledLine(seconds, 45, 50.0),
      166520 +
          570 * baselineDrift +
          70 * respirationDrift -
          1880 * pulseAbsorption * beatScale +
          0.72 * sharedFineNoise +
          12 * _sampledLine(seconds, 46, 50.0),
      (197 +
              3.2 * _smoothRandom(seconds, 47, 0.12) +
              0.85 * _sampledLine(seconds, 48, 50.0))
          .roundToDouble(),
    ];
  }

  static double _templateValueAt(double phase, List<double> template) {
    if (template.isEmpty) {
      return 0;
    }
    final wrappedPhase = phase - phase.floor();
    final position = wrappedPhase * template.length;
    final leftIndex = position.floor() % template.length;
    final rightIndex = (leftIndex + 1) % template.length;
    final fraction = position - position.floor();
    final start = template[leftIndex];
    final end = template[rightIndex];
    final easedFraction = fraction * fraction * (3 - 2 * fraction);
    return start + (end - start) * easedFraction;
  }

  @override
  String get deviceId => _simulatedPlatformDeviceId;

  @override
  List<Sensor> get sensors => _sensors;

  @override
  List<SensorConfiguration> get sensorConfigurations => _sensorConfigurations;

  @override
  Stream<Map<SensorConfiguration, SensorConfigurationValue>>
      get sensorConfigurationStream => _sensorConfigurationController.stream;

  @override
  Future<String?> readDeviceIdentifier() async =>
      _simulatedDeviceIdentifierLabel;

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
  Future<String?> readDeviceFirmwareVersion() async =>
      (await _firmwareVersionFuture).label;

  @override
  Future<semver.Version?> readFirmwareVersionNumber() async =>
      (await _firmwareVersionFuture).version;

  @override
  semver.VersionConstraint get supportedFirmwareRange =>
      semver.VersionConstraint.any;

  @override
  Future<FirmwareSupportStatus> checkFirmwareSupport() async =>
      FirmwareSupportStatus.supported;

  @override
  Future<String?> readDeviceHardwareVersion() async => '2.0.1';

  @override
  Future<DevicePosition?> get position async => DevicePosition.left;

  @override
  Future<StereoDevice?> get pairedDevice async => null;

  @override
  Future<void> pair(StereoDevice device) async {}

  @override
  Future<void> unpair() async {}

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

    if (!darkmode) {
      switch (variant) {
        case WearableIconVariant.left:
          return '$basePath/left.png';
        case WearableIconVariant.right:
          return '$basePath/right.png';
        case WearableIconVariant.pair:
          return '$basePath/pair.png';
        case WearableIconVariant.single:
          break;
      }
    }

    if (darkmode) {
      return '$basePath/icon_no_text_white.svg';
    }

    return '$basePath/icon_no_text.svg';
  }
}

class _PreviewFirmwareVersion {
  final String label;
  final semver.Version version;

  const _PreviewFirmwareVersion({
    required this.label,
    required this.version,
  });
}

class _PreviewSensorConfiguration
    extends SensorFrequencyConfiguration<_PreviewSensorConfigurationValue>
    implements
        ConfigurableSensorConfiguration<_PreviewSensorConfigurationValue> {
  final void Function(SensorConfiguration, SensorConfigurationValue) _onChanged;
  _PreviewSensorConfigurationValue _currentValue;

  @override
  final Set<SensorConfigurationOption> availableOptions;

  _PreviewSensorConfiguration({
    required super.name,
    required super.values,
    required _PreviewSensorConfigurationValue initialValue,
    required this.availableOptions,
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
  static const _historyWindow = Duration(seconds: 5);
  final List<String> _axisNames;
  final List<String> _axisUnits;
  final List<double> Function(double seconds) _sampleValues;
  final Duration _sampleInterval;

  _PreviewSensor({
    required super.sensorName,
    required super.chartTitle,
    required super.shortChartTitle,
    required List<String> axisNames,
    required List<String> axisUnits,
    required List<double> Function(double seconds) sampleValues,
    Duration sampleInterval = AppStorePreviewWearable._sampleInterval,
  })  : _axisNames = axisNames,
        _axisUnits = axisUnits,
        _sampleValues = sampleValues,
        _sampleInterval = sampleInterval,
        super(timestampExponent: -3);

  @override
  List<String> get axisNames => _axisNames;

  @override
  List<String> get axisUnits => _axisUnits;

  @override
  Stream<SensorDoubleValue> get sensorStream async* {
    final startedAt = DateTime.now().millisecondsSinceEpoch;
    final historySamples =
        (_historyWindow.inMilliseconds / _sampleInterval.inMilliseconds)
            .round();

    // Seed the five-second window so a screenshot is ready on the first frame.
    for (var index = historySamples; index >= 0; index--) {
      final timestamp = startedAt - index * _sampleInterval.inMilliseconds;
      yield _valueAt(timestamp);
    }

    var sampleIndex = 1;
    while (true) {
      await Future<void>.delayed(_sampleInterval);
      final timestamp =
          startedAt + sampleIndex * _sampleInterval.inMilliseconds;
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
