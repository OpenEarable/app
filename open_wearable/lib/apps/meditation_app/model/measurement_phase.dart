import 'dart:async';

import 'package:flutter/foundation.dart';

import '../configs/bio_adaptive_mode_config.dart';
import 'biometric_source.dart';
import 'stress_detector.dart';
import 'user_account.dart';
import 'hr_hrv_processor.dart' show HeartRateSample;

class PhaseContext {
  final BiometricSource source;
  final StressDetector detector;
  final bool suppressStressDetectionDuringActivity;

  const PhaseContext({
    required this.source,
    required this.detector,
    this.suppressStressDetectionDuringActivity = true,
  });
}

sealed class MonitoringPhase {
  Duration? get duration;

  /// Timed phases may hold at 100% until the required sensor data is valid.
  bool get canAdvance => true;

  /// Called by the controller only after this phase's timer has expired.
  void atDeadline(PhaseContext ctx) {}

  StreamSubscription<HeartRateSample>? activate(
    PhaseContext ctx,
  );

  /// Called when the session is paused and resumed.
  ///
  /// [activate] runs again on resume, so a phase that keeps a clock of its own
  /// cannot tell the two apart from there; these hooks let it stay aligned
  /// with the time it was actually measuring.
  void onPaused() {}

  void onResumed() {}

  void complete(PhaseContext ctx) {}
}

class CalibrationPhase extends MonitoringPhase {
  @override
  final Duration duration;

  CalibrationPhase({
    this.duration = BioAdaptiveModeConfig.calibrationDuration,
  });

  @override
  StreamSubscription<HeartRateSample>? activate(
    PhaseContext ctx,
  ) {
    ctx.source.beginCalibration();
    return null;
  }
}

class BaselinePhase extends MonitoringPhase {
  final UserAccount userAccount;
  final bool useBestEffortAtDeadline;

  /// Whether the profile's demographic estimate may inform the baseline while
  /// too little has been measured for the measurement to stand alone.
  final bool blendDemographicPrior;

  @override
  final Duration duration;

  int _heartRateCount = 0;
  double _heartRateTotal = 0;
  int _rmssdCount = 0;
  double _rmssdTotal = 0;
  BiometricSource? _source;
  HeartRateSample? _deadlineEstimate;
  final Stopwatch _elapsed = Stopwatch();

  BaselinePhase({
    required this.userAccount,
    Duration? duration,
    this.useBestEffortAtDeadline = false,
    this.blendDemographicPrior = false,
  }) : duration = duration ?? BioAdaptiveModeConfig.baselineDuration;

  /// The demographic estimate's share of the published baseline after
  /// [elapsed] of measurement, or null while it is too early to publish one.
  ///
  /// Falls linearly from 70% at one minute to 30% at five, and holds there.
  static double? demographicPriorWeight(Duration elapsed) {
    const start = BioAdaptiveModeConfig.demographicBlendStart;
    const end = BioAdaptiveModeConfig.demographicBlendEnd;
    const startWeight = BioAdaptiveModeConfig.demographicBlendStartWeight;
    const endWeight = BioAdaptiveModeConfig.demographicBlendEndWeight;

    if (elapsed < start) return null;
    if (elapsed >= end) return endWeight;
    final progress =
        (elapsed - start).inMilliseconds / (end - start).inMilliseconds;
    return startWeight + ((endWeight - startWeight) * progress);
  }

  /// One value on the schedule: the prior's share plus the measurement's.
  @visibleForTesting
  static double blendValue(
    double prior,
    double measured,
    double priorWeight,
  ) =>
      (prior * priorWeight) + (measured * (1 - priorWeight));

  /// Writes the baseline the rest of the session compares against.
  ///
  /// Without blending this is the plain running mean, exactly as before. With
  /// it, the measured mean is weighted against the profile's estimate on the
  /// schedule above, and nothing is published during the first minute: there
  /// is too little measurement to blend, and publishing the prior alone would
  /// present a population estimate as if it had been measured.
  void _publishBaseline() {
    final measuredHeartRate =
        _heartRateCount > 0 ? _heartRateTotal / _heartRateCount : null;
    final measuredRmssd = _rmssdCount > 0 ? _rmssdTotal / _rmssdCount : null;

    final prior =
        blendDemographicPrior ? userAccount.demographicBaseline : null;
    if (prior == null) {
      if (measuredHeartRate != null) {
        userAccount.baselineHeartRate = measuredHeartRate.round();
      }
      if (measuredRmssd != null) {
        userAccount.baselineRMSSD = measuredRmssd;
      }
      return;
    }

    final weight = demographicPriorWeight(_elapsed.elapsed);
    if (weight == null) return;

    if (measuredHeartRate != null) {
      userAccount.baselineHeartRate =
          blendValue(prior.$1.toDouble(), measuredHeartRate, weight).round();
    }
    if (measuredRmssd != null) {
      userAccount.baselineRMSSD = blendValue(prior.$2, measuredRmssd, weight);
    }
  }

  @override
  bool get canAdvance => useBestEffortAtDeadline
      ? _deadlineEstimate?.rmssd != null
      : _heartRateCount > 0 && _rmssdCount > 0;

