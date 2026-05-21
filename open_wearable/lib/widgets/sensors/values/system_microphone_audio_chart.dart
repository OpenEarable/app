import 'dart:io';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart';
import 'package:open_wearable/models/device_name_formatter.dart';
import 'package:open_wearable/models/wearable_display_group.dart';
import 'package:open_wearable/view_models/sensor_recorder_provider_facade.dart';
import 'package:provider/provider.dart';

/// Displays the Android system microphone level and source metadata.
///
/// The widget keeps recorder-driven rebuilds local to the audio card so
/// frequent amplitude samples do not rebuild the surrounding sensor page.
class SystemMicrophoneAudioChart extends StatefulWidget {
  final List<WearableDisplayGroup> groups;

  const SystemMicrophoneAudioChart({
    super.key,
    required this.groups,
  });

  /// Whether the current platform can render the system microphone chart.
  static bool get isSupported => !kIsWeb && Platform.isAndroid;

  @override
  State<SystemMicrophoneAudioChart> createState() =>
      _SystemMicrophoneAudioChartState();
}

class _SystemMicrophoneAudioChartState
    extends State<SystemMicrophoneAudioChart> {
  static const Duration _microphoneSourcesRefreshInterval =
      Duration(seconds: 5);

  Future<List<_AudioMicrophoneSourceInfo>>? _microphoneSourcesFuture;
  String? _microphoneSourcesCacheKey;
  DateTime? _microphoneSourcesLastRefresh;

  @override
  Widget build(BuildContext context) {
    return Selector<SensorRecorderProvider, _AudioRecorderMetadata>(
      selector: (context, recorderProvider) => _AudioRecorderMetadata(
        selectedInputLabel: recorderProvider.appliedAudioInputSource?.label,
        microphoneConfigurationRevision:
            recorderProvider.microphoneConfigurationRevision,
      ),
      builder: (context, metadata, child) {
        final audioHeaderInfo = _resolveHeaderInfo(
          groups: widget.groups,
          selectedInputLabel: metadata.selectedInputLabel,
        );
        final microphoneSourcesFuture = _microphoneSourcesFutureFor(
          widget.groups,
          microphoneConfigurationRevision:
              metadata.microphoneConfigurationRevision,
        );
        final hasHeaderMeta = audioHeaderInfo.deviceName != null ||
            audioHeaderInfo.stereoBadgeLabel != null;

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(10.0),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: PlatformText(
                        'SYSTEM MICROPHONE',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ),
                    if (hasHeaderMeta) ...[
                      const SizedBox(width: 8),
                      Flexible(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            if (audioHeaderInfo.deviceName != null)
                              Flexible(
                                child: PlatformText(
                                  audioHeaderInfo.deviceName!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.right,
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              ),
                            if (audioHeaderInfo.stereoBadgeLabel != null) ...[
                              const SizedBox(width: 8),
                              _AudioStereoBadge(
                                label: audioHeaderInfo.stereoBadgeLabel!,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 200,
                  child: Selector<SensorRecorderProvider, List<double>>(
                    selector: (context, recorderProvider) =>
                        recorderProvider.waveformData,
                    builder: (context, waveformData, child) => _AudioLevelChart(
                      waveformData: waveformData,
                      microphoneSourcesFuture: microphoneSourcesFuture,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  _AudioHeaderInfo _resolveHeaderInfo({
    required List<WearableDisplayGroup> groups,
    required String? selectedInputLabel,
  }) {
    final stereoBadgeLabel = _resolveStereoBadgeLabel(groups);
    final selectedInputName =
        _formatAudioDeviceName(selectedInputLabel, allowGeneric: false);
    if (selectedInputName != null) {
      return _AudioHeaderInfo(
        deviceName: selectedInputName,
        stereoBadgeLabel: stereoBadgeLabel,
      );
    }

    if (groups.isEmpty) {
      return _AudioHeaderInfo(
        deviceName: null,
        stereoBadgeLabel: stereoBadgeLabel,
      );
    }

    WearableDisplayGroup? combinedGroup;
    for (final group in groups) {
      if (group.isCombined) {
        combinedGroup = group;
        break;
      }
    }
    final displayName = combinedGroup?.displayName ?? groups.first.displayName;
    return _AudioHeaderInfo(
      deviceName: _formatAudioDeviceName(displayName, allowGeneric: true),
      stereoBadgeLabel: stereoBadgeLabel,
    );
  }

  String? _resolveStereoBadgeLabel(List<WearableDisplayGroup> groups) {
    if (groups.any((group) => group.isCombined)) {
      return 'L+R';
    }

    final sidesByPairKey = <String, Set<DevicePosition>>{};
    DevicePosition? singleKnownSide;
    for (final group in groups) {
      if (group.primaryPosition != null) {
        singleKnownSide ??= group.primaryPosition;
      }
      final pairKey = group.stereoPairKey;
      final position = group.primaryPosition;
      if (pairKey == null || position == null) {
        continue;
      }
      sidesByPairKey.putIfAbsent(pairKey, () => <DevicePosition>{}).add(
            position,
          );
    }

    final hasConnectedPair = sidesByPairKey.values.any(
      (positions) =>
          positions.contains(DevicePosition.left) &&
          positions.contains(DevicePosition.right),
    );
    if (hasConnectedPair) {
      return 'L+R';
    }

    return switch (singleKnownSide) {
      DevicePosition.left => 'L',
      DevicePosition.right => 'R',
      _ => null,
    };
  }

  String? _formatAudioDeviceName(
    String? rawName, {
    required bool allowGeneric,
  }) {
    final trimmed = rawName?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }

    final lower = trimmed.toLowerCase();
    if (!allowGeneric &&
        (lower == 'bluetooth' ||
            lower.contains('bluetooth sco') ||
            lower.contains('default'))) {
      return null;
    }

    final formatted = formatWearableDisplayName(trimmed);
    final withoutSideSuffix = formatted
        .replaceFirst(
          RegExp(r'\s*\((left|right|l|r)\)$', caseSensitive: false),
          '',
        )
        .replaceFirst(
          RegExp(r'[\s_-]+(left|right|l|r)$', caseSensitive: false),
          '',
        )
        .trim();

    return withoutSideSuffix.isEmpty ? formatted : withoutSideSuffix;
  }

  Future<List<_AudioMicrophoneSourceInfo>> _resolveMicrophoneSources(
    List<WearableDisplayGroup> groups,
  ) async {
    final futures = <Future<_AudioMicrophoneSourceInfo?>>[];
    final seenDeviceIds = <String>{};

    void addCandidate(Wearable? wearable, DevicePosition? position) {
      if (wearable == null || !seenDeviceIds.add(wearable.deviceId)) {
        return;
      }
      futures.add(
        _resolveMicrophoneSource(
          wearable: wearable,
          position: position,
        ),
      );
    }

    for (final group in groups) {
      final leftDevice = group.leftDevice;
      final rightDevice = group.rightDevice;
      addCandidate(leftDevice, DevicePosition.left);
      addCandidate(rightDevice, DevicePosition.right);
      if (leftDevice == null && rightDevice == null) {
        addCandidate(group.primary, group.primaryPosition);
      }
    }

    final resolvedSources = await Future.wait(futures);
    final sources = resolvedSources
        .whereType<_AudioMicrophoneSourceInfo>()
        .toList(growable: false);
    return sources..sort(_compareMicrophoneSources);
  }

  /// Returns a cached source lookup future for stable group and mic settings.
  Future<List<_AudioMicrophoneSourceInfo>> _microphoneSourcesFutureFor(
    List<WearableDisplayGroup> groups, {
    required int microphoneConfigurationRevision,
  }) {
    final cacheKey =
        '${_microphoneSourcesKey(groups)}#$microphoneConfigurationRevision';
    final now = DateTime.now();
    final lastRefresh = _microphoneSourcesLastRefresh;
    final cacheExpired = lastRefresh == null ||
        now.difference(lastRefresh) > _microphoneSourcesRefreshInterval;

    if (_microphoneSourcesFuture == null ||
        _microphoneSourcesCacheKey != cacheKey ||
        cacheExpired) {
      _microphoneSourcesCacheKey = cacheKey;
      _microphoneSourcesLastRefresh = now;
      _microphoneSourcesFuture = _resolveMicrophoneSources(groups);
    }

    return _microphoneSourcesFuture!;
  }

  String _microphoneSourcesKey(List<WearableDisplayGroup> groups) {
    final parts = <String>[];
    for (final group in groups) {
      final leftDevice = group.leftDevice;
      final rightDevice = group.rightDevice;
      if (leftDevice != null) {
        parts.add('${leftDevice.deviceId}:left');
      }
      if (rightDevice != null) {
        parts.add('${rightDevice.deviceId}:right');
      }
      if (leftDevice == null && rightDevice == null) {
        parts.add(
          '${group.primary.deviceId}:${group.primaryPosition?.name ?? 'unknown'}',
        );
      }
    }
    return parts.join('|');
  }

  Future<_AudioMicrophoneSourceInfo?> _resolveMicrophoneSource({
    required Wearable wearable,
    required DevicePosition? position,
  }) async {
    if (!wearable.hasCapability<MicrophoneManager>()) {
      return null;
    }

    final resolvedPosition =
        position ?? await _readMicrophoneSourcePosition(wearable);
    final sideLabel = _microphoneSourceSideLabel(resolvedPosition);
    if (sideLabel == null) {
      return null;
    }

    try {
      final microphone =
          await wearable.requireCapability<MicrophoneManager>().getMicrophone();
      final microphoneLabel = _microphoneSourceLabel(microphone);
      if (microphoneLabel == null) {
        return null;
      }
      return _AudioMicrophoneSourceInfo(
        sideLabel: sideLabel,
        microphoneLabel: microphoneLabel,
      );
    } catch (_) {
      return null;
    }
  }

  Future<DevicePosition?> _readMicrophoneSourcePosition(
    Wearable wearable,
  ) async {
    if (!wearable.hasCapability<StereoDevice>()) {
      return null;
    }
    try {
      return await wearable.requireCapability<StereoDevice>().position;
    } catch (_) {
      return null;
    }
  }

  int _compareMicrophoneSources(
    _AudioMicrophoneSourceInfo a,
    _AudioMicrophoneSourceInfo b,
  ) {
    return _microphoneSourceSortRank(a.sideLabel)
        .compareTo(_microphoneSourceSortRank(b.sideLabel));
  }

  int _microphoneSourceSortRank(String sideLabel) {
    return switch (sideLabel) {
      'L' => 0,
      'R' => 1,
      _ => 2,
    };
  }

  String? _microphoneSourceSideLabel(DevicePosition? position) {
    return switch (position) {
      DevicePosition.left => 'L',
      DevicePosition.right => 'R',
      _ => null,
    };
  }

  String? _microphoneSourceLabel(Microphone microphone) {
    final normalized = microphone.key.toLowerCase().replaceAll(
          RegExp(r'[^a-z0-9]'),
          '',
        );
    if (normalized.contains('inner') || normalized.contains('internal')) {
      return 'Inner';
    }
    if (normalized.contains('outer') || normalized.contains('external')) {
      return 'Outer';
    }
    return null;
  }
}

class _AudioHeaderInfo {
  final String? deviceName;
  final String? stereoBadgeLabel;

  const _AudioHeaderInfo({
    required this.deviceName,
    required this.stereoBadgeLabel,
  });
}

/// Recorder values that affect audio metadata, excluding waveform samples.
class _AudioRecorderMetadata {
  final String? selectedInputLabel;
  final int microphoneConfigurationRevision;

  const _AudioRecorderMetadata({
    required this.selectedInputLabel,
    required this.microphoneConfigurationRevision,
  });

  @override
  bool operator ==(Object other) {
    return other is _AudioRecorderMetadata &&
        other.selectedInputLabel == selectedInputLabel &&
        other.microphoneConfigurationRevision ==
            microphoneConfigurationRevision;
  }

  @override
  int get hashCode => Object.hash(
        selectedInputLabel,
        microphoneConfigurationRevision,
      );
}

class _AudioMicrophoneSourceInfo {
  final String sideLabel;
  final String microphoneLabel;

  const _AudioMicrophoneSourceInfo({
    required this.sideLabel,
    required this.microphoneLabel,
  });

  String get label => '$microphoneLabel ($sideLabel)';
}

class _AudioStereoBadge extends StatelessWidget {
  final String label;

  const _AudioStereoBadge({
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: colorScheme.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: colorScheme.primary.withValues(alpha: 0.24),
        ),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: colorScheme.primary,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

class _AudioLevelChart extends StatelessWidget {
  static const double _sampleIntervalSeconds = 0.1;
  static const double _windowSeconds = 5;
  static const int _maxSamples = 51;
  static const double _maxAbsLevel = 100;

  final List<double> waveformData;
  final Future<List<_AudioMicrophoneSourceInfo>> microphoneSourcesFuture;

  const _AudioLevelChart({
    required this.waveformData,
    required this.microphoneSourcesFuture,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final bars = _buildBars(colorScheme.primary);

    final chartData = LineChartData(
      minX: -_windowSeconds,
      maxX: 0,
      minY: -_maxAbsLevel,
      maxY: _maxAbsLevel,
      lineTouchData: const LineTouchData(
        enabled: false,
        handleBuiltInTouches: false,
      ),
      gridData: FlGridData(
        show: true,
        drawVerticalLine: true,
        getDrawingHorizontalLine: (_) => FlLine(
          color: colorScheme.outline.withValues(alpha: 0.2),
          strokeWidth: 1,
        ),
        getDrawingVerticalLine: (_) => FlLine(
          color: colorScheme.outline.withValues(alpha: 0.2),
          strokeWidth: 1,
        ),
      ),
      titlesData: FlTitlesData(
        leftTitles: AxisTitles(
          axisNameWidget: PlatformText(
            '%',
            style: theme.textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          axisNameSize: 16,
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 34,
            minIncluded: false,
            maxIncluded: false,
            getTitlesWidget: (value, meta) {
              final isBoundaryTick = (value + _maxAbsLevel).abs() < 1e-6 ||
                  (value - _maxAbsLevel).abs() < 1e-6;
              if (isBoundaryTick) {
                return const SizedBox.shrink();
              }
              return SideTitleWidget(
                meta: meta,
                space: 6,
                child: SizedBox(
                  width: 30,
                  child: Text(
                    _formatYAxisTick(value),
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.fade,
                    textAlign: TextAlign.right,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        rightTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
        topTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
        bottomTitles: AxisTitles(
          axisNameSize: 0,
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 20,
            interval: 1,
            minIncluded: true,
            maxIncluded: true,
            getTitlesWidget: (value, meta) => SideTitleWidget(
              meta: meta,
              child: Text(
                _formatXAxisTick(value),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ),
      ),
      borderData: FlBorderData(
        show: true,
        border: Border(
          left: BorderSide(
            color: colorScheme.outline.withValues(alpha: 0.28),
          ),
          bottom: BorderSide(
            color: colorScheme.outline.withValues(alpha: 0.28),
          ),
        ),
      ),
      lineBarsData: bars,
    );

    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(2, 2, 2, 0),
            child: LineChart(
              chartData,
              duration: const Duration(milliseconds: 0),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: LayoutBuilder(
            builder: (context, constraints) => Row(
              children: [
                Expanded(
                  child: FutureBuilder<List<_AudioMicrophoneSourceInfo>>(
                    future: microphoneSourcesFuture,
                    builder: (context, snapshot) {
                      final sources = snapshot.data ?? const [];
                      if (sources.isEmpty) {
                        return const SizedBox.shrink();
                      }
                      final minChipWidth = constraints.maxWidth > 70
                          ? constraints.maxWidth - 70
                          : 0.0;
                      return SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minWidth: minChipWidth,
                          ),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: sources
                                  .map(
                                    (source) => Padding(
                                      padding: const EdgeInsets.only(right: 6),
                                      child: _AudioMicrophoneSourceChip(
                                        label: source.label,
                                      ),
                                    ),
                                  )
                                  .toList(growable: false),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Time (s)',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  List<LineChartBarData> _buildBars(Color color) {
    if (waveformData.isEmpty) {
      return const <LineChartBarData>[];
    }

    final startIndex = waveformData.length > _maxSamples
        ? waveformData.length - _maxSamples
        : 0;
    final visibleData = waveformData.sublist(startIndex);

    return visibleData.asMap().entries.map((entry) {
      final samplesFromNewest = visibleData.length - 1 - entry.key;
      final x = -samplesFromNewest * _sampleIntervalSeconds;
      final level = (entry.value * 100).clamp(0.0, _maxAbsLevel).toDouble();
      return LineChartBarData(
        spots: [
          FlSpot(x, -level),
          FlSpot(x, level),
        ],
        isCurved: false,
        barWidth: 3,
        color: color,
        isStrokeCapRound: true,
        dotData: const FlDotData(show: false),
        belowBarData: BarAreaData(show: false),
      );
    }).toList(growable: false);
  }

  String _formatXAxisTick(double value) {
    final rounded = value.roundToDouble();
    if ((value - rounded).abs() < 0.05) {
      return rounded.toInt().toString();
    }
    return value.toStringAsFixed(1);
  }

  String _formatYAxisTick(double value) {
    final abs = value.abs();
    if (abs >= 100) {
      return value.toStringAsFixed(0);
    }
    if (abs >= 1) {
      return value.toStringAsFixed(1).replaceFirst(RegExp(r'\.0$'), '');
    }
    return '0';
  }
}

class _AudioMicrophoneSourceChip extends StatelessWidget {
  final String label;

  const _AudioMicrophoneSourceChip({
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final axisColor = colorScheme.primary;

    return IgnorePointer(
      child: FilterChip(
        label: Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            color: axisColor.withValues(alpha: 0.95),
            fontWeight: FontWeight.w700,
            fontSize: 10.5,
          ),
        ),
        avatar: Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            color: axisColor,
            shape: BoxShape.circle,
          ),
        ),
        selected: true,
        onSelected: (_) {},
        showCheckmark: false,
        visualDensity: const VisualDensity(
          horizontal: -3,
          vertical: -3,
        ),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        labelPadding: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(horizontal: 4),
        selectedColor: axisColor.withValues(alpha: 0.18),
        backgroundColor: axisColor.withValues(alpha: 0.18),
        side: BorderSide(
          color: axisColor.withValues(alpha: 0.28),
        ),
      ),
    );
  }
}
