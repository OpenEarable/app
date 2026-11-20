import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/activity_models.dart';

/// Disk-backed snapshots and streaming raw traces, kept out of widget state.
/// A serial write queue prevents older checkpoints replacing newer snapshots.
class ActivityStorage {
  Directory? _directory;
  IOSink? _trace;
  Object? _traceError;
  Future<void> _writes = Future.value();
  Future<Directory> get directory async => _directory ??= await Directory(
        '${(await getApplicationSupportDirectory()).path}/activity_tracker',
      ).create(recursive: true);
  Future<Map<String, dynamic>?> load() async {
    final f = File('${(await directory).path}/sessions.json');
    if (!await f.exists()) return null;
    return jsonDecode(await f.readAsString()) as Map<String, dynamic>;
  }

  Future<void> save(Map<String, dynamic> snapshot) {
    final encoded = jsonEncode(snapshot);
    final next = _writes.then((_) async {
      final dir = await directory;
      final temp = File('${dir.path}/sessions.tmp');
      await temp.writeAsString(encoded, flush: true);
      await temp.rename('${dir.path}/sessions.json');
    });
    // Keep subsequent saves usable after a single I/O failure.
    _writes = next.catchError((Object _) {});
    return next;
  }

  Future<void> startTrace(String id) async {
    await closeTrace();
    _trace = File('${(await directory).path}/$id.csv')
        .openWrite(mode: FileMode.append);
    _traceError = null;
    _trace!.done.catchError((Object e) {
      _traceError = e;
    });
    _trace!.writeln(
      'sensor_seconds,ax_m_s2,ay_m_s2,az_m_s2,gx_rad_s,gy_rad_s,gz_rad_s,mode,paused,calibrated,step_delta,rep_delta,jump_height_cm',
    );
  }

  void append(
    MotionSample s,
    ActivityKind kind,
    bool paused,
    bool calibrated,
    int steps,
    int reps,
    double? height,
  ) {
    _trace?.writeln(
      '${s.seconds},${s.acceleration.x},${s.acceleration.y},${s.acceleration.z},${s.gyroscope?.x ?? ''},${s.gyroscope?.y ?? ''},${s.gyroscope?.z ?? ''},${kind.name},$paused,$calibrated,$steps,$reps,${height ?? ''}',
    );
  }

  Future<void> flushTrace() async {
    if (_traceError != null) {
      throw FileSystemException('Raw trace write failed: $_traceError');
    }
    await _trace?.flush();
  }

  Future<void> closeTrace() async {
    final sink = _trace;
    _trace = null;
    await sink?.flush();
    await sink?.close();
  }

  /// Explicit export includes session metadata, reference trials and raw IMU.
  Future<List<String>> export(ActivitySession session) async {
    await flushTrace();
    final root = (await directory).path;
    final json = File('$root/${session.id}.json');
    await json.writeAsString(
      const JsonEncoder.withIndent('  ').convert({
        'schemaVersion': 1,
        'algorithmVersion': 'heuristic-1',
        'heightModel':
            'g * flight_seconds^2 / 8; equal take-off and landing posture assumed',
        'session': session.toJson(),
      }),
    );
    final trials = File('$root/${session.id}_trials.csv');
    String cell(Object? value) =>
        '"${(value ?? '').toString().replaceAll('"', '""')}"';
    await trials.writeAsString(
      [
        'participant,movement_pattern,reference_source,result,captured_at,activity,detected,reference,count_error,absolute_percentage_error,estimated_height_cm,reference_height_cm,height_error_cm',
        ...session.trials.map(
          (t) => [
            t.participant,
            t.pattern,
            t.referenceSource,
            t.resultLabel,
            t.capturedAt?.toIso8601String(),
            t.kind.name,
            t.detected,
            t.reference,
            t.countError,
            t.absolutePercentageError,
            t.estimatedHeightCm,
            t.referenceHeightCm,
            t.heightErrorCm,
          ].map(cell).join(','),
        ),
      ].join('\n'),
    );
    final raw = File('$root/${session.id}.csv');
    return [json.path, if (await raw.exists()) raw.path, trials.path];
  }
}
