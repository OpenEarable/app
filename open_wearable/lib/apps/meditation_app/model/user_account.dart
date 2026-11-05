import 'dart:math';

import '../configs/overall_config.dart';
import '../widgets/emojis.dart';

enum Gender {
  male(
    label: "Male",
    emoji: AppEmojis.male,
  ),
  female(
    label: "Female",
    emoji: AppEmojis.female,
  ),
  nonBinary(
    label: "Non-Binary",
  ),
  unspecified(
    label: "Unspecified",
  );

  final String label;
  final String? emoji;

  const Gender({
    required this.label,
    this.emoji,
  });
}

enum SpeakingSpeed {
  verySlow(
    label: "Very Slow",
    isRecommended: false,
    emoji: AppEmojis.snail,
    speed: OverallMeditationConfig.verySlowSpeechRate,
  ),
  slow(
    label: "Slow",
    isRecommended: true,
    emoji: AppEmojis.turtle,
    speed: OverallMeditationConfig.slowSpeechRate,
  ),
  medium(
    label: "Medium",
    isRecommended: false,
    emoji: AppEmojis.walkingPerson,
    speed: OverallMeditationConfig.mediumSpeechRate,
  ),
  fast(
    label: "Fast",
    isRecommended: false,
    emoji: AppEmojis.runningPerson,
    speed: OverallMeditationConfig.fastSpeechRate,
  );

  final String label;
  final String emoji;
  final bool isRecommended;
  // flutter_tts speech rate, on its normalized 0.0-1.0 scale.
  final double speed;
  const SpeakingSpeed({
    required this.label,
    required this.emoji,
    required this.speed,
    required this.isRecommended,
  });
}

enum FitnessLevel { sedentary, moderate, active, athlete }

enum TtsProviderOption {
  elevenLabs(label: 'ElevenLabs'),
  tencent(label: 'Tencent Cloud');

  final String label;

  const TtsProviderOption({required this.label});

  static TtsProviderOption fromConfig(String? value) {
    // Stray quotes are tolerated. dotenv strips a matched pair, but an
    // unmatched one would otherwise fall through to the ElevenLabs default
    // silently, and a demo that quietly starts on a cloud voice it cannot
    // reach is a bad way to find that out. No provider token contains a
    // quote, so removing them outright is safe.
    final normalized =
        value?.replaceAll('"', '').replaceAll("'", '').trim().toLowerCase();
    return switch (normalized?.toLowerCase()) {
      OverallMeditationConfig.tencentProviderEnvironmentValue ||
      'tencentcloud' ||
      'tencent_cloud' =>
        TtsProviderOption.tencent,
      OverallMeditationConfig.elevenLabsProviderEnvironmentValue =>
        TtsProviderOption.elevenLabs,
      _ => TtsProviderOption.elevenLabs,
    };
  }
}

enum TencentTtsRegion {
  internationalSingapore(
    label: 'International (Singapore)',
    region: OverallMeditationConfig.tencentInternationalRegion,
    host: OverallMeditationConfig.tencentInternationalHost,
  ),
  chinaGuangzhou(
    label: 'Mainland China (Guangzhou)',
    region: OverallMeditationConfig.tencentChinaRegion,
    host: OverallMeditationConfig.tencentChinaHost,
  );

  final String label;
  final String region;
  final String host;

  const TencentTtsRegion({
    required this.label,
    required this.region,
    required this.host,
  });

  static TencentTtsRegion fromConfig(String? value) {
    final normalized = value?.trim().toLowerCase();
    return switch (normalized) {
      OverallMeditationConfig.tencentChinaRegion ||
      'china' ||
      'mainland-china' =>
        TencentTtsRegion.chinaGuangzhou,
      // Frankfurt is retained as a compatibility alias for configurations
      // created before Tencent's product-specific TTS regions were verified.
      // International TextToVoice uses the global endpoint and Singapore
      // processing; eu-frankfurt is not supported by that API.
      OverallMeditationConfig.tencentInternationalRegion ||
      'international' ||
      'global' ||
      'eu-frankfurt' =>
        TencentTtsRegion.internationalSingapore,
      _ => TencentTtsRegion.internationalSingapore,
    };
  }
}