  @override
  void atDeadline(PhaseContext ctx) {
    if (!useBestEffortAtDeadline) return;
    // Keep asking until an estimate arrives that actually carries an RMSSD.
    // The source may return a heart-rate-only sample as its last resort, and
    // caching that with `??=` would pin [canAdvance] to false for good — the
    // demo would sit at the end of its baseline forever. The processor itself
    // applies the same rule: it only caches a resolved estimate with an RMSSD.
    if (_deadlineEstimate?.rmssd != null) return;
    _deadlineEstimate = _source?.finalizeBaselineEstimate();
  }

  bool get hasValidHeartRate => _heartRateCount > 0;
  bool get hasValidRmssd => _rmssdCount > 0;

  @override
  StreamSubscription<HeartRateSample> activate(
    PhaseContext ctx,
  ) {
    _source = ctx.source;
    // Started, not restarted: the controller calls activate() again on every
    // resume, and resetting here sent the blending schedule back to its first
    // step each time the session was paused.
    _elapsed.start();
    ctx.source.beginMeasurement();
    return ctx.source.biometrics.listen((data) {
      _heartRateTotal += data.heartRate;
      _heartRateCount++;

      if (data.rmssd != null) {
        _rmssdTotal += data.rmssd!;
        _rmssdCount++;
      }

      _publishBaseline();
    });
  }

  @override
  void onPaused() => _elapsed.stop();

  @override
  void onResumed() => _elapsed.start();

  /// The measuring time behind the blending schedule, excluding pauses.
  @visibleForTesting
  Duration get elapsedMeasuring => _elapsed.elapsed;

  @override
  void complete(PhaseContext ctx) {
    // Pin the schedule at the value the phase actually ended on, so the stored
    // baseline is not a few seconds stale in its weighting.
    _publishBaseline();
    _elapsed.stop();

    if (!useBestEffortAtDeadline) return;
    final estimate = _deadlineEstimate;
    final rmssd = estimate?.rmssd;
    if (estimate == null || rmssd == null) return;
    // The deadline estimate is based on the complete retained demo window and
    // therefore supersedes partial rolling-window values emitted earlier.
    userAccount.baselineHeartRate = estimate.heartRate;
    userAccount.baselineRMSSD = rmssd;
  }
}

class StressMonitoringPhase extends MonitoringPhase {
  @override
  Duration? get duration => null;

  @override
  StreamSubscription<HeartRateSample> activate(
    PhaseContext ctx,
  ) {
    ctx.source.beginMeasurement();
    return ctx.source.biometrics.listen((sample) {
      ctx.detector.onSample(
        sample,
        suppress: ctx.suppressStressDetectionDuringActivity &&
            ctx.source.suppressStressDetection,
      );
    });
  }
}

class MonitoringPhaseController {
  final PhaseContext _ctx;
  final List<MonitoringPhase> _phases;

  late final ValueNotifier<MonitoringPhase> phase;
  final ValueNotifier<double?> progress = ValueNotifier(null);

  /// True once a timed phase has run past its duration and still cannot
  /// advance, i.e. it is waiting on data that has not arrived.
  ///
  /// The baseline needs at least one usable RMSSD before monitoring can start.
  /// Without this the progress bar simply sat full with nothing to say why,
  /// which in a demo is indistinguishable from the app having hung.
  final ValueNotifier<bool> awaitingPhaseData = ValueNotifier(false);

  final Stopwatch _stopwatch = Stopwatch();
  Timer? _ticker;
  StreamSubscription<HeartRateSample>? _phaseSub;
  int _index = 0;

  MonitoringPhaseController({
    required PhaseContext ctx,
    required List<MonitoringPhase> phases,
  })  : _ctx = ctx,
        _phases = phases {
    phase = ValueNotifier(_phases.first);
  }

  MonitoringPhase get current => _phases[_index];

  void start() {
    _index = 0;
    awaitingPhaseData.value = false;
    progress.value = 0;
    phase.value = current;
    _stopwatch
      ..reset()
      ..start();
    _activate();
    _startTicker();
  }

  void pause() {
    _stopwatch.stop();
    _ticker?.cancel();
    _phaseSub?.cancel();
    current.onPaused();
  }

  void resume() {
    _stopwatch.start();
    current.onResumed();
    _activate();
    if (current.duration != null) _startTicker();
  }

  void dispose() {
    _ticker?.cancel();
    _phaseSub?.cancel();
    phase.dispose();
    progress.dispose();
    awaitingPhaseData.dispose();
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(
      BioAdaptiveModeConfig.phaseProgressUpdateInterval,
      (_) => _tick(),
    );
  }

  void _tick() {
    final duration = current.duration;
    if (duration == null) {
      progress.value = null;
      return; // indefinite phase — nothing to time or advance
    }
    progress.value =
        (_stopwatch.elapsed.inMilliseconds / duration.inMilliseconds)
            .clamp(0.0, 1.0);
    if (_stopwatch.elapsed >= duration) {
      current.atDeadline(_ctx);
      if (current.canAdvance) {
        _advance();
      } else {
        awaitingPhaseData.value = true;
      }
    }
  }

  void _advance() {
    if (_index >= _phases.length - 1) return; // last phase; stay put
    current.complete(_ctx);
    _phaseSub?.cancel();
    awaitingPhaseData.value = false;
    _index++;
    _stopwatch
      ..reset()
      ..start();
    _activate();
    progress.value = current.duration == null ? null : 0;
    phase.value = current;

    // Once we reach an indefinite phase, the ticker has nothing left to do.
    if (current.duration == null) {
      _ticker?.cancel();
    }
  }

  void _activate() {
    _phaseSub?.cancel();
    _phaseSub = current.activate(_ctx);
  }
}
