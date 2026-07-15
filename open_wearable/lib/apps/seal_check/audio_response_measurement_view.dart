import 'dart:convert';
import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart';
import 'package:open_wearable/apps/seal_check/audio_response_measurement_session.dart';
import 'package:open_wearable/apps/seal_check/seal_check_quality.dart';

// NOTE: We intentionally do NOT support writing files on web here.
// If you want web downloads, we can add a proper conditional import helper.
// ignore: avoid_web_libraries_in_flutter
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

// Target curve constants mirrored from firmware seal_check_service.c
final List<double> _kTargetFrequencies = audioResponseRequestFrequencies
    .map((frequency) => frequency.toDouble())
    .toList(
      growable: false,
    );
const List<double> _kTargetMagnitudes = sealCheckTargetMagnitudes;

/// Returns the index in [_kTargetFrequencies] closest to [freqHz] on a log scale.
int _closestTargetIndex(double freqHz) {
  int best = 0;
  double bestDist = double.infinity;
  final logF = math.log(freqHz);
  for (int i = 0; i < _kTargetFrequencies.length; i++) {
    final dist = (logF - math.log(_kTargetFrequencies[i])).abs();
    if (dist < bestDist) {
      bestDist = dist;
      best = i;
    }
  }
  return best;
}

/// Measures and visualizes seal-check results from one or two wearables.
class SealCheckMeasurementView extends StatefulWidget {
  /// Creates a seal-check measurement view.
  const SealCheckMeasurementView({
    super.key,
    this.left,
    this.right,
    this.title = 'Seal Check',
  }) : assert(
          left != null || right != null,
          'At least one of left or right must be provided',
        );

  final AudioResponseManager? left;
  final AudioResponseManager? right;

  /// Title displayed in the app bar.
  final String title;

  @override
  State<SealCheckMeasurementView> createState() =>
      _SealCheckMeasurementViewState();
}

class _SealCheckMeasurementViewState extends State<SealCheckMeasurementView> {
  bool _isMeasuring = false;
  Object? _error;
  StackTrace? _stack;
  AudioResponseMeasurement? _leftResult;
  AudioResponseMeasurement? _rightResult;
  AudioResponseMeasurementProgress? _progress;
  bool _showRawValues = false;
  late final AudioResponseMeasurementSession _session;

  bool get _hasBothSides => widget.left != null && widget.right != null;
  bool get _hasAnyResult => _leftResult != null || _rightResult != null;

  @override
  void initState() {
    super.initState();
    _session = AudioResponseMeasurementSession(
      left: widget.left,
      right: widget.right,
    );
  }

  String _two(int v) => v.toString().padLeft(2, '0');

  String _timestampForFilename(DateTime dt) {
    // yyyyMMdd_HHmmss
    return '${dt.year}${_two(dt.month)}${_two(dt.day)}_${_two(dt.hour)}${_two(dt.minute)}${_two(dt.second)}';
  }

  Future<String?> _saveResultToDownloadsAsJson(
    Map<String, dynamic> result,
  ) async {
    if (kIsWeb) return null;

    final now = DateTime.now();
    final fileName = 'seal_check_${_timestampForFilename(now)}.json';

    if (Platform.isAndroid) {
      final dirPath = await FilePicker.getDirectoryPath();
      if (dirPath == null || dirPath.isEmpty) return null;
      final String path = p.join(dirPath, fileName);
      await File(path).writeAsString(
        const JsonEncoder.withIndent('  ').convert(result),
        flush: true,
      );
      return path;
    }

    Directory? downloads;
    try {
      downloads = await getDownloadsDirectory();
    } catch (_) {
      downloads = null;
    }
    final dir = downloads ?? await getApplicationDocumentsDirectory();
    final String path = p.join(dir.path, fileName);
    await File(path).writeAsString(
      const JsonEncoder.withIndent('  ').convert(result),
      flush: true,
    );
    return path;
  }

