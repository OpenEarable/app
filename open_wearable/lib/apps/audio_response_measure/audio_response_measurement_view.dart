import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart';
import 'package:file_picker/file_picker.dart';

// NOTE: We intentionally do NOT support writing files on web here.
// If you want web downloads, we can add a proper conditional import helper.
// ignore: avoid_web_libraries_in_flutter
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class AudioResponseMeasurementView extends StatefulWidget {
  const AudioResponseMeasurementView({
    super.key,
    required this.manager,
    this.parameters = const {},
    this.title = 'Audio Response',
  });

  final AudioResponseManager manager;

  /// Parameters passed to measureAudioResponse (can be empty)
  final Map<String, dynamic> parameters;

  final String title;

  @override
  State<AudioResponseMeasurementView> createState() => _AudioResponseMeasurementViewState();
}

class _AudioResponseMeasurementViewState extends State<AudioResponseMeasurementView> {
  bool _isMeasuring = false;
  Object? _error;
  StackTrace? _stack;
  Map<String, dynamic>? _result;

  @override
  void initState() {
    super.initState();
    // Measurement is triggered by user button press.
  }

  String _two(int v) => v.toString().padLeft(2, '0');

  String _timestampForFilename(DateTime dt) {
    // yyyyMMdd_HHmmss
    return '${dt.year}${_two(dt.month)}${_two(dt.day)}_${_two(dt.hour)}${_two(dt.minute)}${_two(dt.second)}';
  }

  Future<String?> _saveResultToDownloadsAsJson(Map<String, dynamic> result) async {
    // Web: stub (no dart:html here; add conditional import helper if you want real downloads)
    if (kIsWeb) {
      return null;
    }

    final now = DateTime.now();
    final fileName = 'audio_response_${_timestampForFilename(now)}.json';

    // Android: let user pick a target directory.
    if (Platform.isAndroid) {
      final dirPath = await FilePicker.platform.getDirectoryPath();
      if (dirPath == null || dirPath.isEmpty) {
        // User canceled.
        return null;
      }
      final String path = p.join(dirPath, fileName);
      final encoder = const JsonEncoder.withIndent('  ');
      final jsonStr = encoder.convert(result);
      final file = File(path);
      await file.writeAsString(jsonStr, flush: true);
      return path;
    }

    // iOS: save to Downloads if possible (fallback to app docs).
    Directory? downloads;
    try {
      downloads = await getDownloadsDirectory();
    } catch (_) {
      downloads = null;
    }

    final Directory dir = downloads ?? await getApplicationDocumentsDirectory();
    final String path = p.join(dir.path, fileName);

    final encoder = const JsonEncoder.withIndent('  ');
    final jsonStr = encoder.convert(result);

    final file = File(path);
    await file.writeAsString(jsonStr, flush: true);
    return path;
  }

  Future<void> _startMeasurement() async {
    setState(() {
      _isMeasuring = true;
      _error = null;
      _stack = null;
      _result = null;
    });

    try {
      final res = await widget.manager.measureAudioResponse(widget.parameters);
      // final savedPath = await _saveResultToDownloadsAsJson(res);
      if (!mounted) return;
      setState(() {
        _result = res;
        _isMeasuring = false;
      });
      if (!context.mounted) return;
      // final msg = savedPath == null
      //     ? 'Measured. (Not saved — either not supported or you canceled folder selection.)'
      //     : 'Measured and saved to: $savedPath';
      // ScaffoldMessenger.of(context).showSnackBar(
      //   SnackBar(content: Text(msg)),
      // );
    } catch (e, st) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _stack = st;
        _isMeasuring = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PlatformScaffold(
      appBar: PlatformAppBar(
        title: Text(widget.title),
        trailingActions: [
          PlatformIconButton(
            onPressed: _isMeasuring ? null : _startMeasurement,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _isMeasuring ? null : _startMeasurement,
                    icon: const Icon(Icons.play_arrow),
                    label: Text(_isMeasuring ? 'Measuring…' : 'Measure'),
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: (_isMeasuring || _result == null)
                      ? null
                      : () async {
                          final path = await _saveResultToDownloadsAsJson(_result!);
                          final msg = path == null
                              ? 'Not saved — either not supported or you canceled folder selection.'
                              : 'Saved to: $path';
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(msg)),
                          );
                        },
                  icon: const Icon(Icons.download),
                  label: const Text('Save JSON'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _isMeasuring
                  ? _buildLoading(theme)
                  : (_error != null)
                      ? _buildError(theme)
                      : (_result != null)
                          ? _buildResult(theme, _result!)
                          : Center(
                              child: Text(
                                'Press “Measure” to start.',
                                style: theme.textTheme.titleMedium,
                              ),
                            ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoading(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(
            'Measuring frequency response…',
            style: theme.textTheme.titleMedium,
          ),
        ],
      ),
    );
  }

  Widget _buildError(ThemeData theme) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
            const SizedBox(height: 12),
            Text(
              'Measurement failed',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              _error.toString(),
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _startMeasurement,
              icon: const Icon(Icons.replay),
              label: const Text('Try again'),
            ),
            // If you want to show stack traces in debug builds:
            if (_stack != null)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text(
                  _stack.toString(),
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildResult(ThemeData theme, Map<String, dynamic> result) {
    final int version = (result['version'] as int?) ?? -1;
    final int quality = (result['quality'] as int?) ?? -1;

    final double meanMagnitude = (result['mean_magnitude'] as double?) ?? -1;
    final int numPeaks = (result['num_peaks'] as int?) ?? -1;

    final List<dynamic> pointsDyn = (result['points'] as List?) ?? const [];
    final points = pointsDyn
        .whereType<Map>()
        .map((m) => {
              'frequency_hz': (m['frequency_hz'] as num?)?.toDouble(),
              'frequency_raw_q12_4': (m['frequency_raw_q12_4'] as num?)?.toInt(),
              'magnitude': (m['magnitude'] as num?)?.toDouble(),
            },)
        .where((m) => m['frequency_hz'] != null && m['magnitude'] != null)
        .toList();

    // Sort by frequency (just in case)
    points.sort((a, b) => (a['frequency_hz']!).compareTo(b['frequency_hz']!));

    return ListView(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              runSpacing: 8,
              spacing: 16,
              children: [
                _kv(theme, 'Version', '$version'),
                _kv(theme, 'Quality', '$quality'),
                _kv(theme, 'Mean Magnitude', '$meanMagnitude'),
                _kv(theme, 'Points', '${points.length}'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text('Response points', style: theme.textTheme.titleMedium),
                ),
                const Divider(height: 1),
                ...points.map((p) {
                  final f = p['frequency_hz']!;
                  final mag = p['magnitude']!;
                  final raw = p['frequency_raw_q12_4'] as int?;

                  final subtitle = raw == null
                      ? 'magnitude (uint16 units)'
                      : 'freq raw (Q12.4): $raw • magnitude (uint16 units)';

                  return ListTile(
                    dense: true,
                    title: Text('${f.toStringAsFixed(2)} Hz'),
                    trailing: Text(mag.toStringAsFixed(0)),
                    subtitle: Text(subtitle),
                  );
                }),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _kv(ThemeData theme, String k, String v) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(k, style: theme.textTheme.labelMedium),
        Text(v, style: theme.textTheme.titleMedium),
      ],
    );
  }
}
