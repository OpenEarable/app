import 'dart:io';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart';
import 'package:open_wearable/models/app_shutdown_settings.dart';
import 'package:open_wearable/models/device_name_formatter.dart';
import 'package:open_wearable/models/wearable_display_group.dart';
import 'package:open_wearable/view_models/sensor_data_provider.dart';
import 'package:open_wearable/view_models/sensor_recorder_provider_facade.dart';
import 'package:open_wearable/view_models/wearables_provider.dart';
import 'package:open_wearable/widgets/sensors/sensor_page_spacing.dart';
import 'package:open_wearable/widgets/sensors/values/sensor_value_card.dart';
import 'package:provider/provider.dart';

class SensorValuesPage extends StatefulWidget {
  final Map<(Wearable, Sensor), SensorDataProvider>? sharedProviders;

  const SensorValuesPage({
    super.key,
    this.sharedProviders,
  });

  @override
  State<SensorValuesPage> createState() => _SensorValuesPageState();
}

class _SensorValuesPageState extends State<SensorValuesPage>
    with AutomaticKeepAliveClientMixin<SensorValuesPage> {
  static const Duration _audioMicrophoneSourcesRefreshInterval =
      Duration(seconds: 5);

  final Map<(Wearable, Sensor), SensorDataProvider> _ownedProviders = {};
  Future<List<_AudioMicrophoneSourceInfo>>? _audioMicrophoneSourcesFuture;
  String? _audioMicrophoneSourcesCacheKey;
  DateTime? _audioMicrophoneSourcesLastRefresh;

  Map<(Wearable, Sensor), SensorDataProvider> get _sensorDataProvider =>
      widget.sharedProviders ?? _ownedProviders;

  bool get _ownsProviders => widget.sharedProviders == null;

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    if (_ownsProviders) {
      for (final provider in _ownedProviders.values) {
        provider.dispose();
      }
      _ownedProviders.clear();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return ValueListenableBuilder<bool>(
      valueListenable: AppShutdownSettings.disableLiveDataGraphsListenable,
      builder: (context, disableLiveDataGraphs, _) {
        return ValueListenableBuilder<bool>(
          valueListenable:
              AppShutdownSettings.hideLiveDataGraphsWithoutDataListenable,
          builder: (context, hideCardsWithoutLiveData, __) {
            final shouldHideCardsWithoutLiveData =
                hideCardsWithoutLiveData && !disableLiveDataGraphs;
            return Consumer2<WearablesProvider, SensorRecorderProvider>(
              builder: (context, wearablesProvider, recorderProvider, child) {
                return FutureBuilder<List<WearableDisplayGroup>>(
                  future: buildWearableDisplayGroups(
                    wearablesProvider.wearables,
                    shouldCombinePair: (left, right) =>
                        wearablesProvider.isStereoPairCombined(
                      first: left,
                      second: right,
                    ),
                  ),
                  builder: (context, snapshot) {
                    final groups = orderWearableGroupsByNameAndSide(
                      snapshot.data ??
                          wearablesProvider.wearables
                              .map(
                                (wearable) => WearableDisplayGroup.single(
                                  wearable: wearable,
                                ),
                              )
                              .toList(),
                    );
                    final orderedWearables =
                        _orderedWearablesFromGroups(groups);
                    final audioHeaderInfo = _resolveAudioHeaderInfo(
                      groups: groups,
                      recorderProvider: recorderProvider,
                    );
                    final audioMicrophoneSourcesFuture =
                        _audioMicrophoneSourcesFutureFor(
                      groups,
                      microphoneConfigurationRevision:
                          recorderProvider.microphoneConfigurationRevision,
                    );
                    _ensureProviders(orderedWearables);
                    _cleanupProviders(orderedWearables);

                    Widget buildContent() {
                      final hasAnySensors = _hasAnySensors(orderedWearables);
                      final charts = _buildCharts(
                        orderedWearables,
                        hideCardsWithoutLiveData:
                            shouldHideCardsWithoutLiveData,
                      );

                      return LayoutBuilder(
                        builder: (context, constraints) {
                          if (constraints.maxWidth < 600) {
                            return _buildSmallScreenLayout(
                              context,
                              charts,
                              recorderProvider,
                              audioHeaderInfo: audioHeaderInfo,
                              audioMicrophoneSourcesFuture:
                                  audioMicrophoneSourcesFuture,
                              hasAnySensors: hasAnySensors,
                              hideCardsWithoutLiveData:
                                  shouldHideCardsWithoutLiveData,
                            );
                          } else {
                            return _buildLargeScreenLayout(
                              context,
                              charts,
                              recorderProvider,
                              audioHeaderInfo: audioHeaderInfo,
                              audioMicrophoneSourcesFuture:
                                  audioMicrophoneSourcesFuture,
                              hasAnySensors: hasAnySensors,
                              hideCardsWithoutLiveData:
                                  shouldHideCardsWithoutLiveData,
                            );
                          }
                        },
                      );
                    }

                    if (disableLiveDataGraphs) {
                      return buildContent();
                    }

                    final sensorDataListenable =
                        Listenable.merge(_providersFor(orderedWearables));

                    return AnimatedBuilder(
                      animation: sensorDataListenable,
                      builder: (context, ___) => buildContent(),
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  void _ensureProviders(List<Wearable> orderedWearables) {
    for (final wearable in orderedWearables) {
      if (!wearable.hasCapability<SensorManager>()) {
        continue;
      }
      for (final sensor
          in wearable.requireCapability<SensorManager>().sensors) {
        _sensorDataProvider.putIfAbsent(
          (wearable, sensor),
          () => SensorDataProvider(
            wearable: wearable,
            sensor: sensor,
          ),
        );
      }
    }
  }

  Iterable<SensorDataProvider> _providersFor(
    List<Wearable> orderedWearables,
  ) sync* {
    for (final wearable in orderedWearables) {
      if (!wearable.hasCapability<SensorManager>()) {
        continue;
      }
      for (final sensor
          in wearable.requireCapability<SensorManager>().sensors) {
        final provider = _sensorDataProvider[(wearable, sensor)];
        if (provider != null) {
          yield provider;
        }
      }
    }
  }

  bool _hasAnySensors(List<Wearable> orderedWearables) {
    return orderedWearables.any(
      (wearable) =>
          wearable.hasCapability<SensorManager>() &&
          wearable.requireCapability<SensorManager>().sensors.isNotEmpty,
    );
  }

  List<Widget> _buildCharts(
    List<Wearable> orderedWearables, {
    required bool hideCardsWithoutLiveData,
  }) {
    final charts = <Widget>[];
    for (final wearable in orderedWearables) {
      if (!wearable.hasCapability<SensorManager>()) {
        continue;
      }
      for (final sensor
          in wearable.requireCapability<SensorManager>().sensors) {
        final provider = _sensorDataProvider[(wearable, sensor)];
        if (provider == null) {
          continue;
        }
        if (hideCardsWithoutLiveData && provider.sensorValues.isEmpty) {
          continue;
        }
        final chartIdentity = _sensorChartIdentity(
          wearable: wearable,
          sensor: sensor,
        );
        charts.add(
          ChangeNotifierProvider.value(
            key: ValueKey(chartIdentity),
            value: provider,
            child: SensorValueCard(
              sensor: sensor,
              wearable: wearable,
            ),
          ),
        );
      }
    }
    return charts;
  }

  String _sensorChartIdentity({
    required Wearable wearable,
    required Sensor sensor,
  }) {
    final axisNames = sensor.axisNames.join(',');
    final axisUnits = sensor.axisUnits.join(',');
    return '${wearable.deviceId}|${sensor.runtimeType}|${sensor.sensorName}|$axisNames|$axisUnits';
  }

  void _cleanupProviders(List<Wearable> orderedWearables) {
    if (!_ownsProviders) {
      return;
    }
    _sensorDataProvider.removeWhere((key, provider) {
      final keepProvider = orderedWearables.any(
        (device) =>
            device.hasCapability<SensorManager>() &&
            device == key.$1 &&
            device.requireCapability<SensorManager>().sensors.contains(key.$2),
      );
      if (!keepProvider) {
        provider.dispose();
      }
      return !keepProvider;
    });
  }

  List<Wearable> _orderedWearablesFromGroups(
    List<WearableDisplayGroup> groups,
  ) {
    final ordered = <Wearable>[];
    for (final group in groups) {
      final left = group.leftDevice;
      final right = group.rightDevice;
      if (left != null) {
        ordered.add(left);
      }
      if (right != null && right.deviceId != left?.deviceId) {
        ordered.add(right);
      }
      if (left == null && right == null) {
        ordered.addAll(group.members);
      }
    }
    return ordered;
  }

  _AudioHeaderInfo _resolveAudioHeaderInfo({
    required List<WearableDisplayGroup> groups,
    required SensorRecorderProvider recorderProvider,
  }) {
    final stereoBadgeLabel = _resolveAudioStereoBadgeLabel(groups);
    final selectedInputLabel = recorderProvider.selectedBLEDeviceLabel;
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

  String? _resolveAudioStereoBadgeLabel(List<WearableDisplayGroup> groups) {
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

  Future<List<_AudioMicrophoneSourceInfo>> _resolveAudioMicrophoneSources(
    List<WearableDisplayGroup> groups,
  ) async {
    final futures = <Future<_AudioMicrophoneSourceInfo?>>[];
    final seenDeviceIds = <String>{};

    void addCandidate(Wearable? wearable, DevicePosition? position) {
      if (wearable == null || !seenDeviceIds.add(wearable.deviceId)) {
        return;
      }
      futures.add(
        _resolveAudioMicrophoneSource(
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
    return sources..sort(_compareAudioMicrophoneSources);
  }

  Future<List<_AudioMicrophoneSourceInfo>> _audioMicrophoneSourcesFutureFor(
    List<WearableDisplayGroup> groups, {
    required int microphoneConfigurationRevision,
  }) {
    final cacheKey =
        '${_audioMicrophoneSourcesKey(groups)}#$microphoneConfigurationRevision';
    final now = DateTime.now();
    final lastRefresh = _audioMicrophoneSourcesLastRefresh;
    final cacheExpired = lastRefresh == null ||
        now.difference(lastRefresh) > _audioMicrophoneSourcesRefreshInterval;

    if (_audioMicrophoneSourcesFuture == null ||
        _audioMicrophoneSourcesCacheKey != cacheKey ||
        cacheExpired) {
      _audioMicrophoneSourcesCacheKey = cacheKey;
      _audioMicrophoneSourcesLastRefresh = now;
      _audioMicrophoneSourcesFuture = _resolveAudioMicrophoneSources(groups);
    }

    return _audioMicrophoneSourcesFuture!;
  }

  String _audioMicrophoneSourcesKey(List<WearableDisplayGroup> groups) {
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

  Future<_AudioMicrophoneSourceInfo?> _resolveAudioMicrophoneSource({
    required Wearable wearable,
    required DevicePosition? position,
  }) async {
    if (!wearable.hasCapability<MicrophoneManager>()) {
      return null;
    }

    final resolvedPosition =
        position ?? await _readAudioMicrophoneSourcePosition(wearable);
    final sideLabel = _audioMicrophoneSourceSideLabel(resolvedPosition);
    if (sideLabel == null) {
      return null;
    }

    try {
      final microphone =
          await wearable.requireCapability<MicrophoneManager>().getMicrophone();
      final microphoneLabel = _audioMicrophoneSourceLabel(microphone);
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

  Future<DevicePosition?> _readAudioMicrophoneSourcePosition(
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

  int _compareAudioMicrophoneSources(
    _AudioMicrophoneSourceInfo a,
    _AudioMicrophoneSourceInfo b,
  ) {
    return _audioMicrophoneSourceSortRank(a.sideLabel)
        .compareTo(_audioMicrophoneSourceSortRank(b.sideLabel));
  }

  int _audioMicrophoneSourceSortRank(String sideLabel) {
    return switch (sideLabel) {
      'L' => 0,
      'R' => 1,
      _ => 2,
    };
  }

  String? _audioMicrophoneSourceSideLabel(DevicePosition? position) {
    return switch (position) {
      DevicePosition.left => 'L',
      DevicePosition.right => 'R',
      _ => null,
    };
  }

  String? _audioMicrophoneSourceLabel(Microphone microphone) {
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

  Widget _buildAudioUI(
    SensorRecorderProvider recorderProvider, {
    required _AudioHeaderInfo audioHeaderInfo,
    required Future<List<_AudioMicrophoneSourceInfo>>
        audioMicrophoneSourcesFuture,
  }) {
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
              child: _AudioLevelChart(
                waveformData: recorderProvider.waveformData,
                microphoneSourcesFuture: audioMicrophoneSourcesFuture,
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _shouldShowSystemMicrophoneChart() => !kIsWeb && Platform.isAndroid;

  Widget _buildSmallScreenLayout(
    BuildContext context,
    List<Widget> charts,
    SensorRecorderProvider recorderProvider, {
    required _AudioHeaderInfo audioHeaderInfo,
    required Future<List<_AudioMicrophoneSourceInfo>>
        audioMicrophoneSourcesFuture,
    required bool hasAnySensors,
    required bool hideCardsWithoutLiveData,
  }) {
    return ListView(
      padding: SensorPageSpacing.pagePaddingWithBottomInset(context),
      children: [
        ...charts,
        if (charts.isEmpty)
          Center(
            child: _buildEmptyStateCard(
              context,
              _resolveEmptyState(
                hasAnySensors: hasAnySensors,
                hideCardsWithoutLiveData: hideCardsWithoutLiveData,
              ),
            ),
          ),
        if (_shouldShowSystemMicrophoneChart())
          _buildAudioUI(
            recorderProvider,
            audioHeaderInfo: audioHeaderInfo,
            audioMicrophoneSourcesFuture: audioMicrophoneSourcesFuture,
          ),
      ],
    );
  }

  Widget _buildLargeScreenLayout(
    BuildContext context,
    List<Widget> charts,
    SensorRecorderProvider recorderProvider, {
    required _AudioHeaderInfo audioHeaderInfo,
    required Future<List<_AudioMicrophoneSourceInfo>>
        audioMicrophoneSourcesFuture,
    required bool hasAnySensors,
    required bool hideCardsWithoutLiveData,
  }) {
    final gridItems = <Widget>[
      if (charts.isEmpty)
        _buildEmptyStateCard(
          context,
          _resolveEmptyState(
            hasAnySensors: hasAnySensors,
            hideCardsWithoutLiveData: hideCardsWithoutLiveData,
          ),
        )
      else
        ...charts,
      if (_shouldShowSystemMicrophoneChart())
        _buildAudioUI(
          recorderProvider,
          audioHeaderInfo: audioHeaderInfo,
          audioMicrophoneSourcesFuture: audioMicrophoneSourcesFuture,
        ),
    ];

    return SingleChildScrollView(
      padding: SensorPageSpacing.pagePaddingWithBottomInset(context),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 500,
          childAspectRatio: 1.5,
          crossAxisSpacing: SensorPageSpacing.gridGap,
          mainAxisSpacing: SensorPageSpacing.gridGap,
        ),
        itemCount: gridItems.length,
        itemBuilder: (context, index) {
          return gridItems[index];
        },
      ),
    );
  }

  _SensorValuesEmptyState _resolveEmptyState({
    required bool hasAnySensors,
    required bool hideCardsWithoutLiveData,
  }) {
    if (hasAnySensors && hideCardsWithoutLiveData) {
      return const _SensorValuesEmptyState(
        icon: Icons.sensors_outlined,
        title: 'Waiting for live sensor data',
        subtitle:
            'Graphs will appear once your sensors stream their first samples.',
        removeCardBackground: true,
      );
    }

    return const _SensorValuesEmptyState(
      icon: Icons.sensors_off_outlined,
      title: 'No sensors connected',
      subtitle: 'Connect a wearable to start viewing live sensor values.',
    );
  }

  Widget _buildEmptyStateCard(
    BuildContext context,
    _SensorValuesEmptyState emptyState,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final removeCardBackground = emptyState.removeCardBackground;

    return Card(
      color: removeCardBackground ? Colors.transparent : null,
      clipBehavior: Clip.antiAlias,
      elevation: removeCardBackground ? 0 : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: removeCardBackground
            ? BorderSide.none
            : BorderSide(
                color: colorScheme.outlineVariant.withValues(alpha: 0.55),
              ),
      ),
      shadowColor: removeCardBackground ? Colors.transparent : null,
      surfaceTintColor: removeCardBackground ? Colors.transparent : null,
      child: Ink(
        decoration: removeCardBackground
            ? null
            : BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    colorScheme.primaryContainer.withValues(alpha: 0.28),
                    colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                  ],
                ),
              ),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: colorScheme.primary.withValues(alpha: 0.12),
                    border: Border.all(
                      color: colorScheme.primary.withValues(alpha: 0.28),
                    ),
                  ),
                  child: Icon(
                    emptyState.icon,
                    size: 28,
                    color: colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 14),
                PlatformText(
                  emptyState.title,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                PlatformText(
                  emptyState.subtitle,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SensorValuesEmptyState {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool removeCardBackground;

  const _SensorValuesEmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.removeCardBackground = false,
  });
}

class _AudioHeaderInfo {
  final String? deviceName;
  final String? stereoBadgeLabel;

  const _AudioHeaderInfo({
    required this.deviceName,
    required this.stereoBadgeLabel,
  });
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
