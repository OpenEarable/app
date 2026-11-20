import 'dart:convert';
import 'dart:io';
import 'package:open_wearable/apps/activity_tracker/models/activity_engine.dart';
import 'package:open_wearable/apps/activity_tracker/models/activity_models.dart';

/// Replays exported numeric IMU CSV files through the exact live algorithms.
/// Run: dart run tool/replay_activity_trace.dart path/to/session.csv [...]
Future<void> main(List<String> arguments) async {
  if (arguments.isEmpty) {
    stderr.writeln(
      'Usage: dart run tool/replay_activity_trace.dart <IMU.csv> [...]',
    );
    exitCode = 64;
    return;
  }
  final results = <Map<String, dynamic>>[];
  for (final path in arguments) {
    final engine = ActivityEngine();
    Map<String, double>? initialCalibration;
    final metadata = File(path.replaceFirst(RegExp(r'\.csv$'), '.json'));
    if (await metadata.exists()) {
      final json =
          jsonDecode(await metadata.readAsString()) as Map<String, dynamic>;
      final calibration = (json['session']
          as Map<String, dynamic>?)?['calibration'] as Map<String, dynamic>?;
      if (calibration != null && calibration.isNotEmpty) {
        initialCalibration =
            calibration.map((k, v) => MapEntry(k, (v as num).toDouble()));
      }
    }
    final counts = <String, int>{};
    final jumps = <Map<String, dynamic>>[];
    var steps = 0, samples = 0;
    var wasPaused = false;
    var sessionStarted = false;
    try {
      final rows = File(path)
          .openRead()
          .transform(utf8.decoder)
          .transform(const LineSplitter());
      List<String>? header;
      await for (final row in rows) {
        if (header == null) {
          header = row.split(',');
          if (!header.contains('sensor_seconds')) {
            throw const FormatException('Not an Activity Tracker IMU trace');
          }
          continue;
        }
        final cells = row.split(',');
        final values = Map.fromIterables(header, cells);
        double number(String key) => double.parse(values[key]!);
        final paused = values['paused'] == 'true';
        if (paused) {
          if (!wasPaused) engine.recalibrate();
          wasPaused = true;
          continue;
        }
        wasPaused = false;
        final kind = ActivityKind.values.byName(values['mode']!);
        if (!sessionStarted && values['calibrated'] == 'true') {
          if (initialCalibration != null) {
            engine.restoreCalibration(initialCalibration);
          }
          engine.select(kind);
          sessionStarted = true;
        }
        if (engine.kind != kind) engine.select(kind);
        final update = engine.add(
          MotionSample(
            number('sensor_seconds'),
            MotionVector(
              number('ax_m_s2'),
              number('ay_m_s2'),
              number('az_m_s2'),
            ),
            gyroscope: values['gx_rad_s'] == ''
                ? null
                : MotionVector(
                    number('gx_rad_s'),
                    number('gy_rad_s'),
                    number('gz_rad_s'),
                  ),
          ),
        );
        samples++;
        // Pre-roll calibrates the replay but is outside the recorded session.
        if (values['calibrated'] != 'true') continue;
        steps += update.steps;
        counts.update(
          kind.name,
          (n) => n + update.repetitions,
          ifAbsent: () => update.repetitions,
        );
        if (update.jump != null) jumps.add(update.jump!.toJson());
      }
      results.add({
        'file': path,
        'algorithmVersion': 'heuristic-1',
        'initialCalibrationRestored': initialCalibration != null,
        'calibratedAtEnd': engine.calibrated,
        'samples': samples,
        'steps': steps,
        'repetitionsByMode': counts,
        'jumps': jumps,
      });
    } catch (e) {
      stderr.writeln('$path: $e');
      exitCode = 1;
    }
  }
  stdout.writeln(const JsonEncoder.withIndent('  ').convert(results));
}
