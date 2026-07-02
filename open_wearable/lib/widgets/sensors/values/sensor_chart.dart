import 'dart:collection';
import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart' hide logger;
import 'package:open_wearable/view_models/sensor_configuration_provider.dart';
import 'package:open_wearable/view_models/sensor_data_provider.dart';
import 'package:open_wearable/view_models/wearables_provider.dart';
import 'package:open_wearable/widgets/sensors/values/live_data_graph_settings.dart';
import 'package:provider/provider.dart';

part 'sensor_chart/axis_channel_chip.dart';
part 'sensor_chart/axis_configuration_sheet.dart';
part 'sensor_chart/axis_display_filter.dart';
part 'sensor_chart/axis_filter_engine.dart';
part 'sensor_chart/axis_filter_config.dart';

/// Displays a provider-backed live line chart for a wearable sensor.
class SensorChart extends StatefulWidget {
  /// Whether the chart uses the compact embedded-card layout.
  final bool compactMode;

  /// Whether users can open the per-axis configuration sheet.
  final bool allowAxisConfiguration;

  /// Shared live graph policy controlling visibility and sample updates.
  final LiveDataGraphSettings settings;

  /// Called when the disabled graph overlay is tapped.
  final VoidCallback? onDisabledTap;

  const SensorChart({
    super.key,
    this.compactMode = false,
    this.allowAxisConfiguration = true,
    this.settings = LiveDataGraphSettings.enabled,
    this.onDisabledTap,
  });

  @override
  State<SensorChart> createState() => _SensorChartState();
}

class _SensorChartState extends State<SensorChart> {
  static const List<Color> _fallbackColors = [
    Color(0xFF4A90E2),
    Color(0xFFE76F51),
    Color(0xFF2A9D8F),
    Color(0xFFB565D9),
    Color(0xFFF4A261),
    Color(0xFF3D5A80),
    Color(0xFFD62828),
  ];

  late Map<String, bool> _axisEnabled;
  late Map<String, _AxisFilterConfig> _axisFilters;
  late Map<String, _AxisDisplayFilterCache> _axisDisplayFilters;
  late String _sensorIdentity;

  @override
  void initState() {
    super.initState();
    final sensor = context.read<SensorDataProvider>().sensor;
    _initializeAxisState(sensor);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final sensor = context.read<SensorDataProvider>().sensor;
    _syncAxisState(sensor);
  }

  void _setAxisVisible(String axisName, bool value) {
    setState(() {
      _axisEnabled[axisName] = value;
      _axisDisplayFilters.remove(axisName);
    });
  }

  void _setAxisFilter(String axisName, _AxisFilterConfig filter) {
    setState(() {
      _axisFilters[axisName] = filter;
      _axisDisplayFilters.remove(axisName);
    });
  }

  @override
  Widget build(BuildContext context) {
    final dataProvider = widget.settings.liveUpdatesEnabled
        ? context.watch<SensorDataProvider>()
        : context.read<SensorDataProvider>();
    final sensorConfigurationProvider = _sensorConfigurationProviderFor(
      context,
      dataProvider.wearable,
    );

    if (sensorConfigurationProvider == null) {
      return _buildChart(
        context,
        dataProvider: dataProvider,
        sensorConfigurationProvider: null,
      );
    }

    return ListenableBuilder(
      listenable: sensorConfigurationProvider,
      builder: (context, _) => _buildChart(
        context,
        dataProvider: dataProvider,
        sensorConfigurationProvider: sensorConfigurationProvider,
      ),
    );
  }

