import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart';
import 'package:open_wearable/view_models/sensor_configuration_provider.dart';

import '../configs/bio_adaptive_mode_config.dart';
import 'user_account.dart';
import 'bio_adaptive_session_config.dart';
import 'meditation_analytics.dart';
import 'biometric_source.dart';
import 'stress_detector.dart';
import 'measurement_phase.dart';
import 'activity_tracker.dart' show ActivityLevel;
import 'meditation.dart' show BiometricMeditation, Meditation;
import 'hr_hrv_processor.dart' show HeartRateSample;
import 'monitoring_meditation_deadline.dart';

class Measurement {
  final UserAccount userAccount;
  final BioAdaptiveSessionConfig sessionConfig;
  final MeditationAnalyticsStore? analyticsStore;

  final BiometricSource _source;
  late final StressDetector _detector;
  late final MonitoringPhaseController _phaseController;
  late final MonitoringMeditationDeadline _meditationDeadline;
  StreamSubscription<HeartRateSample>? _latestBiometricsSubscription;
  HeartRateSample? _latestBiometrics;
  DateTime? _lastBiometricsAt;
  Timer? _freshnessTimer;
  final ValueNotifier<bool> metricsFresh = ValueNotifier(false);

  final ValueNotifier<BiometricMeditation?> meditation = ValueNotifier(null);

  Measurement._({
    required this.userAccount,
    required BiometricSource source,
    required List<MonitoringPhase> phases,
    required StressThresholdProvider stressThresholdProvider,
    required BaselineHeartRateProvider baselineHeartRateProvider,
    required this.sessionConfig,
    this.analyticsStore,
  }) : _source = source {
    _detector = StressDetector(
      thresholds: stressThresholdProvider,
      baselineHeartRate: baselineHeartRateProvider,
    );
    _detector.stressLevel.addListener(_onStressLevelChanged);
    _phaseController = MonitoringPhaseController(
      ctx: PhaseContext(
        source: _source,
        detector: _detector,
        suppressStressDetectionDuringActivity:
            sessionConfig.suppressStressDetectionDuringActivity,
      ),
      phases: phases,
    );
    _meditationDeadline = MonitoringMeditationDeadline(
      delay: sessionConfig.guaranteedMeditationDelay,
      onElapsed: _onGuaranteedMeditationDeadline,
    );
    _phaseController.phase.addListener(_onMonitoringPhaseChanged);
  }

  factory Measurement.live({
    required Sensor ppgSensor,
    required Sensor accelerometerSensor,
    required Sensor gyroscopeSensor,
    required SensorConfigurationProvider sensorConfigProvider,
    required UserAccount userAccount,
    BioAdaptiveSessionConfig sessionConfig = BioAdaptiveSessionConfig.standard,
    MeditationAnalyticsStore? analyticsStore,
  }) {
    return Measurement._(
      userAccount: userAccount,
      source: SensorBiometricSource(
        ppgSensor: ppgSensor,
        accelerometerSensor: accelerometerSensor,
        gyroscopeSensor: gyroscopeSensor,
        sensorConfigProvider: sensorConfigProvider,
        hrvMinimumWindow: sessionConfig.hrvMinimumWindow,
        metricWindowDuration: sessionConfig.metricWindowDuration,
        publishBestEffortEstimates: sessionConfig.useBestEffortEstimates,
        startInCalibration: sessionConfig.includeCalibration,
      ),
      phases: [
        if (sessionConfig.includeCalibration)
          CalibrationPhase(duration: sessionConfig.calibrationDuration),
        BaselinePhase(
          userAccount: userAccount,
          duration: sessionConfig.baselineDuration,
          useBestEffortAtDeadline: sessionConfig.useBestEffortEstimates,
          blendDemographicPrior: sessionConfig.blendDemographicBaseline,
        ),
        StressMonitoringPhase(),
      ],
      stressThresholdProvider: () => userAccount.stressThresholds(
        stressThreshold: sessionConfig.stressThresholdOverride,
      ),
      baselineHeartRateProvider: () => userAccount.baselineBiometrics.$1,
      sessionConfig: sessionConfig,
      analyticsStore: analyticsStore,
    );
  }

