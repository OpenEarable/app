import 'overall_config.dart';

/// Parameters used by the regular biosignal-adaptive mode.
abstract final class BioAdaptiveModeConfig {
  // Session phases and intervention.
  static const int meditationSegmentCount = 10;
  static const bool includeCalibration = true;
  static const Duration calibrationDuration = Duration(seconds: 30);
  static const Duration baselineDuration = Duration(minutes: 5);

  /// Blends the profile's population-level estimate into the measured baseline
  /// while too little has been measured to stand on its own.
  ///
  /// Nothing is published before [demographicBlendStart]: there is not yet
  /// enough measurement to blend. From there the prior's share falls linearly
  /// from [demographicBlendStartWeight] to [demographicBlendEndWeight] at
  /// [demographicBlendEnd], i.e. 70/30 after one minute through 30/70 after
  /// five. It applies only when the profile carries age, gender and fitness
  /// level; otherwise the baseline stays purely measured. The conference demo
  /// keeps a sensor-only baseline.
  static const bool blendDemographicBaseline = true;
  static const Duration demographicBlendStart = Duration(minutes: 1);
  static const Duration demographicBlendEnd = Duration(minutes: 5);
  static const double demographicBlendStartWeight = 0.7;
  static const double demographicBlendEndWeight = 0.3;
  static const double? stressThresholdOverride = null;
  // Null keeps regular segments narration-driven instead of applying the
  // demo's 30-second target.
  static const Duration? meditationSegmentDurationOverride = null;
  static const int promptApproximateWordsPerSegment =
      OverallMeditationConfig.standardPromptApproximateWordsPerSegment;
  static const Duration? guaranteedMeditationDelay = null;
  static const bool useBestEffortEstimates = false;
  static const bool allowStressSimulation = true;
  // In the regular office-use mode, sustained movement prevents a new stress
  // classification so motion-related HR/RMSSD changes do not start a
  // meditation.
  static const bool suppressStressDetectionDuringActivity = true;

  // Shared recovery rule for regular and demo biosignal-adaptive sessions.
  // The current generated segment is allowed to finish once measured HR is
  // at or below baseline. RMSSD is deliberately not part of recovery.
  static const int recoveryHeartRateMarginBpm = 0;

  // Production HR/HRV windows. Null delegates to HrHrvProcessor's defaults:
  // 10 s HR buffer, 4 s metric eligibility, 60 s minimum RMSSD history, and
  // 5 min maximum RMSSD history.
  static const Duration? hrvMinimumWindowOverride = null;
  static const Duration? metricWindowDurationOverride = null;

  // Optical channel selection.
  //
  // Rank channels by modulation relative to their own DC level (perfusion
  // index) instead of by absolute AC amplitude, and hold the choice for the
  // measurement instead of re-deciding every sample.
  //
  // Measured on an OpenEarable v2 recording: the previous rule chose green
  // 96.8% of the time and detected 73% of beats; ranking by perfusion and
  // committing selects infrared and detects 101%. Set to false to restore the
  // previous behaviour for comparison.
  static const bool useNormalizedChannelSelection = true;
  static const bool commitOpticalChannelAtMeasurementStart = true;

  /// Minimum time a channel is held before another may take over.
  ///
  /// The 15% perfusion margin alone does not stop thrashing when two channels
  /// are close. One session switched green/infrared more than ten times during
  /// calibration, the last immediately after the commit and therefore at the
  /// very start of the baseline window; each switch steps the beat path's
  /// filters by tens of thousands of counts. That baseline resolved to 31 bpm
  /// from three usable intervals, which armed the demo's 3% threshold at
  /// 32 bpm and fired stress within seconds.
  static const Duration opticalChannelDwell = Duration(seconds: 5);

  // Beat timing signal path.
  //
  // The full conditioning chain low-passes the waveform enough that the
  // systolic peak becomes a broad hump whose maximum wanders: measured peak
  // positions jitter with a standard deviation of 62 ms against a clean
  // reference, and RMSSD squares successive differences, so that alone adds
  // about 87 ms of noise.
  //
  // Enabling this detects and times beats on a parallel, lightly filtered
  // signal (selected channel -> DC block -> band-pass, skipping the motion
  // suppressor, IMU canceller and normalizer). Measured on an OpenEarable v2
  // recording of a still, seated session: outlier-filtered RMSSD 117 ms to
  // 81 ms during meditation and 166 ms to 111 ms during monitoring, with
  // fewer implausible intervals.
  //
  // A later recording with deliberate head movement and talking settled the
  // open question: the lightly filtered path wins in every motion regime,
  // measured as mean clean consecutive beat pairs per comparison window —
  // still 8.0 vs 7.5, light movement 16.2 vs 12.0, sustained movement 11.5 vs
  // 8.5 — leading in 7 of 8 windows with lower RMSSD throughout. The skipped
  // stages were not protecting the waveform under motion; the step limiter and
  // the normalizer's clipping were themselves distorting it.
  //
  // Set to false to restore the previous behaviour. The detector-comparison
  // diagnostic reports both paths whichever way this is set.
  static const bool useLightlyFilteredBeatPath = true;