enum MeditationEnvironment {
  ocean(
    label: "Ocean beach",
    emoji: AppEmojis.wave,
    assetPath: "Ocean_Beach.mp3",
  ),
  mountain(
    label: "Mountain",
    emoji: AppEmojis.mountain,
    assetPath: "Mountain.mp3",
  ),
  forest(
    label: "Forest",
    emoji: AppEmojis.forest,
    assetPath: "Forest.mp3",
  ),
  garden(
    label: "Garden",
    emoji: AppEmojis.cherryBlossom,
    assetPath: "Garden.mp3",
  );

  final String label;
  final String emoji;
  final String assetPath;
  const MeditationEnvironment({
    required this.label,
    required this.emoji,
    required this.assetPath,
  });
}

enum MeditationType {
  mindfulness(
    label: "Mindfulness",
    emoji: AppEmojis.meditatingPerson,
  ),
  breathing(
    label: "Breathing",
    emoji: AppEmojis.breathing,
  ),
  bodyScan(
    label: "Body Scan",
    emoji: AppEmojis.bodyScan,
  ),
  visualizationJourney(
    label: "Visualization Journey",
    emoji: AppEmojis.visualizationJourney,
  );

  final String label;
  final String emoji;
  const MeditationType({required this.label, required this.emoji});
}

class UserAccount {
  // Basic user information
  String? firstName;
  Gender? gender;
  int? age;
  FitnessLevel? fitnessLevel;

  // Meditation preferences
  Gender? voiceGender;
  SpeakingSpeed? speakingSpeed;
  MeditationType? meditationType;
  MeditationEnvironment? meditationEnvironment;
  String? additionalPreferences;
  double? stressThreshold;

  /// Whether this user has explicitly allowed meditation data to be sent to
  /// the configured cloud services. `null` means that no choice has been made
  /// yet; both `null` and `false` keep generation and narration on the device.
  bool? cloudProcessingConsent;

  // API keys and tokens
  String? deepseekApiKey;
  bool hasValidDeepseekKey = false;
  String? elevenLabsApiKey;
  bool hasValidElevenLabsKey = false;
  // Populated by the ElevenLabs connection manager once the key is verified.
  String? elevenLabsVoiceId;
  List<({String voice, String id})>? availableElevenLabsVoices;
  TtsProviderOption ttsProvider;
  String? tencentSecretId;
  String? tencentSecretKey;
  bool hasValidTencentKey = false;
  TencentTtsRegion tencentTtsRegion;

  // Bio-adaptive meditation settings
  int? baselineHeartRate;
  double? baselineRMSSD;

  UserAccount({
    this.firstName,
    this.gender,
    this.age,
    this.fitnessLevel,
    this.voiceGender,
    this.speakingSpeed,
    this.meditationType,
    this.meditationEnvironment,
    this.additionalPreferences,
    this.stressThreshold,
    this.cloudProcessingConsent,
    this.deepseekApiKey,
    this.elevenLabsApiKey,
    this.ttsProvider = TtsProviderOption.elevenLabs,
    this.tencentSecretId,
    this.tencentSecretKey,
    this.tencentTtsRegion = TencentTtsRegion.internationalSingapore,
    this.baselineHeartRate,
    this.baselineRMSSD,
  });

  bool get hasValidSelectedTtsProvider => switch (ttsProvider) {
        TtsProviderOption.elevenLabs => hasValidElevenLabsKey,
        TtsProviderOption.tencent => hasValidTencentKey,
      };

  bool get allowsCloudProcessing => cloudProcessingConsent == true;

