import 'dart:async';
import 'dart:math' as math;
import 'package:open_earable_flutter/open_earable_flutter.dart';
import 'package:open_wearable/models/sensor_streams.dart';
import 'package:open_wearable/view_models/sensor_configuration_provider.dart';
import 'package:open_wearable/view_models/wearables_provider.dart';
import '../models/activity_models.dart';

/// Replaceable input for live OpenEarable streams or deterministic replay.
abstract class ActivitySensorSource {
  Stream<MotionSample> get samples;
  Stream<String?> get interruptions;
  String get deviceName;
  Future<void> open(String deviceId);
  Future<void> close();
  void dispose();
}

/// Owns only the IMU configuration changes made by Activity Tracker.
/// Rebinds streams by device ID when the SDK creates a new wearable on reconnect.
class OpenEarableActivitySource implements ActivitySensorSource {
  OpenEarableActivitySource(this.wearables) {
    wearables.addListener(_devicesChanged);
  }
  final WearablesProvider wearables;
  final _samples = StreamController<MotionSample>.broadcast();
  final _interruptions = StreamController<String?>.broadcast();
  final List<StreamSubscription> _subscriptions = [];
  final Map<SensorConfiguration,
      (SensorConfigurationValue?, SensorConfigurationValue)> _owned = {};
  String? _deviceId;
  Wearable? _wearable;
  SensorConfigurationProvider? _configurationProvider;
  final List<(double, MotionVector)> _gyros = [];
  final List<(double, MotionVector)> _accelerations = [];
  bool _binding = false, _disposed = false;
  @override
  Stream<MotionSample> get samples => _samples.stream;
  @override
  Stream<String?> get interruptions => _interruptions.stream;
  @override
  String get deviceName => _wearable?.name ?? 'OpenEarable';

  @override
  Future<void> open(String deviceId) async {
    if (_deviceId != deviceId) await close();
    _deviceId = deviceId;
    await _bind(force: true);
  }

  void _devicesChanged() {
    if (_deviceId == null || _disposed) return;
    final current =
        wearables.wearables.where((w) => w.deviceId == _deviceId).firstOrNull;
    if (!identical(current, _wearable)) {
      unawaited(
        _bind().catchError((Object e) {
          if (!_disposed) _interruptions.add('Unable to reconnect: $e');
        }),
      );
    }
  }

  Future<void> _bind({bool force = false}) async {
    if (_binding || _disposed || _deviceId == null) return;
    _binding = true;
    final attemptedWearable =
        wearables.wearables.where((w) => w.deviceId == _deviceId).firstOrNull;
    try {
      final next = attemptedWearable;
      if (!force && identical(next, _wearable) && _subscriptions.isNotEmpty) {
        return;
      }
      await _unbind(restore: force);
      if (_disposed || _deviceId == null) return;
      _wearable = next;
      if (next == null) {
        _interruptions.add('Connection lost');
        return;
      }
      if (!next.hasCapability<SensorManager>()) {
        throw StateError('No sensor streaming capability');
      }
      final sensors = next.requireCapability<SensorManager>().sensors;
      Sensor? find(String token) => sensors
          .where(
            (s) =>
                '${s.sensorName} ${s.chartTitle}'
                    .toLowerCase()
                    .contains(token) &&
                s.axisCount == 3,
          )
          .firstOrNull;
      final acc = find('accelerometer');
      final gyro = find('gyroscope');
      if (acc == null || gyro == null) {
        throw StateError('Accelerometer and gyroscope are required');
      }
      if (!acc.axisUnits.every((u) => ['m/s²', 'm/s^2', 'm/s2'].contains(u))) {
        throw StateError(
          'Unsupported acceleration units: ${acc.axisUnits.join(', ')}',
        );
      }
      final gyroDegrees =
          gyro.axisUnits.every((u) => ['dps', 'deg/s', '°/s'].contains(u));
      if (!gyroDegrees && !gyro.axisUnits.every((u) => u == 'rad/s')) {
        throw StateError('Unsupported angular velocity units');
      }
      _configurationProvider = wearables.getSensorConfigurationProvider(next);
      // Shared accelerometer/gyroscope configurations are applied once.
      for (final c in {
        ...acc.relatedConfigurations,
        ...gyro.relatedConfigurations,
      }) {
        _configure(c);
      }
      _subscriptions.add(
        SensorStreams.shared(wearable: next, sensor: gyro).listen(
          (s) {
            final v = _vector(s);
            if (v == null) return;
            _gyros.add(
              (sensorSeconds(gyro, s), v * (gyroDegrees ? math.pi / 180 : 1)),
            );
            if (_gyros.length > 256) _gyros.removeAt(0);
            _drainSamples();
          },
          onError: _streamError,
          onDone: () => _streamError('Gyroscope stream ended'),
        ),
      );
      _subscriptions.add(
        SensorStreams.shared(wearable: next, sensor: acc).listen(
          (s) {
            final v = _vector(s);
            if (v == null) return;
            final t = sensorSeconds(acc, s);
            _accelerations.add((t, v));
            if (_accelerations.length > 128) {
              _accelerations.removeAt(0);
              _interruptions.add('Waiting for synchronized IMU data');
            }
            _drainSamples();
          },
          onError: _streamError,
          onDone: () => _streamError('Accelerometer stream ended'),
        ),
      );
      _interruptions.add(null);
    } catch (_) {
      await _unbind(restore: true);
      rethrow;
    } finally {
      _binding = false;
      // Device changes can arrive while subscriptions are being cancelled.
      if (!_disposed &&
          _deviceId != null &&
          !identical(
            attemptedWearable,
            wearables.wearables
                .where((w) => w.deviceId == _deviceId)
                .firstOrNull,
          )) {
        scheduleMicrotask(_devicesChanged);
      }
    }
  }