  /// Minimum separation between beats on the lightly filtered path, in seconds.
  ///
  /// The smoothing stages that path skips were doing two jobs, not one: they
  /// rounded off the systolic edge (which cost timing precision) *and* they
  /// blurred away the dicrotic notch. Restoring the edge restores the notch, so
  /// the 250 ms floor used for the conditioned signal lets the notch register
  /// as a beat.
  ///
  /// Measured across the four legacy modes on real data, worst-case heart rate
  /// against a true 52 bpm: 66 bpm at 212 ms, 54 bpm at 350 ms, 52 bpm at
  /// 450 ms. At 400 ms every mode agrees, which also neutralises the fact that
  /// mode selection happens once and then sticks. The cost is a ceiling of
  /// 150 bpm, far above anything a seated meditation produces.
  static const double beatPathMinimumBeatIntervalSeconds = 0.40;

  static const double defaultHeartRateWindowSeconds = 10;
  static const double defaultMetricEligibilityWindowSeconds = 4;
  static const double defaultHrvHistoryWindowSeconds = 300;
  static const Duration defaultHrvMinimumWindow = Duration(seconds: 60);
  static const Duration processorWarmupDuration = Duration(seconds: 10);
  static const Duration metricEmitInterval = Duration(seconds: 3);
  static const Duration metricStaleAfter = Duration(seconds: 12);

  /// How long the PPG stream may go silent before the session reports that it
  /// has lost the sensor. At 200 Hz a gap this long is never signal quality;
  /// it means the earbud, the link or the sensor has gone away.
  static const Duration sensorSignalTimeout = Duration(seconds: 5);
  static const Duration sensorSignalCheckInterval = Duration(seconds: 1);
  static const Duration phaseProgressUpdateInterval =
      Duration(milliseconds: 100);

  // Keep IMU traffic low while PPG and meditation audio run concurrently.
  // The activity classifier uses time-based windows, so 25 Hz is sufficient.
  static const int ppgTargetFrequencyHz = 200;
  static const double ppgFallbackFrequencyHz = 100;
  static const int accelerometerTargetFrequencyHz = 25;
  static const double accelerometerFallbackFrequencyHz = 25;
  static const int gyroscopeTargetFrequencyHz = 25;
  static const double gyroscopeFallbackFrequencyHz = 25;

  static const Duration chartVisibleWindow = Duration(minutes: 1);

  // Physical-activity classification and stress-suppression policy.
  static const double gravityMetersPerSecondSquared = 9.81;
  static const double restingAccelerationThreshold = 0.2;
  static const double restingGyroscopeThreshold = 300;
  static const double lightAccelerationThreshold = 0.4;
  static const double lightGyroscopeThreshold = 600;
  static const double moderateAccelerationThreshold = 0.8;
  static const double moderateGyroscopeThreshold = 1200;
  static const double vigorousAccelerationThreshold = 2;
  static const double vigorousGyroscopeThreshold = 3000;
  static const Duration activityClassificationInterval = Duration(seconds: 3);
  static const Duration activityHistoryWindow = Duration(minutes: 5);
  static const double lightActivitySuppressionRatio = 0.4;
  static const double moderateActivitySuppressionRatio = 0.2;
  static const double vigorousActivitySuppressionRatio = 0.05;
  static const double intenseActivitySuppressionRatio = 0.02;

  // Recording-derived stress playback used by the regular mode only.
  // Keep its chart/data cadence identical to metrics produced from live PPG.
  static const Duration recordedStressSampleInterval = metricEmitInterval;
  static const double recordedStressBaselineHeartRate = 71;
  static const double recordedStressBaselineRmssd = 80;
  static const double recordedStressBuildUpHeartRate = 80;
  static const double recordedStressBuildUpRmssd = 50;
  static const double recordedStressPeakHeartRate = 97;
  static const double recordedStressPeakRmssd = 12;
  static const double recordedStressBuildUpEndSeconds = 90;
  static const double recordedStressSpikeEndSeconds = 120;
  static const int recordedStressDetectionHeartRate = 90;
  static const double recordedStressDetectionRmssd = 40;
  static const double recordedStressOuAlpha = 0.9672;
  static const double recordedStressHrOuSigmaStep = 0.763;

  // Recovery begins when stress playback triggers a meditation.
  static const double relaxationTargetHeartRate = 62;
  static const double relaxationTargetRmssd = 90;
  static const double relaxationDurationSeconds = 360;
}
