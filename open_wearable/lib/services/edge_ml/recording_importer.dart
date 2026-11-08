import 'dart:convert';

import 'package:edge_ml_dart/edge_ml_dart.dart';

import '../../widgets/sensors/local_recorder/local_recorder_models.dart';
import '../../widgets/sensors/local_recorder/local_recorder_storage.dart';

/// A conversion preview. No network requests are made by the importer.
class EdgeMlRecordingImport {
  const EdgeMlRecordingImport({
    required this.recording,
    required this.channelNames,
    required this.warnings,
    required this.firstTimestampMs,
    required this.lastTimestampMs,
  });

  final DatasetRecording recording;
  final List<String> channelNames;
  final List<String> warnings;
  final int firstTimestampMs;
  final int lastTimestampMs;
}

/// Converts completed local recordings, preserving each file's sensor channels.
///
/// Legacy CSV files have no schema metadata. This reader accepts Unix epoch
/// milliseconds and microseconds, distinguished by magnitude. It never changes
/// sampling rates or assumes sensor files share timestamps. Units and quantities
/// are intentionally omitted when the source files do not specify them.
class EdgeMlRecordingImporter {
  const EdgeMlRecordingImporter();

  Future<EdgeMlRecordingImport> read(
    LocalRecorderRecordingFolder folder, {
    String? datasetName,
    Future<String> Function(LocalRecorderRecordingFile)? readText,
  }) async {
    final name = (datasetName ?? folder.name).trim();
    if (name.isEmpty) throw const FormatException('Enter a dataset name.');
    final recording = DatasetRecording(
      name,
      metadata: {
        'source': 'OpenWearables',
        'recordingFolder': folder.name,
        'timestampUnit': 'unix milliseconds',
      },
    );
    final load = readText ?? readRecordingFileText;
    final warnings = <String>[];
    final channels = <String>{};
    final labelFiles = <_CsvFile>[];
    int? first;
    int? last;
    final files = [...folder.files]..sort((a, b) => a.name.compareTo(b.name));
    for (final file in files) {
      if (!file.name.toLowerCase().endsWith('.csv')) {
        warnings.add(
          '${file.name}: skipped; only sensor and label CSVs are supported.',
        );
        continue;
      }
      final csv = _CsvFile.parse(file.name, await load(file));
      if (file.name.startsWith('Label_')) {
        labelFiles.add(csv);
        continue;
      }
      if (csv.rows.isEmpty) {
        warnings.add('${file.name}: skipped; no sensor samples.');
        continue;
      }
      final names = [
        for (final axis in csv.columns.skip(1)) '${csv.stem}_$axis',
      ];
      for (final channel in names) {
        if (!channels.add(channel)) {
          throw FormatException(
            'Duplicate channel name: $channel. Rename the source files.',
          );
        }
      }
      int? previous;
      int? previousRaw;
      var sharedMilliseconds = 0;
      bool? microseconds;
      for (final row in csv.rows) {
        final raw = _timestamp(row.first, file.name);
        final isMicroseconds = raw >= 100000000000000;
        if (microseconds != null && microseconds != isMicroseconds) {
          throw FormatException('${file.name}: mixed timestamp units.');
        }
        microseconds = isMicroseconds;
        final time = isMicroseconds ? raw ~/ 1000 : raw;
        if (previousRaw != null && raw < previousRaw) {
          throw FormatException(
            '${file.name}: sensor timestamps are out of order.',
          );
        }
        if (previous == time) sharedMilliseconds++;
        previousRaw = raw;
        previous = time;
        first = first == null || time < first ? time : first;
        last = last == null || time > last ? time : last;
        for (var i = 0; i < names.length; i++) {
          final value = double.tryParse(row[i + 1]);
          if (value == null || !value.isFinite) {
            throw FormatException(
              '${file.name}: invalid value for ${csv.columns[i + 1]}.',
            );
          }
          recording.add(names[i], value, timestamp: time);
        }
      }
      if (sharedMilliseconds > 0) {
        warnings.add(
          '${file.name}: $sharedMilliseconds additional sample rows share '
          'millisecond timestamps. All values are retained; timestamps are '
          'limited to Edge ML’s millisecond precision.',
        );
      }
    }
    if (first == null || last == null) {
      throw const FormatException('This recording contains no sensor samples.');
    }
    final groups = <String>{};
    for (final csv in labelFiles) {
      final group = csv.stem.substring('Label_'.length);
      if (group.isEmpty || !groups.add(group)) {
        throw FormatException('${csv.name}: empty or duplicate label group.');
      }
      _addLabels(recording, csv, group, first, last, warnings);
    }
    warnings.add(
      'These CSVs do not store sensor units or configured sampling rates. '
      'Units and quantities were left unspecified; sample timestamps were preserved '
      'at millisecond precision.',
    );
    return EdgeMlRecordingImport(
      recording: recording,
      channelNames: List.unmodifiable(channels),
      warnings: List.unmodifiable(warnings),
      firstTimestampMs: first,
      lastTimestampMs: last,
    );
  }