  void _streamError(Object e) {
    if (!_disposed) _interruptions.add('Motion stream interrupted: $e');
  }

  void _drainSamples() {
    // Buffer differently batched BLE streams. Never integrate stale gyro data;
    // hold acceleration until a timestamp-matched gyro sample has arrived.
    while (_accelerations.isNotEmpty && _gyros.isNotEmpty) {
      final acc = _accelerations.first;
      final candidates =
          _gyros.where((g) => (g.$1 - acc.$1).abs() <= 0.02).toList()
            ..sort(
              (a, b) => (a.$1 - acc.$1).abs().compareTo((b.$1 - acc.$1).abs()),
            );
      if (candidates.isEmpty) {
        if (_gyros.last.$1 > acc.$1 + 0.08) {
          _accelerations.removeAt(0);
          _interruptions.add('IMU timestamps do not match');
          continue;
        }
        break;
      }
      _accelerations.removeAt(0);
      _samples
          .add(MotionSample(acc.$1, acc.$2, gyroscope: candidates.first.$2));
    }
  }

  /// Timestamp conversion is deliberately metadata-driven (OE2 uses µs).
  static double sensorSeconds(Sensor sensor, SensorValue value) =>
      value.timestamp * math.pow(10, sensor.timestampExponent).toDouble();
  static MotionVector? _vector(SensorValue s) {
    final values = s is SensorDoubleValue
        ? s.values
        : s is SensorIntValue
            ? s.values.map((v) => v.toDouble()).toList()
            : <double>[];
    return values.length == 3
        ? MotionVector(values[0], values[1], values[2])
        : null;
  }

  void _configure(SensorConfiguration c) {
    final provider = _configurationProvider!;
    final previous = provider.getSelectedConfigurationValue(c);
    final previousOptions = previous is ConfigurableSensorConfigurationValue
        ? previous.options
        : <SensorConfigurationOption>{};
    final candidates = c.values
        .whereType<SensorFrequencyConfigurationValue>()
        .where((v) {
          if (v is ConfigurableSensorConfigurationValue) {
            final options = (v as ConfigurableSensorConfigurationValue).options;
            return options.contains(StreamSensorConfigOption()) &&
                previousOptions.every(options.contains);
          }
          return true;
        })
        .where((v) => v.frequencyHz > 0)
        .toList()
      ..sort((a, b) {
        final frequency = a.frequencyHz.compareTo(b.frequencyHz);
        if (frequency != 0) return frequency;
        final aFlags = a is ConfigurableSensorConfigurationValue
            ? (a as ConfigurableSensorConfigurationValue).options.length
            : 0;
        final bFlags = b is ConfigurableSensorConfigurationValue
            ? (b as ConfigurableSensorConfigurationValue).options.length
            : 0;
        return aFlags.compareTo(bFlags);
      });
    if (candidates.isEmpty) {
      throw StateError('No streaming frequency available for ${c.name}');
    }
    // Keep a higher existing rate; never remove an active recording option.
    final target = previous is SensorFrequencyConfigurationValue
        ? math.max(100, previous.frequencyHz)
        : 100;
    final chosen =
        candidates.where((v) => v.frequencyHz >= target).firstOrNull ??
            candidates.last;
    _owned[c] = (previous, chosen);
    provider.addSensorConfiguration(c, chosen, markPending: false);
    provider.applyConfiguration(c, chosen);
  }

  Future<void> _unbind({required bool restore}) async {
    for (final s in _subscriptions) {
      await s.cancel();
    }
    _subscriptions.clear();
    if (restore &&
        _wearable != null &&
        wearables.wearables.contains(_wearable)) {
      for (final e in _owned.entries) {
        final current =
            _configurationProvider?.getSelectedConfigurationValue(e.key);
        final original = e.value.$1;
        // Respect changes another app/recorder made after us. An unknown
        // original configuration is deliberately not guessed as "off".
        if (original != null && current == e.value.$2) {
          _configurationProvider?.addSensorConfiguration(
            e.key,
            original,
            markPending: false,
          );
          _configurationProvider?.applyConfiguration(e.key, original);
        }
      }
    }
    _owned.clear();
    _gyros.clear();
    _accelerations.clear();
    _configurationProvider = null;
    _wearable = null;
  }

  @override
  Future<void> close() async {
    _deviceId = null;
    await _unbind(restore: true);
  }

  @override
  void dispose() {
    _disposed = true;
    wearables.removeListener(_devicesChanged);
    unawaited(
      close().whenComplete(() async {
        await _samples.close();
        await _interruptions.close();
      }),
    );
  }
}