  factory Measurement.recordedStress({
    required UserAccount userAccount,
    required ActivityLevel restingActivityLevel,
    BioAdaptiveSessionConfig sessionConfig = BioAdaptiveSessionConfig.standard,
  }) {
    return Measurement._(
      userAccount: userAccount,
      source: RecordedStressBiometricSource(
        restingActivityLevel: restingActivityLevel,
      ),
      phases: [StressMonitoringPhase()],
      stressThresholdProvider: () => (
        BioAdaptiveModeConfig.recordedStressDetectionHeartRate,
        BioAdaptiveModeConfig.recordedStressDetectionRmssd,
      ),
      baselineHeartRateProvider: () =>
          RecordedStressBiometricSource.baselineHeartRate.round(),
      sessionConfig: sessionConfig,
    );
  }

  // Publish the heart rate and RMSSD
  /// Whether the current phase has overrun its duration while still waiting
  /// for the data it needs to advance. See MonitoringPhaseController.
  ValueListenable<bool> get awaitingPhaseData =>
      _phaseController.awaitingPhaseData;

  /// Whether sensor samples are still arriving. False means the link is gone,
  /// not that the signal is poor - a session cannot recover on its own.
  ValueListenable<bool> get sensorSignalAlive => _source.signalAlive;

  // Mapped once rather than per access: a getter handed StreamBuilder a new
  // Stream object on every rebuild, so it resubscribed, fell back to
  // ConnectionState.waiting, and the tile flashed its baseline label. The
  // underlying controllers are broadcast, so several listeners are fine.
  late final Stream<int> heartRate = _source.biometrics.map((b) => b.heartRate);
  late final Stream<double?> rmssd = _source.biometrics.map((b) => b.rmssd);

  /// RMSSD as the tile displays it: samples carrying no value are skipped, and
  /// the number is formatted here rather than in `build`.
  ///
  /// The view used to derive this inline, which produced a new stream object
  /// on every rebuild. StreamBuilder compares stream instances, so it
  /// resubscribed each time, fell back to ConnectionState.waiting and showed
  /// "Baseline: …" again — and because this stream skips samples without an
  /// RMSSD, the wait for the next one can be long.
  late final Stream<String> rmssdDisplay = rmssd
      .where((value) => value != null)
      .map((value) => value!.toStringAsFixed(1));

  // The latest values stay local and are only included in a cloud prompt when
  // the session's explicit prompt policy permits it.
  HeartRateSample? get latestBiometrics =>
      _hasFreshBiometrics ? _latestBiometrics : null;
  int? get baselineHeartRate => userAccount.baselineHeartRate;
  double? get baselineRmssd => userAccount.baselineRMSSD;

  /// Whether the latest measured HR has returned to the baseline used by the
  /// detector. RMSSD is intentionally irrelevant to meditation completion.
  bool get hasHeartRateRecoveredToBaseline {
    final latest = _latestBiometrics;
    return latest != null &&
        _hasFreshBiometrics &&
        _detector.isHeartRateRecovered(latest.heartRate);
  }

  bool get _hasFreshBiometrics {
    final last = _lastBiometricsAt;
    return metricsFresh.value &&
        last != null &&
        DateTime.now().difference(last) <=
            BioAdaptiveModeConfig.metricStaleAfter;
  }

  void recordDiagnosticEvent(
    String event, [
    Map<String, Object?> values = const {},
  ]) {
    if (_source case final SensorBiometricSource sensor) {
      sensor.recordDiagnosticEvent(event, values);
    }
  }

  // Publish the stress level
  ValueListenable<StressLevel> get stressLevel => _detector.stressLevel;

  // Publish the monitoring phase and progress
  ValueListenable<MonitoringPhase> get monitoringPhase =>
      _phaseController.phase;
  ValueListenable<double?> get progress => _phaseController.progress;

