import 'overall_config.dart';

/// Parameters used only by timed meditation mode.
abstract final class TimedModeConfig {
  static const int segmentCount = 3;

  /// `null` makes regular timed segments narration-driven. The LLM is asked
  /// for [promptApproximateWordsPerSegment] words and no 30-second target is
  /// applied.
  static const Duration? segmentDurationOverride = null;

  static const Duration schedulePollingInterval = Duration(seconds: 1);
  static const Duration scheduleAfterFiveMinutes = Duration(minutes: 5);
  static const Duration scheduleAfterTenMinutes = Duration(minutes: 10);
  static const Duration scheduleAfterThirtyMinutes = Duration(minutes: 30);

  /// Timed mode uses the standard personalized prompt.
  static const int promptApproximateWordsPerSegment =
      OverallMeditationConfig.standardPromptApproximateWordsPerSegment;
}
