/// Immutable participant context for one study session.
///
/// Carries the proband id and age entered when a recording is started, and
/// derives the age-based heart-rate limits used by the ergometer protocol:
/// `HR_max = 220 - age` and the 85% submaximal target `HR_submax`.
class StudySession {
  static const Duration testModeTimerDuration = Duration(seconds: 10);

  /// Participant identifier (used in file names).
  final String probandId;

  /// Participant age in years.
  final int age;

  /// Whether protocol timers should be shortened for local test runs.
  final bool timerTestMode;

  const StudySession({
    required this.probandId,
    required this.age,
    this.timerTestMode = false,
  });

  /// Age-predicted maximum heart rate: `220 - age`.
  int get maxHeartRate => 220 - age;

  /// 85% submaximal heart rate used as the ergometer abort target.
  int get submaxHeartRate => (0.85 * maxHeartRate).round();
}