  // Publish the activity level
  ValueListenable<ActivityLevel> get activityLevel => _source.activityLevel;

  void start() {
    _meditationDeadline.reset();
    _source.start();
    _latestBiometrics = null;
    _lastBiometricsAt = null;
    metricsFresh.value = false;
    _latestBiometricsSubscription = _source.biometrics.listen((sample) {
      _latestBiometrics = sample;
      _lastBiometricsAt = DateTime.now();
      metricsFresh.value = true;
    });
    _startFreshnessTimer();
    _detector.reset();
    _phaseController.start();
    _onMonitoringPhaseChanged();
  }

  void pause() {
    _meditationDeadline.pause();
    _freshnessTimer?.cancel();
    metricsFresh.value = false;
    _source.pause();
    _phaseController.pause();
    // A running meditation is suspended along with the rest of the session,
    // not ended. Stopping it here meant resume() could not bring it back and
    // analytics recorded an abandoned session every time the user paused.
    meditation.value?.pause();
  }

  void resume() {
    _source.resume();
    _startFreshnessTimer();
    _phaseController.resume();
    _meditationDeadline.resume();
    meditation.value?.resume();
  }

  void dispose() {
    _freshnessTimer?.cancel();
    final currentMeditation = meditation.value;
    if (currentMeditation != null) {
      unawaited(
        currentMeditation.stop().whenComplete(currentMeditation.dispose),
      );
    }
    _latestBiometricsSubscription?.cancel();
    _source.dispose();
    _detector.stressLevel.removeListener(_onStressLevelChanged);
    _phaseController.phase.removeListener(_onMonitoringPhaseChanged);
    _meditationDeadline.dispose();
    _detector.dispose();
    _phaseController.dispose();
    meditation.dispose();
    metricsFresh.dispose();
  }

  void _startFreshnessTimer() {
    _freshnessTimer?.cancel();
    _freshnessTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      metricsFresh.value = _hasFreshBiometrics;
    });
  }

  void _onStressLevelChanged() {
    if (_detector.currentStressLevel == StressLevel.stressed &&
        meditation.value == null) {
      _startMeditation();
    }
  }

  void _onMonitoringPhaseChanged() {
    if (_phaseController.current is StressMonitoringPhase) {
      // Baseline measurements remain in the account as the comparison point,
      // but must not masquerade as a current monitoring/recovery sample.
      _latestBiometrics = null;
      _lastBiometricsAt = null;
      metricsFresh.value = false;
      recordDiagnosticEvent('monitoring_started');
      _meditationDeadline.enterMonitoring();
    }
  }

  void _onGuaranteedMeditationDeadline() {
    if (_phaseController.current is StressMonitoringPhase &&
        meditation.value == null) {
      _startMeditation();
    }
  }

  void _startMeditation() {
    if (meditation.value != null) return;
    recordDiagnosticEvent('meditation_triggered');
    _meditationDeadline.satisfy();
    if (_source case final RecordedStressBiometricSource recordedStress) {
      recordedStress.startRelaxationScenario();
    }
    final session = BiometricMeditation(
      userAccount: userAccount,
      measurement: this,
      maxSegments: sessionConfig.meditationSegmentCount,
      meditationSegmentDuration: sessionConfig.meditationSegmentDuration,
      promptPolicy: sessionConfig.promptPolicy,
      analyticsStore: analyticsStore,
      analyticsMode:
          analyticsStore == null ? null : MeditationAnalyticsMode.bioAdaptive,
      diagnosticEventSink: recordDiagnosticEvent,
    );
    meditation.value = session;

    unawaited(session.start());
  }

  /// Removes a completed or manually stopped meditation from the UI and
  /// releases its audio resources. Natural completion remains visible until
  /// the attendee has acknowledged the success card.
  void dismissMeditation(Meditation session) {
    if (meditation.value != session) return;
    meditation.value = null;
    unawaited(session.stop().whenComplete(session.dispose));
  }
}
