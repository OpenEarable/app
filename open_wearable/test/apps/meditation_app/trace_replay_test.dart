// Offline analysis harness for a captured meditation biosignal session.
//
// This is a diagnostic tool rather than a regression test: it is skipped unless
// a trace file is supplied, and it reports rather than asserts behaviour.
//
// Capture a session on the device with:
//   flutter run --dart-define=MEDITATION_CAPTURE_SIGNAL=true
//
// Then analyse the resulting JSONL from open_wearable/ with:
//   flutter test test/apps/meditation_app/trace_replay_test.dart "--dart-define=MEDITATION_TRACE=C:\Users\you\Downloads\hr_hrv_2026-01-01T00-00-00-000000Z.jsonl"
//
// Quote the whole --dart-define argument. PowerShell reads < and > as
// redirection, so an angle-bracket placeholder is a syntax error.
//
// The trace holds beat times and raw photoplethysmography. That is sensitive
// physiological data: keep it local and delete it after analysis.

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:open_wearable/apps/meditation_app/model/hr_hrv_processor.dart';

const _tracePath = String.fromEnvironment('MEDITATION_TRACE');

void main() {
  test(
    'replays a captured session and summarises its measurements',
    () async {
      final events = _readTrace(_tracePath);
      expect(events, isNotEmpty, reason: 'No parsable events in $_tracePath');

      _report('Trace: $_tracePath');
      _report('Events: ${events.length}');

      final audioAt = _relativeSecondsOf(events, 'audio_started');
      _reportMarkers(events);
      _reportStreamHealth(events, audioAt);
      _reportDetectorComparison(events, audioAt);
      _reportPublishedMetrics(events, audioAt);

      final replayed = await _replayRawCapture(events);
      if (replayed == null) {
        _report('');
        _report('No ppg_raw_block events: capture this session with '
            '--dart-define=MEDITATION_CAPTURE_SIGNAL=true to enable replay.');
      }
    },
    skip: _tracePath.isEmpty
        ? 'Supply a capture with --dart-define=MEDITATION_TRACE=<file>'
        : false,
  );
}

// --- trace loading ---------------------------------------------------------

List<Map<String, Object?>> _readTrace(String path) {
  final file = File(path);
  if (!file.existsSync()) {
    fail('Trace file not found: $path');
  }
  final events = <Map<String, Object?>>[];
  for (final line in file.readAsLinesSync()) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) continue;
    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is Map<String, dynamic>) events.add(decoded);
    } catch (_) {
      // A session that ended abruptly can leave one partial final line.
    }
  }
  return events;
}

DateTime? _recordedAt(Map<String, Object?> event) {
  final raw = event['recorded_at'];
  return raw is String ? DateTime.tryParse(raw) : null;
}

double? _relativeSeconds(
  List<Map<String, Object?>> events,
  Map<String, Object?> event,
) {
  final start = _recordedAt(events.first);
  final at = _recordedAt(event);
  if (start == null || at == null) return null;
  return at.difference(start).inMilliseconds / 1000.0;
}

double? _relativeSecondsOf(List<Map<String, Object?>> events, String name) {
  for (final event in events) {
    if (event['event'] == name) return _relativeSeconds(events, event);
  }
  return null;
}

// --- reports ---------------------------------------------------------------

void _report(String line) {
  // ignore: avoid_print
  print(line);
}

void _reportMarkers(List<Map<String, Object?>> events) {
  const interesting = {
    'processor_created',
    'phase_changed',
    'monitoring_started',
    'baseline_deadline',
    'meditation_triggered',
    'audio_start_requested',
    'audio_started',
    'audio_skipped_for_diagnostics',
    'narration_requested',
    'narration_finished',
    'app_lifecycle',
    'stream_paused',
    'stream_resumed',
    'processor_disposed',
  };
  _report('');
  _report('== session markers ==');
  for (final event in events) {
    final name = event['event'];
    if (name is! String || !interesting.contains(name)) continue;
    final at = _relativeSeconds(events, event);
    final detail = <String>[
      for (final key in const ['phase', 'state', 'selected_source'])
        if (event[key] != null) '$key=${event[key]}',
    ].join(' ');
    _report('  t=${at?.toStringAsFixed(1).padLeft(7)}s  $name  $detail');
  }
}

