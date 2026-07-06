/// Lifecycle state of the YMCA ergometer test.
enum ErgoStatus {
  /// Not started yet.
  idle,

  /// The test is running.
  running,

  /// The test has ended and the recovery phase is running.
  ///
  /// Recording continues on all devices; only the start of the recovery is
  /// labelled. When the recovery countdown elapses the test moves to [ended].
  recovering,

  /// The test has ended.
  ended,
}

/// A single per-minute measurement recorded during the ergometer test.
class ErgoMeasurement {
  /// Minute index at which the measurement was due (1-based).
  final int minute;

  /// Stage the measurement belongs to (0 = warm-up).
  final int stage;

  /// App-suggested target wattage for the stage (null during the warm-up).
  final int? targetWatt;

  /// Actual wattage the experimenter read off the ergometer.
  final int actualWatt;

  /// Heart rate entered by the experimenter, in BPM.
  final int heartRate;

  const ErgoMeasurement({
    required this.minute,
    required this.stage,
    required this.targetWatt,
    required this.actualWatt,
    required this.heartRate,
  });
}

/// Minimum measurements a stage must run before it may advance.
///
/// A stage lasts at least three minutes, so the earliest steady-state check is
/// on the third measurement since the stage started.
const int ymcaMinMeasurementsPerStage = 3;

/// Maximum allowed heart-rate change (BPM) versus the previous minute for a
/// stage to count as steady state.
const int ymcaSteadyStateBpmTolerance = 5;

/// Wattage increment (in watts) applied for every stage after the first
/// stabilized workload.
const int ymcaStageIncrementWatt = 30;

/// Duration of the recovery phase that runs directly after the ergometer test.
///
/// Recording keeps running on all devices during recovery; only the start of
/// the recovery is labelled in the ergometer log.
const Duration ymcaRecoveryDuration = Duration(minutes: 15);

/// Computes the first workload wattage from the heart rate at the first
/// stabilized (warm-up) level of the modified YMCA test.
///
/// Boundary handling: 90 BPM falls in the 80–90 band (100 W) and 100 BPM in the
/// 90–100 band (70 W).
int ymcaInitialWattForHeartRate(int heartRate) {
  if (heartRate < 80) {
    return 130;
  }
  if (heartRate <= 90) {
    return 100;
  }
  if (heartRate <= 100) {
    return 70;
  }
  return 40;
}
