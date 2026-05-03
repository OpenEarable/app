import 'dart:convert';
import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
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

// Target curve constants mirrored from firmware seal_check_service.c
const List<double> _kTargetFrequencies = [
  40.0,
  60.0,
  90.0,
  135.0,
  202.5,
  303.75,
  455.625,
  683.4375,
  1025.15625,
];
const List<double> _kTargetMagnitudes = [
  0.90833731,
  1.18334124,
  1.38796968,
  1.16634027,
  0.85781358,
  0.65981396,
  0.84768657,
  0.98236069,
  1.00633671,
];

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

class AudioResponseMeasurementView extends StatefulWidget {
  const AudioResponseMeasurementView({
    super.key,
    this.left,
    this.right,
    this.parameters = const {},
    this.title = 'Audio Response',
  }) : assert(left != null || right != null,
            'At least one of left or right must be provided');

  final AudioResponseManager? left;
  final AudioResponseManager? right;

  /// Parameters passed to measureAudioResponse (can be empty)
  final Map<String, dynamic> parameters;

  final String title;

  @override
  State<AudioResponseMeasurementView> createState() =>
      _AudioResponseMeasurementViewState();
}

class _AudioResponseMeasurementViewState
    extends State<AudioResponseMeasurementView> {
  bool _isMeasuring = false;
  Object? _error;
  StackTrace? _stack;
  Map<String, dynamic>? _leftResult;
  Map<String, dynamic>? _rightResult;
  bool _showRawValues = false;

  bool get _hasBothSides => widget.left != null && widget.right != null;
  bool get _hasAnyResult => _leftResult != null || _rightResult != null;

  @override
  void initState() {
    super.initState();
  }

  String _two(int v) => v.toString().padLeft(2, '0');

  String _timestampForFilename(DateTime dt) {
    // yyyyMMdd_HHmmss
    return '${dt.year}${_two(dt.month)}${_two(dt.day)}_${_two(dt.hour)}${_two(dt.minute)}${_two(dt.second)}';
  }

  Future<String?> _saveResultToDownloadsAsJson(Map<String, dynamic> result) async {
    if (kIsWeb) return null;

    final now = DateTime.now();
    final fileName = 'audio_response_${_timestampForFilename(now)}.json';

    if (Platform.isAndroid) {
      final dirPath = await FilePicker.platform.getDirectoryPath();
      if (dirPath == null || dirPath.isEmpty) return null;
      final String path = p.join(dirPath, fileName);
      await File(path).writeAsString(
          const JsonEncoder.withIndent('  ').convert(result),
          flush: true);
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
        flush: true);
    return path;
  }

  Future<void> _startMeasurement() async {
    setState(() {
      _isMeasuring = true;
      _error = null;
      _stack = null;
      _leftResult = null;
      _rightResult = null;
    });

    try {
      // Run both sides in parallel
      final futures = <Future<(bool isLeft, Map<String, dynamic> res)>>[];
      if (widget.left != null) {
        futures.add(widget.left!
            .measureAudioResponse(widget.parameters)
            .then((r) => (true, r)));
      }
      if (widget.right != null) {
        futures.add(widget.right!
            .measureAudioResponse(widget.parameters)
            .then((r) => (false, r)));
      }

      final results = await Future.wait(futures);
      if (!mounted) return;

      Map<String, dynamic>? leftRes;
      Map<String, dynamic>? rightRes;
      for (final (isLeft, res) in results) {
        if (isLeft) {
          leftRes = res;
        } else {
          rightRes = res;
        }
      }

      setState(() {
        _leftResult = leftRes;
        _rightResult = rightRes;
        _isMeasuring = false;
      });
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
                  onPressed: (_isMeasuring || !_hasAnyResult)
                      ? null
                      : () async {
                          final combined = {
                            if (_leftResult != null) 'left': _leftResult!,
                            if (_rightResult != null) 'right': _rightResult!,
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
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(
            _hasBothSides
                ? 'Measuring left + right…'
                : 'Measuring frequency response…',
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

  Widget _buildResult(ThemeData theme) {
    List<Map<String, dynamic>> _parsePoints(Map<String, dynamic>? result) {
      if (result == null) return [];
      final pointsDyn = (result['points'] as List?) ?? const [];
      final pts = pointsDyn
          .whereType<Map>()
          .map((m) => {
                'frequency_hz': (m['frequency_hz'] as num?)?.toDouble(),
                'frequency_raw_q12_4': (m['frequency_raw_q12_4'] as num?)?.toInt(),
                'magnitude': (m['magnitude'] as num?)?.toDouble(),
              })
          .where((m) =>
              m['frequency_hz'] != null &&
              m['magnitude'] != null &&
              (m['frequency_hz'] as double) > 0.0)
          .cast<Map<String, dynamic>>()
          .toList();
      pts.sort((a, b) =>
          (a['frequency_hz'] as double).compareTo(b['frequency_hz'] as double));
      return pts;
    }

    final leftPoints = _parsePoints(_leftResult);
    final rightPoints = _parsePoints(_rightResult);

    // Compute a shared normalization factor (avg of all measured magnitudes)
    final allMags = [
      ...leftPoints.map((p) => p['magnitude'] as double),
      ...rightPoints.map((p) => p['magnitude'] as double),
    ];
    final normMag =
        allMags.isEmpty ? 1.0 : allMags.reduce((a, b) => a + b) / allMags.length;

    int _quality(Map<String, dynamic>? r) => (r?['quality'] as int?) ?? -1;
    double _meanMag(Map<String, dynamic>? r) =>
        (r?['mean_magnitude'] as double?) ?? -1;

    return Column(
      children: [
        // Summary card
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Wrap(
              runSpacing: 8,
              spacing: 24,
              children: [
                if (_leftResult != null) ...[
                  _kv(theme, 'Left Quality', '${_quality(_leftResult)} / 100'),
                  _kv(theme, 'Left Mean Mag',
                      _meanMag(_leftResult).toStringAsFixed(1)),
                ],
                if (_rightResult != null) ...[
                  _kv(theme, 'Right Quality',
                      '${_quality(_rightResult)} / 100'),
                  _kv(theme, 'Right Mean Mag',
                      _meanMag(_rightResult).toStringAsFixed(1)),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
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
            icon: Icon(_showRawValues ? Icons.expand_less : Icons.expand_more),
            label: Text(
                _showRawValues ? 'Hide raw values' : 'View raw values'),
          ),
        ),
        if (_showRawValues) ...[
          const SizedBox(height: 8),
          if (leftPoints.isNotEmpty)
            _buildRawValuesTable(theme, leftPoints, normMag, label: 'Left'),
          if (rightPoints.isNotEmpty)
            _buildRawValuesTable(theme, rightPoints, normMag, label: 'Right'),
        ],
      ],
    );
  }

  Widget _buildChart(
    ThemeData theme,
    List<Map<String, dynamic>> leftPoints,
    List<Map<String, dynamic>> rightPoints,
    double normMag,
  ) {
    final colorScheme = theme.colorScheme;
    final leftColor = colorScheme.primary;
    final rightColor = colorScheme.error;
    final targetColor = colorScheme.tertiary;

    List<FlSpot> _toSpots(List<Map<String, dynamic>> pts) => pts
        .map((p) => FlSpot(
              math.log(p['frequency_hz'] as double) / math.ln10,
              (p['magnitude'] as double) / normMag,
            ))
        .toList();

    final leftSpots = _toSpots(leftPoints);
    final rightSpots = _toSpots(rightPoints);

    // Target spots
    final targetSpots = List.generate(_kTargetFrequencies.length, (i) {
      return FlSpot(
        math.log(_kTargetFrequencies[i]) / math.ln10,
        _kTargetMagnitudes[i],
      );
    });

    final xTicks =
        _kTargetFrequencies.map((f) => math.log(f) / math.ln10).toList();

    final allYValues = [
      ...leftSpots.map((s) => s.y),
      ...rightSpots.map((s) => s.y),
      ..._kTargetMagnitudes,
    ];
    final maxY = allYValues.isEmpty ? 1.5 : allYValues.reduce(math.max);
    final yMax = (maxY * 1.2).clamp(1.5, 2.5);

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
              minX: xTicks.first - 0.05,
              maxX: xTicks.last + 0.05,
              minY: 0,
              maxY: yMax,
              clipData: const FlClipData.all(),
              lineBarsData: lineBars,
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  axisNameWidget: Text(
                    'Normalized magnitude',
                    style: theme.textTheme.labelSmall,
                  ),
                  axisNameSize: 16,
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 36,
                    interval: 0.5,
                    getTitlesWidget: (value, meta) => SideTitleWidget(
                      meta: meta,
                      child: Text(
                        value.toStringAsFixed(1),
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
                    reservedSize: 32,
                    getTitlesWidget: (value, meta) {
                      final matchIdx = xTicks
                          .indexWhere((x) => (x - value).abs() < 0.001);
                      if (matchIdx < 0) return const SizedBox.shrink();
                      final freq = _kTargetFrequencies[matchIdx];
                      final label = freq < 100
                          ? freq.toStringAsFixed(0)
                          : freq >= 1000
                              ? '${(freq / 1000).toStringAsFixed(1)}k'
                              : freq.toStringAsFixed(0);
                      return SideTitleWidget(
                        meta: meta,
                        angle: -0.5,
                        child: Text(label,
                            style: theme.textTheme.labelSmall),
                      );
                    },
                  ),
                ),
                topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
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
                verticalInterval: 0.01,
                checkToShowVerticalLine: (value) =>
                    xTicks.any((x) => (x - value).abs() < 0.001),
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
                  getTooltipItems: (touchedSpots) {
                    return touchedSpots.map((s) {
                      final freq = math.pow(10, s.x).toDouble();
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
                        '$sideLabel\n${freq.toStringAsFixed(1)} Hz\n${s.y.toStringAsFixed(3)}',
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

  Widget _buildRawValuesTable(
    ThemeData theme,
    List<Map<String, dynamic>> points,
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
                  DataColumn(label: Text('Norm. Mag'), numeric: true),
                  DataColumn(label: Text('Target Freq (Hz)')),
                  DataColumn(label: Text('Target Mag'), numeric: true),
                ],
                rows: points.map((point) {
                  final freq = point['frequency_hz']!;
                  final mag = point['magnitude']!;
                  final normM = mag / normMag;
                  final tIdx = _closestTargetIndex(freq);
                  final tFreq = _kTargetFrequencies[tIdx];
                  final tMag = _kTargetMagnitudes[tIdx];

                  return DataRow(cells: [
                    DataCell(Text(freq.toStringAsFixed(2))),
                    DataCell(Text(mag.toStringAsFixed(0))),
                    DataCell(Text(normM.toStringAsFixed(3))),
                    DataCell(Text(tFreq.toStringAsFixed(3))),
                    DataCell(Text(tMag.toStringAsFixed(5))),
                  ]);
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