void _reportStreamHealth(
  List<Map<String, Object?>> events,
  double? audioAt,
) {
  final before = <Map<String, Object?>>[];
  final after = <Map<String, Object?>>[];
  for (final event in events) {
    if (event['event'] != 'stream_health') continue;
    final at = _relativeSeconds(events, event);
    if (audioAt == null || at == null || at < audioAt) {
      before.add(event);
    } else {
      after.add(event);
    }
  }

  _report('');
  _report('== stream health ==');
  void summarise(String label, List<Map<String, Object?>> rows) {
    if (rows.isEmpty) return;
    final rates = rows
        .map((row) => (row['observed_hz'] as num?)?.toDouble())
        .whereType<double>()
        .toList()
      ..sort();
    final gaps = rows
        .map((row) => (row['maximum_gap_ms'] as num?)?.toDouble() ?? 0)
        .toList()
      ..sort();
    final gapCount = rows.fold<int>(
      0,
      (sum, row) => sum + ((row['gap_count'] as num?)?.toInt() ?? 0),
    );
    _report('  $label (${rows.length} windows)');
    if (rates.isNotEmpty) {
      _report('    observed_hz  median=${_median(rates).toStringAsFixed(1)}'
          '  min=${rates.first.toStringAsFixed(1)}'
          '  max=${rates.last.toStringAsFixed(1)}');
    }
    _report('    max_gap_ms   median=${_median(gaps).toStringAsFixed(1)}'
        '  p90=${_percentile(gaps, 0.9).toStringAsFixed(1)}'
        '  max=${gaps.last.toStringAsFixed(1)}');
    _report('    gaps total=$gapCount');
  }

  summarise('before audio', before);
  summarise('after audio ', after);
}

void _reportDetectorComparison(
  List<Map<String, Object?>> events,
  double? audioAt,
) {
  final byPhaseAndMode = <String, Map<String, List<Map<String, Object?>>>>{};
  for (final event in events) {
    if (event['event'] != 'detector_comparison') continue;
    final at = _relativeSeconds(events, event);
    final phase =
        (audioAt == null || at == null || at < audioAt) ? 'before' : 'after';
    final candidates = event['candidates'];
    if (candidates is! List) continue;
    final spanMs = (event['window_span_ms'] as num?)?.toDouble();
    for (final candidate in candidates.cast<Map<String, dynamic>>()) {
      final path = candidate['signal_path'] as String?;
      final mode = path == null
          ? (candidate['mode'] as String? ?? 'unknown')
          : '${candidate['mode']} [$path]';
      // Beats expected in this window at the detector's own reported rate.
      // A yield below 1.0 means beats are being missed, which is what inflates
      // RMSSD; above 1.0 means extra peaks, usually the dicrotic notch.
      final hr = (candidate['heart_rate_bpm'] as num?)?.toDouble();
      final peaks = (candidate['peak_count'] as num?)?.toDouble();
      if (spanMs != null && hr != null && hr > 0 && peaks != null) {
        candidate['beat_yield'] = peaks / (spanMs / 1000 * hr / 60);
      }
      byPhaseAndMode
          .putIfAbsent(phase, () => {})
          .putIfAbsent(mode, () => [])
          .add(candidate);
    }
  }

  _report('');
  _report('== detector modes on identical windows ==');
  if (byPhaseAndMode.isEmpty) {
    _report('  none recorded (needs a traced run reaching a comparison point)');
    return;
  }
  for (final phase in const ['before', 'after']) {
    final modes = byPhaseAndMode[phase];
    if (modes == null || modes.isEmpty) continue;
    _report('  $phase audio:');
    _report('    ${'mode'.padRight(34)}${'peaks'.padLeft(7)}'
        '${'clean'.padLeft(7)}${'acc'.padLeft(7)}${'rej'.padLeft(7)}'
        '${'HR'.padLeft(9)}${'RMSSD'.padLeft(9)}${'yield'.padLeft(8)}');
    final entries = modes.entries.toList()
      ..sort(
        (a, b) => _meanOf(b.value, 'clean_pair_count')
            .compareTo(_meanOf(a.value, 'clean_pair_count')),
      );
    for (final entry in entries) {
      final rows = entry.value;
      _report('    ${entry.key.padRight(34)}'
          '${_meanOf(rows, 'peak_count').toStringAsFixed(1).padLeft(7)}'
          '${_meanOf(rows, 'clean_pair_count').toStringAsFixed(1).padLeft(7)}'
          '${_meanOf(rows, 'accepted_interval_count').toStringAsFixed(1).padLeft(7)}'
          '${_meanOf(rows, 'rejected_interval_count').toStringAsFixed(1).padLeft(7)}'
          '${_meanOf(rows, 'heart_rate_bpm').toStringAsFixed(1).padLeft(9)}'
          '${_meanOf(rows, 'rmssd_ms').toStringAsFixed(1).padLeft(9)}'
          '${_meanOf(rows, 'beat_yield').toStringAsFixed(2).padLeft(8)}');
    }
    _report('    (means over ${entries.first.value.length} windows; '
        'higher clean-pair counts and fewer rejected intervals are better)');
  }
}

