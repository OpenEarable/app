import '../configs/bio_adaptive_mode_config.dart';
import '../configs/demo_mode_config.dart';
import 'meditation_prompt_policy.dart';

class BioAdaptiveSessionConfig {
  final bool includeCalibration;
  final Duration calibrationDuration;
  final Duration baselineDuration;
  final double? stressThresholdOverride;
  final Duration? meditationSegmentDuration;
  final Duration? hrvMinimumWindow;
  final Duration? metricWindowDuration;
  final Duration? guaranteedMeditationDelay;
  final int meditationSegmentCount;

  /// Allows physiologically plausible, beat-derived estimates that fall below
  /// the production stream's confidence threshold. Used only by the
  /// time-constrained conference demo; it never introduces synthetic values.
  final bool useBestEffortEstimates;
  final MeditationPromptPolicy promptPolicy;
  final bool allowStressSimulation;
  final bool suppressStressDetectionDuringActivity;

  /// Whether the baseline may blend the profile's demographic estimate with
  /// what has been measured so far. See BioAdaptiveModeConfig.
  final bool blendDemographicBaseline;

  const BioAdaptiveSessionConfig({
    required this.includeCalibration,
    required this.calibrationDuration,
    required this.baselineDuration,
    required this.stressThresholdOverride,
    required this.meditationSegmentDuration,
    required this.hrvMinimumWindow,
    required this.metricWindowDuration,
    required this.guaranteedMeditationDelay,
    required this.meditationSegmentCount,
    required this.useBestEffortEstimates,
    required this.promptPolicy,
    required this.allowStressSimulation,
    required this.suppressStressDetectionDuringActivity,
    required this.blendDemographicBaseline,
  });

  /// Full-length production behaviour. It uses the same sensor-only baseline
  /// path as the demo, but retains the longer production timing and stricter
  /// signal-quality requirements.
  static const standard = BioAdaptiveSessionConfig(
    includeCalibration: BioAdaptiveModeConfig.includeCalibration,
    calibrationDuration: BioAdaptiveModeConfig.calibrationDuration,
    baselineDuration: BioAdaptiveModeConfig.baselineDuration,
    stressThresholdOverride: BioAdaptiveModeConfig.stressThresholdOverride,
    meditationSegmentDuration:
        BioAdaptiveModeConfig.meditationSegmentDurationOverride,
    hrvMinimumWindow: BioAdaptiveModeConfig.hrvMinimumWindowOverride,
    metricWindowDuration: BioAdaptiveModeConfig.metricWindowDurationOverride,
    guaranteedMeditationDelay: BioAdaptiveModeConfig.guaranteedMeditationDelay,
    meditationSegmentCount: BioAdaptiveModeConfig.meditationSegmentCount,
    useBestEffortEstimates: BioAdaptiveModeConfig.useBestEffortEstimates,
    promptPolicy: MeditationPromptPolicy.standard,
    allowStressSimulation: BioAdaptiveModeConfig.allowStressSimulation,
    suppressStressDetectionDuringActivity:
        BioAdaptiveModeConfig.suppressStressDetectionDuringActivity,
    blendDemographicBaseline: BioAdaptiveModeConfig.blendDemographicBaseline,
  );

  /// Time-condensed conference cycle described in the demo paper.
  static const conferenceDemo = BioAdaptiveSessionConfig(
    includeCalibration: DemoModeConfig.includeCalibration,
    calibrationDuration: DemoModeConfig.calibrationDuration,
    baselineDuration: DemoModeConfig.baselineDuration,
    stressThresholdOverride: DemoModeConfig.stressThreshold,
    meditationSegmentDuration: DemoModeConfig.meditationSegmentDuration,
    hrvMinimumWindow: DemoModeConfig.hrvMinimumWindow,
    metricWindowDuration: DemoModeConfig.metricWindowDuration,
    guaranteedMeditationDelay: DemoModeConfig.guaranteedMeditationDelay,
    meditationSegmentCount:
        DemoModeConfig.biosignalAdaptiveMeditationSegmentCount,
    useBestEffortEstimates: DemoModeConfig.useBestEffortEstimates,
    promptPolicy: MeditationPromptPolicy.conferenceDemo,
    allowStressSimulation: DemoModeConfig.allowStressSimulation,
    suppressStressDetectionDuringActivity:
        DemoModeConfig.suppressStressDetectionDuringActivity,
    blendDemographicBaseline: DemoModeConfig.blendDemographicBaseline,
  );
}
