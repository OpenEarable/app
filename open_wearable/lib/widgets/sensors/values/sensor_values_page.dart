import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart';
import 'package:open_wearable/models/app_shutdown_settings.dart';
import 'package:open_wearable/models/wearable_display_group.dart';
import 'package:open_wearable/view_models/sensor_data_provider.dart';
import 'package:open_wearable/view_models/sensor_recorder_provider.dart';
import 'package:open_wearable/view_models/wearables_provider.dart';
import 'package:open_wearable/widgets/sensors/sensor_page_spacing.dart';
import 'package:open_wearable/widgets/sensors/values/sensor_value_card.dart';
import 'package:provider/provider.dart';
import 'dart:io';

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
  final Map<(Wearable, Sensor), SensorDataProvider> _ownedProviders = {};

  Map<(Wearable, Sensor), SensorDataProvider> get _sensorDataProvider =>
      widget.sharedProviders ?? _ownedProviders;

  bool get _ownsProviders => widget.sharedProviders == null;

  String? _errorMessage;
  bool _isInitializing = true;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    if (Platform.isAndroid) {
      _checkStreamingStatus();
    }
  }

  void _checkStreamingStatus() {
    final recorderProvider =
        Provider.of<SensorRecorderProvider>(context, listen: false);
    if (!recorderProvider.isBLEMicrophoneStreamingEnabled) {
      if (mounted) {
        setState(() {
          _isInitializing = false;
          _errorMessage =
              'BLE microphone streaming not enabled. Enable it in sensor configuration.';
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _isInitializing = false;
          _errorMessage = null;
        });
      }
    }
  }

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
                if (Platform.isAndroid && mounted) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!recorderProvider.isBLEMicrophoneStreamingEnabled &&
                        _errorMessage == null &&
                        !recorderProvider.isRecording) {
                      setState(() {
                        _errorMessage =
                            'BLE microphone streaming not enabled. Enable it in sensor configuration.';
                      });
                    } else if (recorderProvider
                            .isBLEMicrophoneStreamingEnabled &&
                        _errorMessage != null &&
                        _errorMessage!
                            .contains('BLE microphone streaming not enabled')) {
                      setState(() {
                        _errorMessage = null;
                      });
                    }
                  });
                }
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
                              hasAnySensors: hasAnySensors,
                              hideCardsWithoutLiveData:
                                  shouldHideCardsWithoutLiveData,
                              recorderProvider: recorderProvider,
                            );
                          } else {
                            return _buildLargeScreenLayout(
                              context,
                              charts,
                              hasAnySensors: hasAnySensors,
                              hideCardsWithoutLiveData:
                                  shouldHideCardsWithoutLiveData,
                              recorderProvider: recorderProvider,
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

  Widget _buildSmallScreenLayout(
    BuildContext context,
    List<Widget> charts, {
    required bool hasAnySensors,
    required bool hideCardsWithoutLiveData,
    required SensorRecorderProvider recorderProvider,
  }) {
    if (charts.isEmpty) {
      final emptyState = _resolveEmptyState(
        hasAnySensors: hasAnySensors,
        hideCardsWithoutLiveData: hideCardsWithoutLiveData,
      );
      return Padding(
        padding: SensorPageSpacing.pagePaddingWithBottomInset(context),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: _buildEmptyStateCard(context, emptyState),
          ),
        ),
      );
    }

    final showRecorderWaveform = recorderProvider.isRecording;

    return Padding(
      padding: SensorPageSpacing.pagePaddingWithBottomInset(context),
      child: ListView(
        children: [
          // Android microphone waveform and error
          if (Platform.isAndroid) ...[
            // Waveform card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          showRecorderWaveform
                              ? Icons.fiber_manual_record
                              : Icons.mic,
                          color:
                              showRecorderWaveform ? Colors.red : Colors.blue,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          showRecorderWaveform
                              ? 'AUDIO WAVEFORM (Recording)'
                              : 'AUDIO WAVEFORM',
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 100,
                      child: _isInitializing
                          ? const Center(child: CircularProgressIndicator())
                          : CustomPaint(
                              painter: WaveformPainter(
                                  recorderProvider.waveformData),
                            ),
                    ),
                  ],
                ),
              ),
            ),
            // Error message
            if (_errorMessage != null) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    _errorMessage!,
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ],
          // Sensor charts
          ...charts,
        ],
      ),
    );
  }

  Widget _buildLargeScreenLayout(
    BuildContext context,
    List<Widget> charts, {
    required bool hasAnySensors,
    required bool hideCardsWithoutLiveData,
    required SensorRecorderProvider recorderProvider,
  }) {
    final emptyState = _resolveEmptyState(
      hasAnySensors: hasAnySensors,
      hideCardsWithoutLiveData: hideCardsWithoutLiveData,
    );
    final showRecorderWaveform = recorderProvider.isRecording;

    return Padding(
      padding: SensorPageSpacing.pagePaddingWithBottomInset(context),
      child: SingleChildScrollView(
        child: Column(
          children: [
            // Android microphone waveform and error (top priority)
            if (Platform.isAndroid) ...[
              // Waveform card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            showRecorderWaveform
                                ? Icons.fiber_manual_record
                                : Icons.mic,
                            color:
                                showRecorderWaveform ? Colors.red : Colors.blue,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            showRecorderWaveform
                                ? 'Audio waveform (Recording)'
                                : 'Audio waveform',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 80,
                        child: _isInitializing
                            ? const Center(child: CircularProgressIndicator())
                            : CustomPaint(
                                painter: WaveformPainter(
                                    recorderProvider.waveformData),
                              ),
                      ),
                    ],
                  ),
                ),
              ),
              if (_errorMessage != null) ...[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      _errorMessage!,
                      style:
                          TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ],
            const SizedBox(height: 16),
            // Sensor charts grid
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 500,
                childAspectRatio: 1.5,
                crossAxisSpacing: SensorPageSpacing.gridGap,
                mainAxisSpacing: SensorPageSpacing.gridGap,
              ),
              itemCount: charts.isEmpty ? 1 : charts.length,
              itemBuilder: (context, index) {
                if (charts.isEmpty) {
                  return _buildEmptyStateCard(context, emptyState);
                }
                return charts[index];
              },
            ),
          ],
        ),
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