  Future<void> _startMeasurement() async {
    setState(() {
      _isMeasuring = true;
      _error = null;
      _stack = null;
      _leftResult = null;
      _rightResult = null;
      _progress = null;
    });

    try {
      final results = await _session.measure(onProgress: _handleProgress);
      if (!mounted) return;

      setState(() {
        _leftResult = results.left;
        _rightResult = results.right;
        _isMeasuring = false;
        _progress = null;
      });
    } catch (e, st) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _stack = st;
        _isMeasuring = false;
        _progress = null;
      });
    }
  }

  void _handleProgress(AudioResponseMeasurementProgress progress) {
    if (!mounted) return;
    setState(() {
      _progress = progress;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PlatformScaffold(
      appBar: PlatformAppBar(
        title: Text(widget.title),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
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
                    onPressed: (_isMeasuring || !_hasAnyResult)
                        ? null
                        : () async {
                            final combined = {
                              if (_leftResult != null)
                                'left': _leftResult!.toJson(),
                              if (_rightResult != null)
                                'right': _rightResult!.toJson(),
                            };
                            final path =
                                await _saveResultToDownloadsAsJson(combined);
                            final msg = path == null
                                ? 'Not saved — either not supported or you canceled.'
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
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _isMeasuring
                  ? _buildLoading(theme)
                  : (_error != null)
                      ? _buildError(theme)
                      : _hasAnyResult
                          ? _buildResult(theme)
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
    final progress = _progress;
    final isUploading =
        progress?.phase == AudioResponseMeasurementPhase.uploadingTone;
    final uploadFraction = progress?.uploadFraction;
    final progressLabel = isUploading && uploadFraction != null
        ? '${(uploadFraction * 100).round()}%'
        : null;
    final statusText = switch (progress?.phase) {
      AudioResponseMeasurementPhase.uploadingTone => progress?.totalUploads == 1
          ? 'Uploading seal-check tone…'
          : 'Uploading seal-check tones…',
      AudioResponseMeasurementPhase.measuringResponse =>
        _hasBothSides ? 'Measuring left + right…' : 'Running seal check…',
      null => 'Preparing seal check…',
    };

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            LinearProgressIndicator(
              value: isUploading ? uploadFraction : null,
            ),
            const SizedBox(height: 16),
            Text(
              statusText,
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            if (progressLabel != null) ...[
              const SizedBox(height: 8),
              Text(
                progressLabel,
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ],
        ),
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
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.hintColor),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildResult(ThemeData theme) {
    List<AudioResponsePoint> sortedPoints(AudioResponseMeasurement? result) {
      final points = result?.points
              .where(
                (point) => point.frequencyHz > 0 && point.magnitude > 0,
              )
              .toList(growable: false) ??
          [];
      points.sort((a, b) => a.frequencyHz.compareTo(b.frequencyHz));
      return points;
    }

    final leftPoints = sortedPoints(_leftResult);
    final rightPoints = sortedPoints(_rightResult);

    // Compute a shared normalization factor (avg of all measured magnitudes)
    final allMags = [
      ...leftPoints.map((point) => point.magnitude),
      ...rightPoints.map((point) => point.magnitude),
    ];
    final normMag = allMags.isEmpty
        ? 1.0
        : allMags.reduce((a, b) => a + b) / allMags.length;

    final leftQuality =
        leftPoints.isNotEmpty ? computeSealCheckQuality(leftPoints) : null;
    final rightQuality =
        rightPoints.isNotEmpty ? computeSealCheckQuality(rightPoints) : null;

    return SingleChildScrollView(
      child: Column(
        children: [
          // Summary cards
          Row(
            children: [
              if (leftQuality != null) ...[
                Expanded(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            'Left Quality',
                            style: theme.textTheme.labelMedium,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${leftQuality.round()} / 100',
                            style: theme.textTheme.titleLarge,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (rightQuality != null) const SizedBox(width: 8),
              ],
              if (rightQuality != null)
                Expanded(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            'Right Quality',
                            style: theme.textTheme.labelMedium,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${rightQuality.round()} / 100',
                            style: theme.textTheme.titleLarge,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 320,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
                child: _buildChart(theme, leftPoints, rightPoints, normMag),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => setState(() => _showRawValues = !_showRawValues),
              icon:
                  Icon(_showRawValues ? Icons.expand_less : Icons.expand_more),
              label: Text(
                _showRawValues ? 'Hide raw values' : 'View raw values',
              ),
            ),
          ),
          if (_showRawValues) ...[
            const SizedBox(height: 8),
            _buildRawValuesTabs(theme, leftPoints, rightPoints, normMag),
          ],
        ],
      ),
    );
  }

  Widget _buildChart(
    ThemeData theme,
    List<AudioResponsePoint> leftPoints,
    List<AudioResponsePoint> rightPoints,
    double normMag,
  ) {
    final colorScheme = theme.colorScheme;
    const leftColor = Colors.blue;
    final rightColor = colorScheme.error;
    final targetColor = colorScheme.tertiary;

    // Convert to dB: 20 * log10(mag / normMag)
    double toDb(double mag) => 20.0 * math.log(mag / normMag) / math.ln10;

    // Use frequency INDEX (0–8) as X so fl_chart tick placement is trivial.
    // Each index corresponds to _kTargetFrequencies[index].
    List<FlSpot> toSpots(List<AudioResponsePoint> pts) {
      final spots = <FlSpot>[];
      for (final point in pts) {
        final freq = point.frequencyHz;
        if (freq <= 0) continue;
        spots.add(
          FlSpot(
            _closestTargetIndex(freq).toDouble(),
            toDb(point.magnitude),
          ),
        );
      }
      return spots;
    }

    final leftSpots = toSpots(leftPoints);
    final rightSpots = toSpots(rightPoints);

    // Target spots at integer indices; dB re 1.0
    final targetSpots = List.generate(_kTargetFrequencies.length, (i) {
      return FlSpot(
        i.toDouble(),
        20.0 * math.log(_kTargetMagnitudes[i]) / math.ln10,
      );
    });

    final allYValues = [
      ...leftSpots.map((s) => s.y),
      ...rightSpots.map((s) => s.y),
      ...targetSpots.map((s) => s.y),
    ];
    final rawMin = allYValues.isEmpty ? -10.0 : allYValues.reduce(math.min);
    final rawMax = allYValues.isEmpty ? 6.0 : allYValues.reduce(math.max);
    final yMin = ((rawMin - 3).floorToDouble()).clamp(-30.0, -3.0);
    final yMax = ((rawMax + 3).ceilToDouble()).clamp(3.0, 15.0);

    final lineBars = <LineChartBarData>[
      // Target (dashed)
      LineChartBarData(
        spots: targetSpots,
        color: targetColor,
        barWidth: 2,
        dotData: FlDotData(
          show: true,
          getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(
            radius: 3,
            color: targetColor,
            strokeWidth: 0,
            strokeColor: Colors.transparent,
          ),
        ),
        dashArray: [6, 4],
        isCurved: true,
        curveSmoothness: 0.2,
        belowBarData: BarAreaData(show: false),
      ),
      // Left
      if (leftSpots.isNotEmpty)
        LineChartBarData(
          spots: leftSpots,
          color: leftColor,
          barWidth: 2.5,
          dotData: FlDotData(
            show: true,
            getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(
              radius: 4,
              color: leftColor,
              strokeWidth: 0,
              strokeColor: Colors.transparent,
            ),
          ),
          isCurved: true,
          curveSmoothness: 0.2,
          belowBarData: BarAreaData(show: false),
        ),
      // Right
      if (rightSpots.isNotEmpty)
        LineChartBarData(
          spots: rightSpots,
          color: rightColor,
          barWidth: 2.5,
          dotData: FlDotData(
            show: true,
            getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(
              radius: 4,
              color: rightColor,
              strokeWidth: 0,
              strokeColor: Colors.transparent,
            ),
          ),
          isCurved: true,
          curveSmoothness: 0.2,
          belowBarData: BarAreaData(show: false),
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Legend
        Wrap(
          spacing: 16,
          children: [
            if (leftSpots.isNotEmpty) _legendDot(leftColor, 'Left'),
            if (rightSpots.isNotEmpty) _legendDot(rightColor, 'Right'),
            _legendDash(targetColor, 'Target'),
          ],
        ),
        const SizedBox(height: 8),
        Expanded(
          child: LineChart(
            LineChartData(
              minX: -0.5,
              maxX: 8.5,
              minY: yMin,
              maxY: yMax,
              clipData: const FlClipData.all(),
              lineBarsData: lineBars,
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  axisNameWidget: Text(
                    'Magnitude (dB)',
                    style: theme.textTheme.labelSmall,
                  ),
                  axisNameSize: 16,
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 52,
                    interval: 3,
                    getTitlesWidget: (value, meta) => SideTitleWidget(
                      meta: meta,
                      child: Text(
                        '${value.toStringAsFixed(0)} dB',
                        style: theme.textTheme.labelSmall,
                      ),
                    ),
                  ),
                ),
                bottomTitles: AxisTitles(
                  axisNameWidget: Text(
                    'Frequency (Hz)',
                    style: theme.textTheme.labelSmall,
                  ),
                  axisNameSize: 16,
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 48,
                    interval: 1.0,
                    getTitlesWidget: (value, meta) {
                      final idx = value.round();
                      if ((value - idx).abs() > 0.01 ||
                          idx < 0 ||
                          idx >= _kTargetFrequencies.length) {
                        return const SizedBox.shrink();
                      }
                      final freq = _kTargetFrequencies[idx];
                      final label = freq >= 1000
                          ? '${(freq / 1000).toStringAsFixed(1)}k'
                          : freq.toStringAsFixed(0);
                      return SideTitleWidget(
                        meta: meta,
                        angle: -math.pi / 3,
                        child: Text(
                          label,
                          style: theme.textTheme.labelSmall,
                        ),
                      );
                    },
                  ),
                ),
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
              ),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: true,
                getDrawingVerticalLine: (value) => FlLine(
                  color: theme.dividerColor.withAlpha(80),
                  strokeWidth: 0.8,
                ),
                getDrawingHorizontalLine: (value) => FlLine(
                  color: theme.dividerColor.withAlpha(80),
                  strokeWidth: 0.8,
                ),
                verticalInterval: 1.0,
                checkToShowVerticalLine: (value) {
                  final idx = value.round();
                  return (value - idx).abs() < 0.01 &&
                      idx >= 0 &&
                      idx < _kTargetFrequencies.length;
                },
              ),
              borderData: FlBorderData(
                show: true,
                border: Border(
                  bottom: BorderSide(color: theme.dividerColor),
                  left: BorderSide(color: theme.dividerColor),
                ),
              ),
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  getTooltipColor: (_) => Colors.grey.shade300,
                  getTooltipItems: (touchedSpots) {
                    return touchedSpots.map((s) {
                      final idx =
                          s.x.round().clamp(0, _kTargetFrequencies.length - 1);
                      final freq = _kTargetFrequencies[idx];
                      final Color c;
                      final String sideLabel;
                      if (s.barIndex == 0) {
                        c = targetColor;
                        sideLabel = 'Target';
                      } else if (leftSpots.isNotEmpty && s.barIndex == 1) {
                        c = leftColor;
                        sideLabel = 'Left';
                      } else {
                        c = rightColor;
                        sideLabel = 'Right';
                      }
                      return LineTooltipItem(
                        '$sideLabel\n${freq.toStringAsFixed(1)} Hz\n${s.y.toStringAsFixed(1)} dB',
                        TextStyle(color: c, fontSize: 12),
                      );
                    }).toList();
                  },
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRawValuesTabs(
    ThemeData theme,
    List<AudioResponsePoint> leftPoints,
    List<AudioResponsePoint> rightPoints,
    double normMag,
  ) {
    final tabs = <({String label, List<AudioResponsePoint> points})>[];
    if (leftPoints.isNotEmpty) tabs.add((label: 'Left', points: leftPoints));
    if (rightPoints.isNotEmpty) tabs.add((label: 'Right', points: rightPoints));
    if (tabs.isEmpty) return const SizedBox.shrink();

    // Single side: show table directly without tabs
    if (tabs.length == 1) {
      return SizedBox(
        height: 300,
        child: _buildRawValuesTable(
          theme,
          tabs.first.points,
          normMag,
          label: tabs.first.label,
        ),
      );
    }

    return SizedBox(
      height: 300,
      child: DefaultTabController(
        length: tabs.length,
        child: Card(
          child: Column(
            children: [
              TabBar(
                tabs: tabs.map((t) => Tab(text: t.label)).toList(),
              ),
              Expanded(
                child: TabBarView(
                  children: tabs
                      .map(
                        (t) => SingleChildScrollView(
                          child: _buildRawValuesTable(
                            theme,
                            t.points,
                            normMag,
                            label: t.label,
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRawValuesTable(
    ThemeData theme,
    List<AudioResponsePoint> points,
    double normMag, {
    String label = '',
  }) {
    if (points.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(8),
        child: Text('No data points.'),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                label.isEmpty ? 'Raw values' : 'Raw values — $label',
                style: theme.textTheme.titleMedium,
              ),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columnSpacing: 16,
                headingRowHeight: 32,
                dataRowMinHeight: 28,
                dataRowMaxHeight: 36,
                columns: const [
                  DataColumn(label: Text('Freq (Hz)')),
                  DataColumn(label: Text('Magnitude'), numeric: true),
                  DataColumn(label: Text('dB'), numeric: true),
                  DataColumn(label: Text('Target Freq (Hz)')),
                  DataColumn(label: Text('Target (dB)'), numeric: true),
                ],
                rows: points.map((point) {
                  final freq = point.frequencyHz;
                  final mag = point.magnitude;
                  final db = 20.0 * math.log(mag / normMag) / math.ln10;
                  final tIdx = _closestTargetIndex(freq);
                  final tFreq = _kTargetFrequencies[tIdx];
                  final tDb =
                      20.0 * math.log(_kTargetMagnitudes[tIdx]) / math.ln10;

                  return DataRow(
                    cells: [
                      DataCell(Text(freq.toStringAsFixed(2))),
                      DataCell(Text(mag.toStringAsFixed(0))),
                      DataCell(Text('${db.toStringAsFixed(1)} dB')),
                      DataCell(Text(tFreq.toStringAsFixed(3))),
                      DataCell(Text('${tDb.toStringAsFixed(1)} dB')),
                    ],
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  Widget _legendDash(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 20,
          height: 2,
          child: CustomPaint(
            painter: _DashPainter(color: color),
          ),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}

class _DashPainter extends CustomPainter {
  final Color color;
  const _DashPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2;
    const dashWidth = 5.0;
    const gap = 3.0;
    double x = 0;
    while (x < size.width) {
      canvas.drawLine(
        Offset(x, size.height / 2),
        Offset((x + dashWidth).clamp(0, size.width), size.height / 2),
        paint,
      );
      x += dashWidth + gap;
    }
  }

  @override
  bool shouldRepaint(_DashPainter old) => old.color != color;
}