void _reportPublishedMetrics(
  List<Map<String, Object?>> events,
  double? audioAt,
) {
  final before = <Map<String, Object?>>[];
  final after = <Map<String, Object?>>[];
  for (final event in events) {
    if (event['event'] != 'metric_published') continue;
    final at = _relativeSeconds(events, event);
    if (audioAt == null || at == null || at < audioAt) {
      before.add(event);
    } else {
      after.add(event);
    }
  }

  _report('');
  _report('== published metrics ==');
  void summarise(String label, List<Map<String, Object?>> rows) {
    if (rows.isEmpty) return;
    final hr = rows
        .map((row) => (row['heart_rate_bpm'] as num?)?.toDouble())
        .whereType<double>()
        .toList()
      ..sort();
    final rmssd = rows
        .map((row) => (row['rmssd_ms'] as num?)?.toDouble())
        .whereType<double>()
        .toList()
      ..sort();
    final nulls = rows.length - rmssd.length;
    _report('  $label  n=${rows.length}');
    if (hr.isNotEmpty) {
      _report('    HR     median=${_median(hr).toStringAsFixed(0)}'
          '  range ${hr.first.toStringAsFixed(0)}-${hr.last.toStringAsFixed(0)}');
    }
    if (rmssd.isNotEmpty) {
      _report('    RMSSD  median=${_median(rmssd).toStringAsFixed(1)} ms'
          '  range ${rmssd.first.toStringAsFixed(1)}-'
          '${rmssd.last.toStringAsFixed(1)} ms  (null in $nulls)');
      if (_median(rmssd) > 120) {
        _report('    !! a resting RMSSD above ~120 ms indicates missed or '
            'doubled beats rather than real variability');
      }
    } else {
      _report('    RMSSD  unavailable in all $nulls samples');
    }
  }

  summarise('before audio', before);
  summarise('after audio ', after);
}

// --- replay ----------------------------------------------------------------