  factory UserAccount.fromEnvironment(
    Map<String, String> environment, {
    String? firstName,
    Gender? gender,
    int? age,
    FitnessLevel? fitnessLevel,
  }) {
    String? configured(String key) {
      final value = environment[key]?.trim();
      return value == null || value.isEmpty ? null : value;
    }

    final deepseekApiKey = configured(
      OverallMeditationConfig.deepseekApiKeyEnvironmentKey,
    );
    final elevenLabsApiKey = configured(
      OverallMeditationConfig.elevenLabsApiKeyEnvironmentKey,
    );
    final tencentSecretId = configured(
      OverallMeditationConfig.tencentSecretIdEnvironmentKey,
    );
    final tencentSecretKey = configured(
          OverallMeditationConfig.tencentSecretKeyEnvironmentKey,
        ) ??
        configured(
          OverallMeditationConfig.tencentLegacySecretKeyEnvironmentKey,
        );

    final account = UserAccount(
      firstName: firstName,
      gender: gender,
      age: age,
      fitnessLevel: fitnessLevel,
      deepseekApiKey: deepseekApiKey,
      elevenLabsApiKey: elevenLabsApiKey,
      ttsProvider: TtsProviderOption.fromConfig(
        environment[OverallMeditationConfig.ttsProviderEnvironmentKey],
      ),
      tencentSecretId: tencentSecretId,
      tencentSecretKey: tencentSecretKey,
      tencentTtsRegion: TencentTtsRegion.fromConfig(
        environment[OverallMeditationConfig.tencentRegionEnvironmentKey],
      ),
    );

    // Retained for configuration-import tooling and parser tests. The public
    // runtime starts with UserAccount() and accepts credentials only through
    // the API Keys page.
    account.hasValidDeepseekKey = deepseekApiKey != null;
    account.hasValidElevenLabsKey = elevenLabsApiKey != null;
    account.hasValidTencentKey =
        tencentSecretId != null && tencentSecretKey != null;
    return account;
  }

  /// Creates an attendee-scoped account containing only cloud-service
  /// configuration. No permanent profile, meditation preference, stress
  /// threshold, or stored baseline is read into the demo session.
  factory UserAccount.forConferenceDemo({
    required UserAccount serviceConfiguration,
  }) {
    final account = UserAccount(
      // Voice choice is service configuration managed on the API Keys page,
      // not attendee profile data. It is used for TTS but never added to the
      // privacy-restricted demo prompt.
      voiceGender: serviceConfiguration.voiceGender,
      cloudProcessingConsent: serviceConfiguration.cloudProcessingConsent,
      deepseekApiKey: serviceConfiguration.deepseekApiKey,
      elevenLabsApiKey: serviceConfiguration.elevenLabsApiKey,
      ttsProvider: serviceConfiguration.ttsProvider,
      tencentSecretId: serviceConfiguration.tencentSecretId,
      tencentSecretKey: serviceConfiguration.tencentSecretKey,
      tencentTtsRegion: serviceConfiguration.tencentTtsRegion,
    );

    account.hasValidDeepseekKey = serviceConfiguration.hasValidDeepseekKey;
    account.elevenLabsVoiceId = serviceConfiguration.elevenLabsVoiceId;
    account.hasValidElevenLabsKey = serviceConfiguration.hasValidElevenLabsKey;
    account.hasValidTencentKey = serviceConfiguration.hasValidTencentKey;
    account.availableElevenLabsVoices =
        serviceConfiguration.availableElevenLabsVoices == null
            ? null
            : List.of(serviceConfiguration.availableElevenLabsVoices!);
    return account;
  }

  /// The population-level estimate for this profile, or null when the profile
  /// is not complete enough to produce one.
  ///
  /// Requires age, gender and fitness level together: each contributes an
  /// additive adjustment, so a missing field silently leaves a generic
  /// population default in its place. That is fine as a last-resort fallback
  /// for [baselineBiometrics], but not as a prior that the measured baseline
  /// is deliberately blended with.
  (int heartRate, double rmssd)? get demographicBaseline {
    if (age == null ||
        gender == null ||
        gender == Gender.unspecified ||
        fitnessLevel == null) {
      return null;
    }
    return _demographicEstimate();
  }

  (int heartRate, double rmssd) get baselineBiometrics {
    // if values have been determined return them
    if (baselineHeartRate != null && baselineRMSSD != null) {
      return (baselineHeartRate!, baselineRMSSD!);
    }

    final (defaultHeartRate, defaultRMSSD) = _demographicEstimate();

    // Demographic defaults are estimates for contexts that have no measured
    // baseline (for example a timed session). Do not persist them as if they
    // were sensor measurements; doing so would also make later profile edits
    // return stale estimates.
    return (
      baselineHeartRate ?? defaultHeartRate,
      baselineRMSSD ?? defaultRMSSD,
    );
  }