  void _addLabels(
    DatasetRecording recording,
    _CsvFile csv,
    String group,
    int first,
    int last,
    List<String> warnings,
  ) {
    // Last state wins when several changes have the same millisecond timestamp.
    final events = <int, String?>{};
    int? previous;
    for (final row in csv.rows) {
      final time = _timestamp(row.first, csv.name);
      if (time >= 100000000000000) {
        throw FormatException(
          '${csv.name}: label timestamps must be Unix milliseconds.',
        );
      }
      if (previous != null && time < previous) {
        throw FormatException(
          '${csv.name}: label timestamps are out of order.',
        );
      }
      previous = time;
      String? active;
      for (var i = 1; i < row.length; i++) {
        if (row[i] != 'true' && row[i] != 'false') {
          throw FormatException(
            '${csv.name}: label states must be true or false.',
          );
        }
        if (row[i] == 'true') {
          if (active != null) {
            throw FormatException(
              '${csv.name}: multiple active labels in group $group.',
            );
          }
          active = csv.columns[i];
        }
      }
      events[time] = active;
    }
    final times = events.keys.toList();
    for (var i = 0; i < times.length; i++) {
      final active = events[times[i]];
      if (active == null) continue;
      final start = times[i] < first ? first : times[i];
      final nextEnd = i + 1 < times.length ? times[i + 1] - 1 : last;
      final end = nextEnd > last ? last : nextEnd;
      if (start <= end) {
        recording.addLabel(DatasetLabel(group, active, start: start, end: end));
      }
    }
    if (csv.rows.isEmpty) {
      warnings.add(
        '${csv.name}: contains label names but no recorded label states.',
      );
    } else if (times.any((t) => t < first || t > last)) {
      warnings.add(
        '${csv.name}: label ranges were clipped to the sensor recording bounds.',
      );
    }
  }
}

int _timestamp(String text, String file) {
  final value = int.tryParse(text);
  // Current app recordings use absolute Unix timestamps, not relative ticks.
  if (value == null || value < 100000000000 || value >= 100000000000000000) {
    throw FormatException(
      '$file: unsupported timestamp "$text". '
      'Expected Unix milliseconds or microseconds.',
    );
  }
  return value;
}

class _CsvFile {
  const _CsvFile(this.name, this.columns, this.rows);

  final String name;
  final List<String> columns;
  final List<List<String>> rows;
  String get stem => name.substring(0, name.length - 4);

  // Matches the recorder's unquoted, comma-separated output. The recorder does
  // not escape commas or newlines in axis/label names; malformed rows fail here.
  factory _CsvFile.parse(String name, String text) {
    final lines = const LineSplitter().convert(text.replaceFirst('\uFEFF', ''));
    if (lines.isEmpty) throw FormatException('$name: empty CSV file.');
    final columns = lines.first.split(',').map((s) => s.trim()).toList();
    if (columns.length < 2 ||
        columns.first != 'timestamp' ||
        columns.any((s) => s.isEmpty) ||
        columns.toSet().length != columns.length) {
      throw FormatException('$name: invalid CSV header.');
    }
    final rows = <List<String>>[];
    for (var i = 1; i < lines.length; i++) {
      if (lines[i].trim().isEmpty) continue;
      final row = lines[i].split(',').map((s) => s.trim()).toList();
      if (row.length != columns.length) {
        throw FormatException('$name: wrong column count on line ${i + 1}.');
      }
      rows.add(row);
    }
    return _CsvFile(name, columns, rows);
  }
}
