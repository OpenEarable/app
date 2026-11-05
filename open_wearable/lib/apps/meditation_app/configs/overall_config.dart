/// Configuration shared by every meditation mode.
///
/// This file intentionally contains runtime values, not a second descriptive
/// copy. Mode-specific files may alias these constants when they inherit the
/// shared behavior. Low-level DSP coefficients remain next to the algorithms
/// they tune in `hr_hrv_processor.dart`.
abstract final class OverallMeditationConfig {
  // Session playback.
  static const int defaultSegmentCount = 10;
  // Regular sessions are narration-driven: once TTS has finished, no extra
  // minimum segment hold is imposed. The conference demo owns its explicit
  // 30-second segment target in DemoModeConfig.
  static const Duration standardNarrationMinimumDuration = Duration.zero;
  static const Duration progressUpdateInterval = Duration(seconds: 1);

  /// How many segments a session without biosignals may produce ahead of the
  /// one being played.
  ///
  /// Generation and speech synthesis used to happen in the silence between
  /// segments; they now run during playback. One segment of lookahead already
  /// covers a normal wait, so the extra depth exists to absorb an unusually
  /// slow request rather than to go faster. Biosignal-adaptive sessions are
  /// pinned to one: their next request carries the biometrics sampled when the
  /// current segment starts and cannot be made before then.
  static const int narrationPrefetchDepth = 3;
  static const double backgroundMusicVolume = 1;
  static const String audioAssetPrefix =
      'lib/apps/meditation_app/assets/audio/';

  // Used by both regular biosignal-adaptive and timed meditation segments.
  // Their duration is determined by the resulting narration, not by a
  // 30-second target.
  static const int standardPromptApproximateWordsPerSegment = 280;

  // DeepSeek generation.
  static const String deepseekApiBaseUrl = 'https://api.deepseek.com';
  static const String deepseekChatPath = '/chat/completions';
  static const String deepseekBalancePath = '/user/balance';
  static const String deepseekModel = 'deepseek-v4-pro';
  static const int deepseekMaxTokens = 2000;
  static const double deepseekTemperature = 0.7;
  static const Duration deepseekRequestTimeout = Duration(seconds: 30);

  // ElevenLabs synthesis and credential checks.
  static const String elevenLabsApiBaseUrl = 'https://api.elevenlabs.io';
  static const String elevenLabsModel = 'eleven_flash_v2_5';
  static const String elevenLabsMaleVoiceId = 'CwhRBWXzGAHq8TQ4Fs17';
  static const String elevenLabsFemaleVoiceId = 'hpp4J3VqNfWAUOO0d1Us';
  static const Duration elevenLabsRequestTimeout = Duration(seconds: 20);
  // ElevenLabs accepts 0.7-1.2 and recommends staying near 0.8-1.1, where 1.0
  // is the voice's natural pace. Same shape as the Tencent mapping: medium is
  // natural, slow is below it, fast above.
  static const double elevenLabsVerySlowSpeechRate = 0.75;
  static const double elevenLabsSlowSpeechRate = 0.85;
  static const double elevenLabsMediumSpeechRate = 1.0;
  static const double elevenLabsFastSpeechRate = 1.10;

  // Tencent TextToVoice. International and Mainland China use different API
  // hosts and account/service activations; the active choice still comes from
  // TENCENT_TTS_REGION or the in-app selector.
  static const String tencentInternationalRegion = 'ap-singapore';
  static const String tencentInternationalHost = 'tts.intl.tencentcloudapi.com';
  static const String tencentChinaRegion = 'ap-guangzhou';
  static const String tencentChinaHost = 'tts.tencentcloudapi.com';
  static const int tencentPremiumMaleVoiceType = 101050;
  static const int tencentPremiumFemaleVoiceType = 101051;
  static const Duration tencentRequestTimeout = Duration(seconds: 25);
  static const int tencentTextChunkMaxUnits = 460;
  static const int tencentVolume = 0;
  static const int tencentProjectId = 0;
  static const int tencentModelType = 1;
  static const int tencentPrimaryLanguageEnglish = 2;
  static const int tencentSampleRate = 16000;
  static const String tencentCodec = 'mp3';
  static const bool tencentEnableSubtitle = false;

  // A cloud provider is selected once per meditation. These retries happen
  // before the session stops; it never changes to another voice mid-session.
  static const List<Duration> cloudTtsRetryDelays = [
    Duration.zero,
    Duration(seconds: 1),
    Duration(seconds: 2),
  ];

  // On-device fallback used only when no configured cloud provider is usable
  // at session start.
  static const String fallbackLanguage = 'en-US';
  static const double fallbackSpeechRate = 0.3;
  static const double fallbackVolume = 0.8;
  static const double verySlowSpeechRate = 0.2;
  static const double slowSpeechRate = 0.3;
  static const double mediumSpeechRate = 0.5;
  static const double fastSpeechRate = 0.7;
  static const double tencentVerySlowSpeechRate = -2;
  static const double tencentSlowSpeechRate = -1;
  static const double tencentMediumSpeechRate = 0;
  static const double tencentFastSpeechRate = 1;
  static const double tencentCredentialCheckSpeechRate = 0;
  static const Map<String, String> fallbackFemaleVoice = {
    'name': 'en-us-x-sfg-local',
    'locale': fallbackLanguage,
  };
  static const Map<String, String> fallbackMaleVoice = {
    'name': 'en-us-x-iob-local',
    'locale': fallbackLanguage,
  };

  // Legacy/import configuration tokens. The public app does not bundle or
  // load an environment file; users configure credentials in the API Keys UI.
  static const String deepseekApiKeyEnvironmentKey = 'DEEPSEEK_API_KEY';
  static const String elevenLabsApiKeyEnvironmentKey = 'ELEVENLABS_API_KEY';
  static const String ttsProviderEnvironmentKey = 'TTS_PROVIDER';
  static const String elevenLabsProviderEnvironmentValue = 'elevenlabs';
  static const String tencentProviderEnvironmentValue = 'tencent';
  static const String tencentSecretIdEnvironmentKey = 'TENCENT_SECRET_ID';
  static const String tencentSecretKeyEnvironmentKey = 'TENCENT_SECRET_KEY';
  static const String tencentLegacySecretKeyEnvironmentKey =
      'TENCENT_TTS_API_KEY';
  static const String tencentRegionEnvironmentKey = 'TENCENT_TTS_REGION';

  // Shared account defaults used only when no measured/profile value exists.
  static const double verySensitiveStressSensitivity = 0.05;
  static const double defaultStressSensitivity = 0.10;
  static const double moderateStressSensitivity = 0.15;
  static const double lessSensitiveStressSensitivity = 0.20;
  static const double minimumProfileBaselineRmssd = 12;

  // Weekly analytics includes regular biosignal-adaptive and timed sessions;
  // demo sessions never receive an analytics store.
  static const String analyticsStorageKey = 'meditation_session_analytics_v1';
  static const Duration analyticsRetention = Duration(days: 366);
  static const Duration analyticsWeekLength = Duration(days: 7);

  // Credential checks in the settings UI.
  static const Duration credentialCheckTimeout = Duration(seconds: 20);
}
