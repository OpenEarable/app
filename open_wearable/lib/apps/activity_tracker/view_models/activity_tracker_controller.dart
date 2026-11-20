import 'dart:async';
import 'dart:collection';
import 'dart:math' as math;
import 'package:flutter/widgets.dart';
import '../models/activity_engine.dart';
import '../models/activity_models.dart';
import '../services/activity_sensor_source.dart';
import '../services/activity_storage.dart';

/// App-wide session owner: navigation never owns the live sensor subscription.
/// Confirmed results are checkpointed; incomplete cycles are never restored.
class ActivityTrackerController extends ChangeNotifier
    with WidgetsBindingObserver {
  ActivityTrackerController({
    required this.source,
    ActivityStorage? storage,
    bool observeLifecycle = true,
  })  : storage = storage ?? ActivityStorage(),
        _observeLifecycle = observeLifecycle {
    if (observeLifecycle) WidgetsBinding.instance.addObserver(this);
    ready = _load();
    _sampleSubscription = source.samples.listen(
      _onSample,
      onError: (Object e) => _interrupt('Motion stream interrupted: $e'),
    );
    _statusSubscription = source.interruptions.listen((message) {
      if (message != null) _interrupt(message);
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (deviceId == null) return;
      if (_lastArrival != null &&
          DateTime.now().difference(_lastArrival!).inSeconds >= 2 &&
          interruption == null) {
        _interrupt('Motion data interrupted');
      }
      if (isTracking && ++_ticks % 5 == 0) unawaited(checkpoint());
      _notify();
    });
  }
  final ActivitySensorSource source;
  final ActivityStorage storage;
  final bool _observeLifecycle;
  final engine = ActivityEngine();
  late final Future<void> ready;
  late final StreamSubscription<MotionSample> _sampleSubscription;
  late final StreamSubscription<String?> _statusSubscription;
  late final Timer _timer;
  final List<ActivitySession> sessions = [];
  final Map<String, int> _dailySteps = {};
  final Queue<double> _signal = Queue();
  final Queue<MotionSample> _preRoll = Queue();
  List<double> get signal => List.unmodifiable(_signal);
  ActivitySession? current;
  String? deviceId, interruption, storageError;
  bool preparing = false, paused = false, backgrounded = false;
  bool _disposed = false;
  int _ticks = 0, repetitions = 0;
  DateTime? _lastArrival, _lastUiUpdate;
  final Stopwatch _setClock = Stopwatch();
  bool get isTracking => current != null;
  bool get connected =>
      deviceId != null &&
      interruption == null &&
      _lastArrival != null &&
      DateTime.now().difference(_lastArrival!) < const Duration(seconds: 2);
  bool get canCount =>
      isTracking && connected && !paused && !backgrounded && engine.calibrated;
  String get deviceName => isTracking ? current!.deviceName : source.deviceName;
  ActivityKind get mode => engine.kind;
  int get setSeconds => _setClock.elapsed.inSeconds;
  String get _day => DateTime.now().toIso8601String().substring(0, 10);
  int get todaySteps => _dailySteps[_day] ?? 0;
  int get currentSetNumber =>
      1 + (current?.sets.where((s) => s.kind == mode).length ?? 0);

  Future<void> _load() async {
    try {
      final data = await storage.load();
      if (data == null) return;
      _dailySteps.addAll(Map<String, int>.from(data['dailySteps'] ?? {}));
      sessions.addAll(
        (data['sessions'] as List? ?? [])
            .map((s) => ActivitySession.fromJson(s)),
      );
      for (final session in sessions.where((s) => s.endedAt == null)) {
        session.interrupted = true;
        session.endedAt =
            DateTime.tryParse(data['checkpointAt'] ?? '') ?? session.startedAt;
      }
    } catch (e) {
      storageError = 'Saved sessions could not be read. $e';
    }
    _notify();
  }

  /// Opens a selected wearable; an existing session keeps its current device.
  Future<void> prepare(String id) async {
    await ready;
    if (isTracking) return;
    preparing = true;
    deviceId = id;
    interruption = 'Waiting for motion data';
    _lastArrival = null;
    _preRoll.clear();
    engine.recalibrate();
    _notify();
    try {
      await source.open(id);
    } catch (e) {
      interruption = 'Unable to start IMU streaming: $e';
    }
    preparing = false;
    _notify();
  }

  Future<void> reconnect() async {
    if (deviceId == null) return;
    engine.recalibrate();
    try {
      await source.open(deviceId!);
    } catch (e) {
      _interrupt('Unable to reconnect: $e');
    }
  }

  /// Cancels readiness streaming if the user leaves without starting a session.
  Future<void> releasePreparedDevice() async {
    if (isTracking) return;
    deviceId = null;
    await source.close();
  }

  Future<void> start() async {
    await ready;
    if (isTracking || !connected || !engine.calibrated) return;
    final now = DateTime.now();
    final session = ActivitySession(
      id: now.microsecondsSinceEpoch.toString(),
      startedAt: now,
      deviceName: source.deviceName,
      calibration: engine.calibration,
    );
    try {
      await storage.startTrace(session.id);
      for (final sample in _preRoll) {
        storage.append(sample, ActivityKind.steps, false, false, 0, 0, null);
      }
      _preRoll.clear();
    } catch (e) {
      storageError = 'Raw motion data could not be recorded. $e';
      _notify();
      return;
    }
    current = session;
    sessions.insert(0, session);
    paused = false;
    engine.select(ActivityKind.steps);
    await checkpoint();
    _notify();
  }

  void startExercise(ActivityKind kind) {
    if (!canCount || mode != ActivityKind.steps || kind == ActivityKind.steps) {
      return;
    }
    repetitions = 0;
    _setClock
      ..reset()
      ..start();
    engine.select(kind);
    _signal.clear();
    _notify();
  }

  void pause() {
    if (!isTracking) return;
    paused = true;
    _setClock.stop();
    engine.recalibrate();
    unawaited(checkpoint());
    _notify();
  }

  void resume() {
    if (!isTracking) return;
    paused = false;
    engine.recalibrate();
    if (mode != ActivityKind.steps) _setClock.start();
    _notify();
  }

  void finishSet() {
    if (current == null || mode == ActivityKind.steps) return;
    if (mode != ActivityKind.jumps) {
      current!.sets.add(
        ExerciseSet(
          kind: mode,
          repetitions: repetitions,
          seconds: setSeconds,
        ),
      );
    }
    repetitions = 0;
    _setClock
      ..stop()
      ..reset();
    paused = false;
    engine.select(ActivityKind.steps);
    unawaited(checkpoint());
    _notify();
  }

  Future<ActivitySession?> finish() async {
    if (current == null) return null;
    finishSet();
    final result = current!;
    result.endedAt = DateTime.now();
    current = null;
    deviceId = null;
    await checkpoint();
    try {
      await storage.closeTrace();
    } catch (e) {
      storageError = 'Motion trace could not be saved. $e';
    }
    await source.close();
    _notify();
    return result;
  }

  void addTrial(ActivitySession session, ValidationTrial trial) {
    session.trials.add(trial);
    unawaited(checkpoint());
    _notify();
  }

  void _onSample(MotionSample sample) {
    if (!isTracking) {
      _preRoll.add(sample);
      if (_preRoll.length > 250) _preRoll.removeFirst();
    }
    final wasInterrupted = interruption != null;
    interruption = null;
    _lastArrival = DateTime.now();
    if (wasInterrupted) engine.recalibrate();
    final update =
        paused || backgrounded ? const ActivityUpdate() : engine.add(sample);
    if (mode != ActivityKind.steps) {
      if (canCount) {
        _setClock.start();
      } else {
        _setClock.stop();
      }
    }
    if (isTracking) {
      if (update.steps > 0) {
        current!.steps += update.steps;
        _dailySteps[_day] = todaySteps + update.steps;
      }
      repetitions += update.repetitions;
      if (update.jump != null) current!.jumps.add(update.jump!);
      storage.append(
        sample,
        mode,
        paused || backgrounded,
        engine.calibrated,
        update.steps,
        update.repetitions,
        update.jump?.heightCm,
      );
      if (update.steps > 0 || update.repetitions > 0 || update.jump != null) {
        unawaited(checkpoint());
      }
    }
    _signal.add(engine.movement);
    if (_signal.length > 160) _signal.removeFirst();
    // Algorithms consume every sample; widgets redraw at most 10 times/s.
    if (_lastUiUpdate == null ||
        _lastArrival!.difference(_lastUiUpdate!).inMilliseconds >= 100) {
      _lastUiUpdate = _lastArrival;
      _notify();
    }
  }

  void _interrupt(String message) {
    if (interruption == message) return;
    interruption = message;
    _setClock.stop();
    engine.recalibrate();
    _notify();
  }

  /// Checkpoints counts and current partial set without resuming it on restart.
  Future<void> checkpoint() async {
    if (storageError?.startsWith('Saved sessions could not be read') ?? false) {
      return;
    }
    final recentDays = _dailySteps.keys.toList()..sort();
    for (final day in recentDays.take(math.max(0, recentDays.length - 90))) {
      _dailySteps.remove(day);
    }
    final snapshot = <String, dynamic>{
      'schemaVersion': 1,
      'checkpointAt': DateTime.now().toIso8601String(),
      'dailySteps': _dailySteps,
      'sessions': sessions.take(200).map((s) {
        final json = s.toJson();
        if (identical(s, current) &&
            mode != ActivityKind.steps &&
            mode != ActivityKind.jumps) {
          json['sets'] = [
            ...s.sets.map((e) => e.toJson()),
            ExerciseSet(
              kind: mode,
              repetitions: repetitions,
              seconds: setSeconds,
            ).toJson(),
          ];
        }
        return json;
      }).toList(),
    };
    try {
      await storage.save(snapshot);
      await storage.flushTrace();
    } catch (e) {
      storageError = 'Session could not be saved. $e';
      _notify();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      backgrounded = true;
      _setClock.stop();
      engine.recalibrate();
      unawaited(checkpoint());
    } else if (state == AppLifecycleState.resumed && backgrounded) {
      backgrounded = false;
      engine.recalibrate();
      if (!paused && mode != ActivityKind.steps) _setClock.start();
      _notify();
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    if (_observeLifecycle) WidgetsBinding.instance.removeObserver(this);
    _timer.cancel();
    unawaited(_sampleSubscription.cancel());
    unawaited(_statusSubscription.cancel());
    unawaited(checkpoint().whenComplete(storage.closeTrace));
    source.dispose();
    super.dispose();
  }
}
