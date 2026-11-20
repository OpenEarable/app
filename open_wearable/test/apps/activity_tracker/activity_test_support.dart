import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:open_earable_flutter/open_earable_flutter.dart';
import 'package:open_wearable/apps/activity_tracker/models/activity_models.dart';
import 'package:open_wearable/apps/activity_tracker/services/activity_sensor_source.dart';
import 'package:open_wearable/apps/activity_tracker/services/activity_storage.dart';

class MemoryActivityStorage extends ActivityStorage {
  Map<String, dynamic>? snapshot;
  int rawSamples = 0;
  @override
  Future<Map<String, dynamic>?> load() async => snapshot;
  @override
  Future<void> save(Map<String, dynamic> value) async {
    snapshot = jsonDecode(jsonEncode(value));
  }

  @override
  Future<void> startTrace(String id) async {}
  @override
  void append(
    MotionSample s,
    ActivityKind kind,
    bool paused,
    bool calibrated,
    int steps,
    int reps,
    double? height,
  ) {
    rawSamples++;
  }

  @override
  Future<void> flushTrace() async {}
  @override
  Future<void> closeTrace() async {}
}

class ReplayActivitySource implements ActivitySensorSource {
  final data = StreamController<MotionSample>.broadcast(sync: true);
  final status = StreamController<String?>.broadcast(sync: true);
  double time = 0;
  bool closed = false;
  @override
  String get deviceName => 'OpenEarable 2.0 (L)';
  @override
  Stream<MotionSample> get samples => data.stream;
  @override
  Stream<String?> get interruptions => status.stream;
  @override
  Future<void> open(String deviceId) async {
    closed = false;
  }

  @override
  Future<void> close() async {
    closed = true;
  }

  void emit(double z) {
    time += 0.01;
    data.add(
      MotionSample(
        time,
        MotionVector(0, 0, z),
        gyroscope: MotionVector.zero,
      ),
    );
  }

  void still([int samples = 200]) {
    for (var i = 0; i < samples; i++) {
      emit(9.80665);
    }
  }

  void walk(int steps) {
    for (var i = 0; i < steps * 50; i++) {
      emit(9.80665 + 2.8 * math.sin(2 * math.pi * 2 * i / 100));
    }
    still(40);
  }

  @override
  void dispose() {
    data.close();
    status.close();
  }
}

class TestActivityWearable extends Wearable {
  TestActivityWearable()
      : super(
          name: 'OpenEarable 2.0 (L)',
          disconnectNotifier: WearableDisconnectNotifier(),
        );
  @override
  String get deviceId => 'activity-test-ear';
  @override
  Future<void> disconnect() async {}
}