  (int heartRate, double rmssd) _demographicEstimate() {
    // refer to the default values if not set
    int defaultHeartRate = 72;
    double defaultRMSSD = 42.0;

    // Age adjustment for baseline values
    if (age != null) {
      if (age! < 25) {
        defaultHeartRate = 68;
        defaultRMSSD = 50.0;
      } else if (age! < 35) {
        defaultHeartRate = 70;
        defaultRMSSD = 42.0;
      } else if (age! < 45) {
        defaultHeartRate = 72;
        defaultRMSSD = 35.0;
      } else if (age! < 55) {
        defaultHeartRate = 74;
        defaultRMSSD = 28.0;
      } else if (age! < 65) {
        defaultHeartRate = 76;
        defaultRMSSD = 22.0;
      } else {
        defaultHeartRate = 78;
        defaultRMSSD = 18.0;
      }
    }

    // Gender adjustment for baseline values
    if (gender != null) {
      switch (gender!) {
        case Gender.male:
          defaultHeartRate -= 4;
          defaultRMSSD += 6.0;
          break;
        case Gender.female:
          defaultHeartRate += 4;
          defaultRMSSD -= 6.0;
          break;
        default:
          // No change for unspecified
          break;
      }
    }

    // Fitness level adjustment for baseline values
    if (fitnessLevel != null) {
      switch (fitnessLevel!) {
        case FitnessLevel.sedentary:
          defaultHeartRate += 8;
          defaultRMSSD -= 12.0;
          break;
        case FitnessLevel.moderate:
          // No change for moderate fitness level
          break;
        case FitnessLevel.active:
          defaultHeartRate -= 6;
          defaultRMSSD += 15.0;
          break;
        case FitnessLevel.athlete:
          defaultHeartRate -= 12;
          defaultRMSSD += 35.0;
          break;
      }
    }
    // The age/gender/fitness adjustments are additive, so the unlucky
    // combinations bottom out at or below zero — an over-65 sedentary woman
    // lands on exactly 0.0. stressThresholds() would then derive an RMSSD
    // threshold of 0, and "rmssd < 0" is never true, so stress could never be
    // detected for that profile at all. Floor it at a physiologically sane
    // value instead.
    defaultRMSSD = max(
      defaultRMSSD,
      OverallMeditationConfig.minimumProfileBaselineRmssd,
    );

    return (defaultHeartRate, defaultRMSSD);
  }

  /// Thresholds derived from the baseline biometrics and a sensitivity
  /// fraction. Pass [stressThreshold] to override the account's saved
  /// sensitivity for a single call (e.g. a demo session) without persisting
  /// it; omit it to use (and, the first time, cache) the account's own.
  (int, double) stressThresholds({double? stressThreshold}) {
    final (baselineHeartRate, baselineRMSSD) = baselineBiometrics;

    // A one-session override (for example, the conference demo's 3%) must not
    // mutate the permanent account preference.
    final threshold = stressThreshold ??
        (this.stressThreshold ??=
            OverallMeditationConfig.defaultStressSensitivity);

    final heartRateThreshold = (baselineHeartRate * (1 + threshold)).round();
    final rmssdThreshold = baselineRMSSD * (1 - threshold);
    return (heartRateThreshold, rmssdThreshold);
  }

  String getContextSummary() {
    final name = firstName?.trim();
    final ageDescription = age == null ? 'Not provided' : '$age years old';
    return '''User Profile:
- Name: ${name?.isNotEmpty == true ? name : 'the person you are guiding'}
- Age: $ageDescription
- Gender: ${gender?.label ?? 'Not provided'}
- Fitness Level: ${fitnessLevel == null ? 'Not provided' : _fitnessLevelLabel(fitnessLevel!)}
- Meditation Type: ${meditationType?.label ?? 'Not provided'}
- Meditation Environment: ${meditationEnvironment?.label ?? 'Not provided'}
- Additional Preferences: ${additionalPreferences ?? 'None'}
- Resting Heart Rate: ${baselineBiometrics.$1.toStringAsFixed(0)} BPM
- Baseline HRV (RMSSD): ${baselineBiometrics.$2.toStringAsFixed(0)} ms''';
  }

  static String _fitnessLevelLabel(FitnessLevel level) => switch (level) {
        FitnessLevel.sedentary => 'Sedentary',
        FitnessLevel.moderate => 'Moderate',
        FitnessLevel.active => 'Active',
        FitnessLevel.athlete => 'Athlete',
      };
}
