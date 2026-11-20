import 'dart:math' as math;

/// Core activities selected by the user. No automatic activity classifier.
enum ActivityKind {
  steps('Steps'),
  squats('Squats'),
  pushUps('Push-ups'),
  jumps('Jump test');

  const ActivityKind(this.label);
  final String label;
}

/// IMU vector in sensor coordinates, using SI units.
class MotionVector {
  const MotionVector(this.x, this.y, this.z);
  static const zero = MotionVector(0, 0, 0);
  final double x, y, z;
  MotionVector operator +(MotionVector b) =>
      MotionVector(x + b.x, y + b.y, z + b.z);
  MotionVector operator -(MotionVector b) =>
      MotionVector(x - b.x, y - b.y, z - b.z);
  MotionVector operator *(double s) => MotionVector(x * s, y * s, z * s);
  double dot(MotionVector b) => x * b.x + y * b.y + z * b.z;
  MotionVector cross(MotionVector b) =>
      MotionVector(y * b.z - z * b.y, z * b.x - x * b.z, x * b.y - y * b.x);
  double get length => math.sqrt(dot(this));
  MotionVector get unit => length > 0 ? this * (1 / length) : zero;
  bool get isFinite => x.isFinite && y.isFinite && z.isFinite;
}

/// One accelerometer sample plus a recent gyroscope sample (rad/s).
/// [seconds] uses the sensor clock, converted using its timestamp exponent.
class MotionSample {
  const MotionSample(this.seconds, this.acceleration, {this.gyroscope});
  final double seconds;
  final MotionVector acceleration;
  final MotionVector? gyroscope;
}

/// Flight-time estimate. A null height explicitly marks an unusable attempt.
class JumpAttempt {
  const JumpAttempt({
    required this.at,
    required this.flightSeconds,
    this.heightCm,
    this.reason,
  });
  final double at, flightSeconds;
  final double? heightCm;
  final String? reason;
  Map<String, dynamic> toJson() => {
        'at': at,
        'flightSeconds': flightSeconds,
        'heightCm': heightCm,
        'reason': reason,
      };
  factory JumpAttempt.fromJson(Map<String, dynamic> j) => JumpAttempt(
        at: (j['at'] as num).toDouble(),
        flightSeconds: (j['flightSeconds'] as num).toDouble(),
        heightCm: (j['heightCm'] as num?)?.toDouble(),
        reason: j['reason'] as String?,
      );
}

/// A completed manually selected exercise set.
class ExerciseSet {
  const ExerciseSet({
    required this.kind,
    required this.repetitions,
    required this.seconds,
  });
  final ActivityKind kind;
  final int repetitions, seconds;
  Map<String, dynamic> toJson() =>
      {'kind': kind.name, 'repetitions': repetitions, 'seconds': seconds};
  factory ExerciseSet.fromJson(Map<String, dynamic> j) => ExerciseSet(
        kind: ActivityKind.values.byName(j['kind']),
        repetitions: j['repetitions'],
        seconds: j['seconds'],
      );
}

/// Independent ground truth for a single trial; no inferred labels are used.
class ValidationTrial {
  const ValidationTrial({
    required this.participant,
    required this.pattern,
    required this.referenceSource,
    required this.kind,
    required this.detected,
    required this.reference,
    this.estimatedHeightCm,
    this.referenceHeightCm,
    this.resultLabel = '',
    this.capturedAt,
  });
  final String participant, pattern, referenceSource;
  final String resultLabel;
  final DateTime? capturedAt;
  final ActivityKind kind;
  final int detected, reference;
  final double? estimatedHeightCm, referenceHeightCm;
  int get countError => detected - reference;
  double? get absolutePercentageError =>
      reference > 0 ? countError.abs() / reference * 100 : null;
  double? get heightErrorCm =>
      estimatedHeightCm != null && referenceHeightCm != null
          ? estimatedHeightCm! - referenceHeightCm!
          : null;
  Map<String, dynamic> toJson() => {
        'participant': participant,
        'pattern': pattern,
        'referenceSource': referenceSource,
        'resultLabel': resultLabel,
        'capturedAt': capturedAt?.toIso8601String(),
        'kind': kind.name,
        'detected': detected,
        'reference': reference,
        'estimatedHeightCm': estimatedHeightCm,
        'referenceHeightCm': referenceHeightCm,
      };
  factory ValidationTrial.fromJson(Map<String, dynamic> j) => ValidationTrial(
        participant: j['participant'],
        pattern: j['pattern'],
        referenceSource: j['referenceSource'],
        resultLabel: j['resultLabel'] ?? '',
        capturedAt: DateTime.tryParse(j['capturedAt'] ?? ''),
        kind: ActivityKind.values.byName(j['kind']),
        detected: j['detected'],
        reference: j['reference'],
        estimatedHeightCm: (j['estimatedHeightCm'] as num?)?.toDouble(),
        referenceHeightCm: (j['referenceHeightCm'] as num?)?.toDouble(),
      );
}

/// Persisted session, including interrupted sessions recovered after restart.
class ActivitySession {
  ActivitySession({
    required this.id,
    required this.startedAt,
    required this.deviceName,
    this.endedAt,
    this.steps = 0,
    this.interrupted = false,
    this.calibration = const {},
    List<ExerciseSet>? sets,
    List<JumpAttempt>? jumps,
    List<ValidationTrial>? trials,
  })  : sets = sets ?? [],
        jumps = jumps ?? [],
        trials = trials ?? [];
  final String id, deviceName;
  final Map<String, double> calibration;
  final DateTime startedAt;
  DateTime? endedAt;
  int steps;
  bool interrupted;
  final List<ExerciseSet> sets;
  final List<JumpAttempt> jumps;
  final List<ValidationTrial> trials;
  int get repetitions => sets.fold(0, (n, s) => n + s.repetitions);
  double? get bestHeightCm => jumps
      .map((j) => j.heightCm)
      .whereType<double>()
      .fold<double?>(null, (best, h) => best == null || h > best ? h : best);
  Map<String, dynamic> toJson() => {
        'id': id,
        'startedAt': startedAt.toIso8601String(),
        'endedAt': endedAt?.toIso8601String(),
        'deviceName': deviceName,
        'steps': steps,
        'interrupted': interrupted,
        'calibration': calibration,
        'sets': sets.map((s) => s.toJson()).toList(),
        'jumps': jumps.map((s) => s.toJson()).toList(),
        'trials': trials.map((s) => s.toJson()).toList(),
      };
  factory ActivitySession.fromJson(Map<String, dynamic> j) => ActivitySession(
        id: j['id'],
        startedAt: DateTime.parse(j['startedAt']),
        endedAt: j['endedAt'] == null ? null : DateTime.parse(j['endedAt']),
        deviceName: j['deviceName'],
        steps: j['steps'] ?? 0,
        interrupted: j['interrupted'] ?? false,
        calibration: (j['calibration'] as Map<String, dynamic>? ?? {})
            .map((key, value) => MapEntry(key, (value as num).toDouble())),
        sets: (j['sets'] as List).map((e) => ExerciseSet.fromJson(e)).toList(),
        jumps:
            (j['jumps'] as List).map((e) => JumpAttempt.fromJson(e)).toList(),
        trials: (j['trials'] as List? ?? [])
            .map((e) => ValidationTrial.fromJson(e))
            .toList(),
      );
}