// Custom waveform painter with vertical bars
class WaveformPainter extends CustomPainter {
  final List<double> waveformData;
  final Color waveColor;
  final double spacing;
  final double waveThickness;
  final bool showMiddleLine;

  WaveformPainter(
    this.waveformData, {
    this.waveColor = Colors.blue,
    this.spacing = 4.0,
    this.waveThickness = 3.0,
    this.showMiddleLine = true,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (waveformData.isEmpty) return;

    final double height = size.height;
    final double centerY = height / 2;

    // Draw middle line first (behind the bars)
    if (showMiddleLine) {
      final centerLinePaint = Paint()
        ..color = Colors.grey.withAlpha(75)
        ..strokeWidth = 1.0;
      canvas.drawLine(
        Offset(0, centerY),
        Offset(size.width, centerY),
        centerLinePaint,
      );
    }

    // Paint for the vertical bars
    final paint = Paint()
      ..color = waveColor
      ..strokeWidth = waveThickness
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    // Calculate how many bars can fit in the available width
    final maxBars = (size.width / spacing).floor();
    final startIndex =
        waveformData.length > maxBars ? waveformData.length - maxBars : 0;

    // Calculate starting position (always start at 0 or align right)
    final visibleData = waveformData.sublist(startIndex);
    final totalWaveformWidth = visibleData.length * spacing;
    final startX = size.width - totalWaveformWidth;

    // Draw each amplitude value as a vertical bar
    for (int i = 0; i < visibleData.length; i++) {
      final x = startX + (i * spacing);
      final amplitude = visibleData[i];

      // Scale amplitude to fit within the canvas height
      final barHeight = amplitude * centerY * 0.8;

      // Draw top half of the bar (above center line)
      final topY = centerY - barHeight;
      final bottomY = centerY + barHeight;

      // Draw the vertical line from top to bottom
      canvas.drawLine(
        Offset(x, topY),
        Offset(x, bottomY),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant WaveformPainter oldDelegate) {
    return oldDelegate.waveformData.length != waveformData.length ||
        oldDelegate.waveColor != waveColor;
  }
}
