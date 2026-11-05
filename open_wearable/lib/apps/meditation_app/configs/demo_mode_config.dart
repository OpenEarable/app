import 'overall_config.dart';

/// Parameters shared by the two conference-demo experiences.
abstract final class DemoModeConfig {
  // Demo biosignal-adaptive cycle.
  static const bool includeCalibration = true;
  static const Duration calibrationDuration = Duration(seconds: 30);
  static const Duration baselineDuration = Duration(seconds: 30);
  // The demo baseline stays sensor-only: it is 30 seconds long, so the
  // blending schedule would never leave its first step, and the attendee
  // account deliberately carries no profile to draw a prior from.
  static const bool blendDemographicBaseline = false;
  static const double stressThreshold = 0.03;
  static const Duration metricWindowDuration = Duration(seconds: 30);
  static const Duration hrvMinimumWindow = Duration(seconds: 30);
  static const Duration guaranteedMeditationDelay = Duration(minutes: 2);
  // Welcome and completion messages remain outside this generated count.
  //
  // This is a cap, not a fixed length. The demo ends adaptively on the same
  // HR-only rule as the regular mode: after each segment, measured heart rate
  // at or below the baseline completes the meditation. A participant who
  // settles quickly hears one segment; one who does not hears up to three.
  //
  // Note the interaction with guaranteedMeditationDelay below. A meditation
  // started by that deadline rather than by stress detection begins with heart
  // rate already at or near baseline, so it will often satisfy the recovery
  // rule after the first segment.
  static const int biosignalAdaptiveMeditationSegmentCount = 3;
  static const Duration meditationSegmentDuration = Duration(seconds: 30);
  static const bool useBestEffortEstimates = true;
  static const bool allowStressSimulation = false;
  // Activity is still classified and displayed in the demo, but it must never
  // prevent the condensed intervention from starting.
  static const bool suppressStressDetectionDuringActivity = false;

  // Personalized meditation-only demo.
  static const int meditationOnlySegmentCount = 3;
  static const Duration meditationOnlySegmentDuration = Duration(seconds: 30);

  // Privacy policy for both demo submodes.
  static const bool includePermanentProfileInPrompt = false;
  static const bool includePhysiologicalDataInPrompt = false;

  // Mainland China deployment checklist:
  // 1. Use Tencent rather than ElevenLabs for TTS.
  // 2. Select the Mainland China Tencent endpoint/region below.
  // 3. Supply TENCENT_SECRET_ID and TENCENT_SECRET_KEY belonging to a Tencent
  //    Cloud account where Mainland China TTS is activated. International
  //    credentials/service activation are not assumed to carry over.
  // 4. DeepSeek needs no endpoint change; keep its existing API key and global
  //    base URL. No profile or physiological values are added to its prompts.
  //
  // These values document equivalent deployment-tooling selections. They are
  // not automatically applied: the public app follows the provider and region
  // selected by the user on the API Keys page.
  static const Map<String, String> chinaEnvironmentOverrides = {
    OverallMeditationConfig.ttsProviderEnvironmentKey:
        OverallMeditationConfig.tencentProviderEnvironmentValue,
    OverallMeditationConfig.tencentRegionEnvironmentKey:
        OverallMeditationConfig.tencentChinaRegion,
  };
  static const String chinaTencentApiHost =
      OverallMeditationConfig.tencentChinaHost;
  static const bool chinaRequiresDeepseekEndpointOverride = false;
  static const String chinaDeepseekApiBaseUrl =
      OverallMeditationConfig.deepseekApiBaseUrl;
}