/// Re-runs the captured raw signal through the real pipeline. Returns null when
/// the trace holds no waveform capture.
Future<List<HeartRateSample>?> _replayRawCapture(
  List<Map<String, Object?>> events,
) async {
  final hasRaw = events.any((event) => event['event'] == 'ppg_raw_block');
  if (!hasRaw) return null;

  final created = events.firstWhere(
    (event) => event['event'] == 'processor_created',
    orElse: () => <String, Object?>{},
  );
  final metadata = events.firstWhere(
    (event) => event['event'] == 'sensor_metadata',
    orElse: () => <String, Object?>{},
  );

  final ppgHz = (created['configured_ppg_hz'] as num?)?.toDouble() ??
      (metadata['configured_ppg_hz'] as num?)?.toDouble() ??
      200.0;
  final imuHz = (created['configured_accelerometer_hz'] as num?)?.toDouble() ??
      (metadata['configured_accelerometer_hz'] as num?)?.toDouble() ??
      50.0;
  final exponent = (metadata['ppg_timestamp_exponent'] as num?)?.toInt() ?? -6;

  final windowMs = (created['metric_window_ms'] as num?)?.toDouble();
  final eligibilityMs = (created['metric_eligibility_ms'] as num?)?.toDouble();
  final hrvHistoryMs = (created['hrv_history_window_ms'] as num?)?.toDouble();
  final hrvMinimumMs = (created['hrv_minimum_window_ms'] as num?)?.toDouble();
  // A non-null metricWindowDuration drives all three windows to one value, so
  // that is how the original session's setting is recovered here.
  final sharedWindow = windowMs != null &&
          eligibilityMs != null &&
          hrvHistoryMs != null &&
          (windowMs - eligibilityMs).abs() < 1 &&
          (windowMs - hrvHistoryMs).abs() < 1
      ? Duration(milliseconds: windowMs.round())
      : null;

  _report('');
  _report('== replay ==');
  _report('  ppg=${ppgHz}Hz imu=${imuHz}Hz exponent=$exponent '
      'metricWindow=${sharedWindow?.inSeconds ?? "default"} '
      'hrvMinimum=${hrvMinimumMs == null ? "default" : (hrvMinimumMs / 1000).round()}s');

  Future<List<HeartRateSample>> run() async {
    final ticksPerSecond = pow(10, -exponent).toDouble();
    final origin = DateTime(2026);
    // Anchored to the session's first sample, not each block's base: the
    // processor's warm-up and emit gating run off this clock, so a per-block
    // anchor would rewind it every block and nothing would ever be published.
    int? sessionBaseTicks;
    var now = origin;
    final processor = HrHrvProcessor(
      sampleFreq: ppgHz,
      accelerometerFreq: imuHz,
      timestampExponent: exponent,
      hrvMinimumWindow: hrvMinimumMs == null
          ? null
          : Duration(milliseconds: hrvMinimumMs.round()),
      metricWindowDuration: sharedWindow,
      publishBestEffortEstimates: created['best_effort_enabled'] == true,
      now: () => now,
    );
    addTearDown(processor.dispose);
    final published = <HeartRateSample>[];
    final subscription = processor.biometricStream.listen(published.add);
    addTearDown(subscription.cancel);

    // File order is emission order, so replaying events in sequence reproduces
    // the original interleaving of phase changes and sensor samples.
    for (final event in events) {
      switch (event['event']) {
        case 'phase_changed':
          if (event['phase'] == 'calibration') {
            processor.beginCalibration();
          } else if (event['phase'] == 'measurement') {
            processor.beginMeasurement();
          }
        case 'imu_raw_block':
          _forEachSample(event, const ['x', 'y', 'z'], (timestamp, values) {
            processor.processAccelerometerSample(
              timestamp,
              values[0],
              values[1],
              values[2],
            );
          });
        case 'ppg_raw_block':
          _forEachSample(event, const ['red', 'ir', 'green', 'ambient'],
              (timestamp, values) {
            sessionBaseTicks ??= timestamp;
            now = origin.add(
              Duration(
                microseconds:
                    ((timestamp - sessionBaseTicks!) / ticksPerSecond * 1e6)
                        .round(),
              ),
            );
            processor.processPpgSample(
              timestamp,
              values[0],
              values[1],
              values[2],
              values[3],
            );
          });
      }
    }
    await Future<void>.delayed(Duration.zero);
    return published;
  }

  final published = await run();

  void summarise(String label, List<HeartRateSample> samples) {
    final hr = samples.map((s) => s.heartRate.toDouble()).toList()..sort();
    final rmssd = samples.map((s) => s.rmssd).whereType<double>().toList()
      ..sort();
    _report('  $label  published=${samples.length}'
        '  HR median=${hr.isEmpty ? "n/a" : _median(hr).toStringAsFixed(0)}'
        '  RMSSD median='
        '${rmssd.isEmpty ? "n/a" : "${_median(rmssd).toStringAsFixed(1)} ms"}'
        '  (null in ${samples.length - rmssd.length})');
  }

  summarise('replayed pipeline', published);
  _report('  A resting RMSSD in the 20-80 ms band is physiological; well '
      'above that means beats are being missed or doubled.');
  return published;
}

int _baseOf(Map<String, Object?> event) =>
    (event['base_timestamp_ticks'] as num?)?.toInt() ?? 0;

void _forEachSample(
  Map<String, Object?> event,
  List<String> channels,
  void Function(int timestamp, List<double> values) consume,
) {
  final base = _baseOf(event);
  final offsets = (event['timestamp_offsets_ticks'] as List?)?.cast<num>();
  if (offsets == null) return;
  final columns = <List<num>>[];
  for (final channel in channels) {
    final column = (event[channel] as List?)?.cast<num>();
    if (column == null) return;
    columns.add(column);
  }
  for (var index = 0; index < offsets.length; index++) {
    if (columns.any((column) => index >= column.length)) break;
    consume(
      base + offsets[index].toInt(),
      [for (final column in columns) column[index].toDouble()],
    );
  }
}

// --- statistics ------------------------------------------------------------

double _median(List<double> sorted) =>
    sorted.isEmpty ? double.nan : sorted[sorted.length ~/ 2];

double _percentile(List<double> sorted, double fraction) => sorted.isEmpty
    ? double.nan
    : sorted[min(sorted.length - 1, (sorted.length * fraction).floor())];

double _meanOf(List<Map<String, Object?>> rows, String key) {
  final values = rows
      .map((row) => (row[key] as num?)?.toDouble())
      .whereType<double>()
      .toList();
  if (values.isEmpty) return double.nan;
  return values.reduce((a, b) => a + b) / values.length;
}