  Widget _buildChart(
    BuildContext context, {
    required SensorDataProvider dataProvider,
    required SensorConfigurationProvider? sensorConfigurationProvider,
  }) {
    final sensor = dataProvider.sensor;
    _syncAxisState(sensor);
    final sensorValues = widget.settings.liveUpdatesEnabled
        ? dataProvider.sensorValues
        : Queue<SensorValue>();
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final compactMode = widget.compactMode;
    final referenceTimestamp = dataProvider.displayTimestamp;
    final visibleAxes = {
      for (final axis in sensor.axisNames)
        if (_axisEnabled[axis] ?? false) axis,
    };
    final frequencyBounds = _frequencyBoundsForSensor(
      sensor,
      sensorConfigurationProvider: sensorConfigurationProvider,
    );

    final axisData = _buildAxisData(
      sensor,
      sensorValues,
      visibleAxes: visibleAxes,
      windowSeconds: dataProvider.timeWindow.toDouble(),
      referenceTimestamp: referenceTimestamp,
      frequencyBounds: frequencyBounds,
    );
    final enabledSeries = <_AxisSeries>[
      for (int i = 0; i < sensor.axisNames.length; i++)
        if (_axisEnabled[sensor.axisNames[i]] ?? false)
          _AxisSeries(
            spots: axisData[sensor.axisNames[i]] ?? const <FlSpot>[],
            color: _axisColor(
              axisIndex: i,
              axisName: sensor.axisNames[i],
              colorScheme: colorScheme,
            ),
          ),
    ];

    final windowSeconds = dataProvider.timeWindow.toDouble();
    const maxX = 0.0;
    final minX = -windowSeconds;
    final yAxisBounds = _computeYAxisBounds(enabledSeries);

    const disabledChipLabelColor = Color(0xFF8A8A8A);
    const disabledChipBackgroundColor = Color(0xFFECECEC);
    const disabledChipBorderColor = Color(0xFFD7D7D7);
    const disabledChipDotColor = Color(0xFFB3B3B3);

    final leftUnit = sensor.axisUnits.isNotEmpty ? sensor.axisUnits.first : '';

    final chartData = LineChartData(
      minX: minX,
      maxX: maxX,
      minY: yAxisBounds.min,
      maxY: yAxisBounds.max,
      lineTouchData: LineTouchData(
        enabled: widget.settings.liveUpdatesEnabled && !compactMode,
        handleBuiltInTouches:
            widget.settings.liveUpdatesEnabled && !compactMode,
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
          axisNameWidget: leftUnit.isEmpty
              ? null
              : PlatformText(
                  leftUnit,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
          axisNameSize: leftUnit.isEmpty ? 0 : (compactMode ? 16 : 22),
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: compactMode ? 34 : 46,
            minIncluded: false,
            maxIncluded: false,
            getTitlesWidget: (value, meta) {
              final isBoundaryTick = (value - yAxisBounds.min).abs() < 1e-6 ||
                  (value - yAxisBounds.max).abs() < 1e-6;
              if (isBoundaryTick) {
                return const SizedBox.shrink();
              }
              return SideTitleWidget(
                meta: meta,
                space: 6,
                child: SizedBox(
                  width: compactMode ? 30 : 40,
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
            reservedSize: compactMode ? 20 : 24,
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
      lineBarsData: enabledSeries
          .map(
            (series) => LineChartBarData(
              spots: series.spots,
              isCurved: false,
              barWidth: 2.2,
              color: series.color,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(show: false),
            ),
          )
          .toList(growable: false),
    );

    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              compactMode ? 2 : 6,
              compactMode ? 2 : 4,
              2,
              0,
            ),
            child: LiveDataGraphSurface(
              settings: widget.settings,
              onDisabledTap: widget.onDisabledTap,
              child: LineChart(
                chartData,
                duration: const Duration(milliseconds: 0),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: LayoutBuilder(
            builder: (context, constraints) => Row(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minWidth: max(0.0, constraints.maxWidth - 70),
                      ),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children:
                              sensor.axisNames.asMap().entries.map((entry) {
                            final axisIndex = entry.key;
                            final axisName = entry.value;
                            final axisColor = _axisColor(
                              axisIndex: axisIndex,
                              axisName: axisName,
                              colorScheme: colorScheme,
                            );
                            final selected = _axisEnabled[axisName] ?? false;
                            final filter = _effectiveAxisFilter(
                              axisName,
                              frequencyBounds,
                            );

                            return Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: _AxisChannelChip(
                                axisName: axisName,
                                statusLabel: _axisChipStatusLabel(
                                  filter: filter,
                                ),
                                dotColor:
                                    selected ? axisColor : disabledChipDotColor,
                                labelColor: selected
                                    ? axisColor.withValues(alpha: 0.95)
                                    : disabledChipLabelColor,
                                backgroundColor: selected
                                    ? axisColor.withValues(alpha: 0.18)
                                    : disabledChipBackgroundColor,
                                borderColor: selected
                                    ? axisColor.withValues(alpha: 0.28)
                                    : disabledChipBorderColor,
                                dottedBorder: !selected,
                                compact: compactMode,
                                onTap: widget.settings.liveUpdatesEnabled &&
                                        widget.allowAxisConfiguration
                                    ? () => _openAxisConfigurationSheet(
                                          context: context,
                                          sensor: sensor,
                                          dataProvider: dataProvider,
                                          axisName: axisName,
                                          axisColor: axisColor,
                                        )
                                    : null,
                              ),
                            );
                          }).toList(growable: false),
                        ),
                      ),
                    ),
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

  void _openAxisConfigurationSheet({
    required BuildContext context,
    required Sensor sensor,
    required SensorDataProvider dataProvider,
    required String axisName,
    required Color axisColor,
  }) {
    final frequencyBounds = _frequencyBoundsForSensor(
      sensor,
      sensorConfigurationProvider: _sensorConfigurationProviderFor(
        context,
        dataProvider.wearable,
      ),
    );
    final existingFilter =
        _axisFilters[axisName] ?? const _AxisFilterConfig.raw();
    final clampedFilter = existingFilter.clampedTo(frequencyBounds);
    if (existingFilter != clampedFilter) {
      setState(() {
        _axisFilters[axisName] = clampedFilter;
        _axisDisplayFilters.remove(axisName);
      });
    }

    showPlatformModalSheet<void>(
      context: context,
      material: MaterialModalSheetData(
        isScrollControlled: true,
        showDragHandle: true,
        isDismissible: true,
        enableDrag: true,
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            final visible = _axisEnabled[axisName] ?? true;
            final filter =
                (_axisFilters[axisName] ?? const _AxisFilterConfig.raw())
                    .clampedTo(frequencyBounds);

            void updateVisible(bool value) {
              _setAxisVisible(axisName, value);
              setSheetState(() {});
            }

            void updateFilter(_AxisFilterConfig value) {
              _setAxisFilter(axisName, value.clampedTo(frequencyBounds));
              setSheetState(() {});
            }

            void applyFilterToAll() {
              setState(() {
                for (final axis in sensor.axisNames) {
                  _axisFilters[axis] = filter;
                  _axisDisplayFilters.remove(axis);
                }
              });
              setSheetState(() {});
            }

            void resetChannel() {
              setState(() {
                _axisEnabled[axisName] = true;
                _axisFilters[axisName] =
                    const _AxisFilterConfig.raw().clampedTo(frequencyBounds);
                _axisDisplayFilters.remove(axisName);
              });
              setSheetState(() {});
            }

            final theme = Theme.of(sheetContext);
            final colorScheme = theme.colorScheme;
            final sensorTitle = _axisConfigurationSensorTitle(sensor);
            final mediaQuery = MediaQuery.of(sheetContext);
            return SafeArea(
              child: AnimatedPadding(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                padding: EdgeInsets.only(bottom: mediaQuery.viewInsets.bottom),
                child: SizedBox(
                  height: mediaQuery.size.height * 0.82,
                  child: Material(
                    color: colorScheme.surface,
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      children: [
                                        if (sensorTitle.isNotEmpty) ...[
                                          Flexible(
                                            fit: FlexFit.loose,
                                            child: Text(
                                              sensorTitle,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: theme.textTheme.titleMedium
                                                  ?.copyWith(
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                        ],
                                        _AxisHeaderChannelPill(
                                          axisName: axisName,
                                          axisColor: axisColor,
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Configure graph visibility and filtering. Recordings are unaffected.',
                                      style:
                                          theme.textTheme.bodySmall?.copyWith(
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                tooltip: 'Close',
                                onPressed: () =>
                                    Navigator.of(sheetContext).pop(),
                                icon: const Icon(Icons.close_rounded, size: 20),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: _AxisConfigurationPanel(
                            key: ValueKey('axis_config_$axisName'),
                            axisColor: axisColor,
                            visible: visible,
                            filter: filter,
                            frequencyBounds: frequencyBounds,
                            onVisibleChanged: updateVisible,
                            onFilterChanged: updateFilter,
                            onApplyFilterToAll: applyFilterToAll,
                            onResetChannel: resetChannel,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  String _axisConfigurationSensorTitle(Sensor sensor) =>
      sensor.sensorName.trim();

  String _axisChipStatusLabel({required _AxisFilterConfig filter}) {
    return _axisFilterShortLabel(filter);
  }

  _AxisFilterConfig _effectiveAxisFilter(
    String axisName,
    _FilterFrequencyBounds frequencyBounds,
  ) {
    return (_axisFilters[axisName] ?? const _AxisFilterConfig.raw()).clampedTo(
      frequencyBounds,
    );
  }

  SensorConfigurationProvider? _sensorConfigurationProviderFor(
    BuildContext context,
    Wearable wearable,
  ) {
    try {
      return context
          .read<WearablesProvider>()
          .getSensorConfigurationProvider(wearable);
    } catch (_) {
      return null;
    }
  }

  _FilterFrequencyBounds _frequencyBoundsForSensor(
    Sensor sensor, {
    SensorConfigurationProvider? sensorConfigurationProvider,
  }) {
    final activeStreamingRates = <double>[];
    final streamingRates = <double>[];
    final fallbackRates = <double>[];

    for (final configuration in sensor.relatedConfigurations) {
      final activeValue = _activeFrequencyValueForConfiguration(
        configuration,
        sensorConfigurationProvider,
      );
      if (activeValue != null &&
          activeValue.frequencyHz > 0 &&
          _isStreamingFrequencyValue(configuration, activeValue)) {
        activeStreamingRates.add(activeValue.frequencyHz);
      }

      for (final value in configuration.values) {
        if (value is! SensorFrequencyConfigurationValue ||
            value.frequencyHz <= 0) {
          continue;
        }

        fallbackRates.add(value.frequencyHz);

        if (_isStreamingFrequencyValue(configuration, value)) {
          streamingRates.add(value.frequencyHz);
        }
      }
    }

    final rates = activeStreamingRates.isNotEmpty
        ? activeStreamingRates
        : (streamingRates.isNotEmpty ? streamingRates : fallbackRates);
    if (rates.isEmpty) {
      return const _FilterFrequencyBounds.fallback();
    }

    final maxSamplingRateHz = rates.reduce(max);
    return _FilterFrequencyBounds(
      maxCutoffHz: max(
        _FilterFrequencyBounds.defaultMinCutoffHz,
        maxSamplingRateHz / 2,
      ),
      maxSamplingRateHz: maxSamplingRateHz,
    );
  }

  SensorFrequencyConfigurationValue? _activeFrequencyValueForConfiguration(
    SensorConfiguration configuration,
    SensorConfigurationProvider? sensorConfigurationProvider,
  ) {
    final selectedValue =
        sensorConfigurationProvider?.getSelectedConfigurationValue(
      configuration,
    );
    if (selectedValue is SensorFrequencyConfigurationValue) {
      return selectedValue;
    }

    final reportedValue =
        sensorConfigurationProvider?.getLastReportedConfigurationValue(
      configuration,
    );
    if (reportedValue is SensorFrequencyConfigurationValue) {
      return reportedValue;
    }

    final dynamic configurationDynamic = configuration;
    try {
      final currentValue = configurationDynamic.currentValue;
      if (currentValue is SensorFrequencyConfigurationValue) {
        return currentValue;
      }
    } catch (_) {
      // Fall back to advertised values when the configuration has no current
      // value API.
    }
    return null;
  }

  bool _isStreamingFrequencyValue(
    SensorConfiguration configuration,
    SensorFrequencyConfigurationValue value,
  ) {
    final SensorConfigurationValue configurationValue = value;
    if (configurationValue is ConfigurableSensorConfigurationValue) {
      return configurationValue.options.contains(
        const StreamSensorConfigOption(),
      );
    }

    return configuration is! ConfigurableSensorConfiguration ||
        configuration.availableOptions.contains(
          const StreamSensorConfigOption(),
        );
  }

  String _axisFilterShortLabel(_AxisFilterConfig filter) {
    if (!filter.hasActiveFilters) {
      return 'Raw';
    }

    final labels = <String>[];
    if (filter.highPassEnabled && filter.lowPassEnabled) {
      labels.add(
        'BP ${_formatNumber(filter.highPassCutoffHz)}-${_formatNumber(filter.lowPassCutoffHz)}Hz',
      );
    } else if (filter.highPassEnabled) {
      labels.add('HP ${_formatNumber(filter.highPassCutoffHz)}Hz');
    } else if (filter.lowPassEnabled) {
      labels.add('LP ${_formatNumber(filter.lowPassCutoffHz)}Hz');
    }

    if (filter.notchEnabled) {
      labels.add(
        'N ${_formatNumber(filter.notchCenterHz)}±${_formatNumber(filter.notchWidthHz / 2)}Hz',
      );
    }

    return labels.isEmpty ? 'Raw' : labels.join(' + ');
  }

  double _toRelativeSeconds(
    Sensor sensor,
    int timestamp, {
    required int referenceTimestamp,
  }) {
    final scale = pow(10, -sensor.timestampExponent).toDouble();
    return (timestamp - referenceTimestamp).toDouble() / scale;
  }

  Map<String, List<FlSpot>> _buildAxisData(
    Sensor sensor,
    Queue<SensorValue> buffer, {
    required Set<String> visibleAxes,
    required double windowSeconds,
    required int referenceTimestamp,
    required _FilterFrequencyBounds frequencyBounds,
  }) {
    final data = <String, List<FlSpot>>{
      for (var axis in sensor.axisNames) axis: <FlSpot>[],
    };
    if (buffer.isEmpty) return data;

    final timestampScale = pow(10, -sensor.timestampExponent).toDouble();
    final filteredVisibleAxes = visibleAxes.where((axisName) {
      final filter = _effectiveAxisFilter(axisName, frequencyBounds);
      return filter.hasActiveFilters;
    }).toList(growable: false);
    if (filteredVisibleAxes.isNotEmpty && _axisDisplayFilters.isNotEmpty) {
      final visibleTimestamps = {
        for (final sensorValue in buffer) sensorValue.timestamp,
      };
      for (final axisName in filteredVisibleAxes) {
        _axisDisplayFilters[axisName]?.retainTimestamps(visibleTimestamps);
      }
    }

    for (final sensorValue in buffer) {
      final x = _toRelativeSeconds(
        sensor,
        sensorValue.timestamp,
        referenceTimestamp: referenceTimestamp,
      ).clamp(-windowSeconds, 0.0);
      if (sensorValue is SensorDoubleValue) {
        for (int i = 0; i < sensor.axisCount; i++) {
          final axisName = sensor.axisNames[i];
          if (!visibleAxes.contains(axisName)) {
            continue;
          }
          final displayValue = _displayValueForAxis(
            axisName: axisName,
            rawValue: sensorValue.values[i],
            timestamp: sensorValue.timestamp,
            timestampScale: timestampScale,
            frequencyBounds: frequencyBounds,
          );
          data[axisName]!.add(FlSpot(x, displayValue));
        }
      } else {
        final values = (sensorValue as SensorIntValue).values;
        for (int i = 0; i < sensor.axisCount; i++) {
          final axisName = sensor.axisNames[i];
          if (!visibleAxes.contains(axisName)) {
            continue;
          }
          final displayValue = _displayValueForAxis(
            axisName: axisName,
            rawValue: values[i].toDouble(),
            timestamp: sensorValue.timestamp,
            timestampScale: timestampScale,
            frequencyBounds: frequencyBounds,
          );
          data[axisName]!.add(FlSpot(x, displayValue));
        }
      }
    }

    return data;
  }

  double _displayValueForAxis({
    required String axisName,
    required double rawValue,
    required int timestamp,
    required double timestampScale,
    required _FilterFrequencyBounds frequencyBounds,
  }) {
    final config = _effectiveAxisFilter(axisName, frequencyBounds);
    if (!config.hasActiveFilters) {
      return rawValue;
    }

    return _displayFilterForAxis(
      axisName: axisName,
      config: config,
      timestampScale: timestampScale,
    ).apply(rawValue, timestamp);
  }

  _AxisDisplayFilterCache _displayFilterForAxis({
    required String axisName,
    required _AxisFilterConfig config,
    required double timestampScale,
  }) {
    final existing = _axisDisplayFilters[axisName];
    if (existing != null &&
        existing.config == config &&
        existing.timestampScale == timestampScale) {
      return existing;
    }

    final next = _AxisDisplayFilterCache(
      config: config,
      timestampScale: timestampScale,
    );
    _axisDisplayFilters[axisName] = next;
    return next;
  }

  _YAxisBounds _computeYAxisBounds(List<_AxisSeries> seriesList) {
    var minY = double.infinity;
    var maxY = double.negativeInfinity;

    for (final series in seriesList) {
      for (final spot in series.spots) {
        minY = min(minY, spot.y);
        maxY = max(maxY, spot.y);
      }
    }

    if (!minY.isFinite || !maxY.isFinite) {
      return const _YAxisBounds(min: -1, max: 1);
    }

    final range = maxY - minY;
    if (range.abs() < 1e-9) {
      final pad = max(minY.abs() * 0.05, 1e-3);
      return _YAxisBounds(
        min: minY - pad,
        max: maxY + pad,
      );
    }

    final pad = max(range * 0.1, 1e-6);
    return _YAxisBounds(
      min: minY - pad,
      max: maxY + pad,
    );
  }

  void _initializeAxisState(Sensor sensor) {
    _sensorIdentity = _sensorKey(sensor);
    _axisEnabled = {for (final axis in sensor.axisNames) axis: true};
    _axisFilters = {
      for (final axis in sensor.axisNames) axis: const _AxisFilterConfig.raw(),
    };
    _axisDisplayFilters = <String, _AxisDisplayFilterCache>{};
  }

  void _syncAxisState(Sensor sensor) {
    final sensorIdentity = _sensorKey(sensor);
    if (sensorIdentity != _sensorIdentity) {
      _initializeAxisState(sensor);
      return;
    }

    final hasSameAxes = _axisEnabled.length == sensor.axisNames.length &&
        _axisFilters.length == sensor.axisNames.length &&
        sensor.axisNames.every(
          (axis) =>
              _axisEnabled.containsKey(axis) && _axisFilters.containsKey(axis),
        );
    if (hasSameAxes) {
      return;
    }

    _axisEnabled = {
      for (final axis in sensor.axisNames) axis: _axisEnabled[axis] ?? true,
    };
    _axisFilters = {
      for (final axis in sensor.axisNames)
        axis: _axisFilters[axis] ?? const _AxisFilterConfig.raw(),
    };
    final axisNames = sensor.axisNames.toSet();
    _axisDisplayFilters.removeWhere((axis, _) => !axisNames.contains(axis));
  }

  String _sensorKey(Sensor sensor) =>
      '${sensor.runtimeType}|${sensor.sensorName}|${sensor.axisNames.join(',')}|${sensor.axisUnits.join(',')}';

  String _formatXAxisTick(double value) {
    final rounded = value.roundToDouble();
    if ((value - rounded).abs() < 0.05) {
      return rounded.toInt().toString();
    }
    return value.toStringAsFixed(1);
  }

  String _formatYAxisTick(double value) {
    final abs = value.abs();
    String output;

    if (abs >= 100000 || (abs > 0 && abs < 0.001)) {
      output = value.toStringAsExponential(1);
    } else if (abs >= 1000) {
      output = value.toStringAsFixed(0);
    } else if (abs >= 100) {
      output = value.toStringAsFixed(1);
    } else if (abs >= 1) {
      output = value.toStringAsFixed(2);
    } else {
      output = value.toStringAsFixed(3);
    }

    return _trimTrailingZeros(output);
  }

  String _trimTrailingZeros(String value) {
    if (value.contains('e') || value.contains('E')) return value;
    var result = value;
    if (result.contains('.')) {
      result = result.replaceFirst(RegExp(r'0+$'), '');
      result = result.replaceFirst(RegExp(r'\.$'), '');
    }
    return result;
  }

  Color _axisColor({
    required int axisIndex,
    required String axisName,
    required ColorScheme colorScheme,
  }) {
    final name = axisName.toLowerCase();

    if (name == 'x') return const Color(0xFF4A90E2);
    if (name == 'y') return const Color(0xFFE76F51);
    if (name == 'z') return const Color(0xFF2A9D8F);
    if (name == 'r' || name == 'red') return Colors.red;
    if (name == 'g' || name == 'green') return Colors.green;
    if (name == 'b' || name == 'blue') return Colors.blue;
    if (name.contains('temp')) return const Color(0xFFFB8500);
    if (name.contains('pressure')) return const Color(0xFF6C63FF);

    if (axisIndex == 0) return colorScheme.primary;
    return _fallbackColors[axisIndex % _fallbackColors.length];
  }
}

class _AxisSeries {
  final List<FlSpot> spots;
  final Color color;

  const _AxisSeries({
    required this.spots,
    required this.color,
  });
}

class _YAxisBounds {
  final double min;
  final double max;

  const _YAxisBounds({
    required this.min,
    required this.max,
  });
}
