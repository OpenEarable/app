import 'package:flutter/foundation.dart' show setEquals;
import 'package:flutter/material.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart';
import 'package:open_wearable/view_models/sensor_configuration_provider.dart';
import 'package:provider/provider.dart';

import 'sensor_config_option_icon_factory.dart';

class SensorConfigurationDetailView extends StatelessWidget {
  final SensorConfiguration sensorConfiguration;
  final SensorConfiguration? pairedSensorConfiguration;
  final SensorConfigurationProvider? pairedProvider;

  const SensorConfigurationDetailView({
    super.key,
    required this.sensorConfiguration,
    this.pairedSensorConfiguration,
    this.pairedProvider,
  });

  @override
  Widget build(BuildContext context) {
    const sensorOnGreen = Color(0xFF2E7D32);
    final sensorConfigNotifier = context.watch<SensorConfigurationProvider>();
    final selectedValue =
        sensorConfigNotifier.getSelectedConfigurationValue(sensorConfiguration);
    final isApplied = sensorConfigNotifier.isConfigurationApplied(
      sensorConfiguration,
    );
    final selectableValues = sensorConfigNotifier
        .getSensorConfigurationValues(sensorConfiguration, distinct: true)
        .where((value) => _isVisibleValue(value, selectedValue))
        .toList(growable: false);
    final dropdownSelection =
        _resolveSelection(selectableValues, selectedValue);
    final colorScheme = Theme.of(context).colorScheme;
    final accentColor = isApplied ? sensorOnGreen : colorScheme.primary;
    final targetOptions = sensorConfiguration is ConfigurableSensorConfiguration
        ? (sensorConfiguration as ConfigurableSensorConfiguration)
            .availableOptions
            .toList(growable: false)
        : const <SensorConfigurationOption>[];

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      children: [
        if (targetOptions.isNotEmpty) ...[
          Text(
            'Data Targets',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 3),
          Text(
            'Select where this sensor output is sent.',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 8),
          Column(
            children: [
              for (var i = 0; i < targetOptions.length; i++) ...[
                _OptionToggleTile(
                  option: targetOptions[i],
                  accentColor: accentColor,
                  selected: sensorConfigNotifier
                      .getSelectedConfigurationOptions(
                        sensorConfiguration,
                      )
                      .contains(targetOptions[i]),
                  onChanged: (enabled) {
                    _updatePrimaryAndPair(
                      primaryProvider: sensorConfigNotifier,
                      updatePrimary: () {
                        if (enabled) {
                          sensorConfigNotifier.addSensorConfigurationOption(
                            sensorConfiguration,
                            targetOptions[i],
                          );
                        } else {
                          sensorConfigNotifier.removeSensorConfigurationOption(
                            sensorConfiguration,
                            targetOptions[i],
                          );
                        }
                      },
                    );
                  },
                ),
                if (i < targetOptions.length - 1) const SizedBox(height: 8),
              ],
            ],
          ),
          const SizedBox(height: 12),
        ],
        Text(
          'Sampling Rate',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 3),
        Text(
          'Set how often this sensor is sampled.',
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 8),
        selectableValues.isEmpty
            ? Text(
                'No sampling rates are available for this sensor.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
              )
            : DropdownButtonFormField<SensorConfigurationValue>(
                initialValue: dropdownSelection,
                isExpanded: true,
                decoration: InputDecoration(
                  isDense: true,
                  filled: false,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: colorScheme.outlineVariant.withValues(alpha: 0.55),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: colorScheme.outlineVariant.withValues(alpha: 0.55),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: colorScheme.primary.withValues(alpha: 0.6),
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 7,
                  ),
                ),
                items: selectableValues
                    .map(
                      (value) => DropdownMenuItem<SensorConfigurationValue>(
                        value: value,
                        child: Text(_samplingRateLabel(value)),
                      ),
                    )
                    .toList(growable: false),
                onChanged: (value) {
                  if (value == null) {
                    return;
                  }
                  _updatePrimaryAndPair(
                    primaryProvider: sensorConfigNotifier,
                    updatePrimary: () {
                      sensorConfigNotifier.addSensorConfiguration(
                        sensorConfiguration,
                        value,
                      );
                    },
                  );
                },
              ),
      ],
    );
  }

  void _updatePrimaryAndPair({
    required SensorConfigurationProvider primaryProvider,
    required VoidCallback updatePrimary,
  }) {
    updatePrimary();
    _syncPairedSelection(primaryProvider);
  }

  void _syncPairedSelection(SensorConfigurationProvider primaryProvider) {
    final pairedNotifier = pairedProvider;
    final mirroredConfig = pairedSensorConfiguration;
    if (pairedNotifier == null || mirroredConfig == null) {
      return;
    }

    final selectedPrimaryValue =
        primaryProvider.getSelectedConfigurationValue(sensorConfiguration);
    if (selectedPrimaryValue == null) {
      return;
    }

    final mirroredValue = _findMirroredValue(
      mirroredConfig: mirroredConfig,
      sourceValue: selectedPrimaryValue,
    );
    if (mirroredValue == null) {
      return;
    }

    pairedNotifier.addSensorConfiguration(
      mirroredConfig,
      mirroredValue,
      markPending: true,
    );
  }

  bool _isVisibleValue(
    SensorConfigurationValue value,
    SensorConfigurationValue? selectedValue,
  ) {
    if (value is! SensorFrequencyConfigurationValue) {
      return true;
    }
    if (value.frequencyHz == 0 || value.frequencyHz >= 0.1) {
      return true;
    }
    if (selectedValue is! SensorFrequencyConfigurationValue) {
      return false;
    }
    return value.frequencyHz == selectedValue.frequencyHz;
  }

  SensorConfigurationValue? _resolveSelection(
    List<SensorConfigurationValue> values,
    SensorConfigurationValue? selected,
  ) {
    if (selected == null) {
      return null;
    }
    for (final value in values) {
      if (_sameValue(value, selected)) {
        return value;
      }
    }
    return null;
  }

  bool _sameValue(SensorConfigurationValue a, SensorConfigurationValue b) {
    if (a.runtimeType != b.runtimeType) {
      return false;
    }
    if (a is SensorFrequencyConfigurationValue &&
        b is SensorFrequencyConfigurationValue) {
      return a.frequencyHz == b.frequencyHz;
    }
    return a.key == b.key;
  }

  String _samplingRateLabel(SensorConfigurationValue value) {
    if (value is SensorFrequencyConfigurationValue) {
      return '${value.frequencyHz.toStringAsFixed(2)} Hz';
    }
    return value.key;
  }

  SensorConfigurationValue? _findMirroredValue({
    required SensorConfiguration mirroredConfig,
    required SensorConfigurationValue sourceValue,
  }) {
    for (final candidate in mirroredConfig.values) {
      if (_normalizeName(candidate.key) == _normalizeName(sourceValue.key)) {
        return candidate;
      }
    }

    if (sourceValue is SensorFrequencyConfigurationValue) {
      final sourceOptions = _optionNameSet(sourceValue);
      final candidates = mirroredConfig.values
          .whereType<SensorFrequencyConfigurationValue>()
          .toList(growable: false);
      if (candidates.isNotEmpty) {
        final sameOptionCandidates = candidates
            .where(
              (candidate) =>
                  setEquals(_optionNameSet(candidate), sourceOptions),
            )
            .toList(growable: false);
        final scoped =
            sameOptionCandidates.isNotEmpty ? sameOptionCandidates : candidates;
        SensorFrequencyConfigurationValue? best;
        double? bestDistance;
        for (final candidate in scoped) {
          final distance =
              (candidate.frequencyHz - sourceValue.frequencyHz).abs();
          if (best == null || distance < bestDistance!) {
            best = candidate;
            bestDistance = distance;
          }
        }
        if (best != null) {
          return best;
        }
      }
    }

    if (sourceValue is ConfigurableSensorConfigurationValue) {
      final sourceWithoutOptions = sourceValue.withoutOptions();
      final sourceOptions = _optionNameSet(sourceValue);
      for (final candidate in mirroredConfig.values
          .whereType<ConfigurableSensorConfigurationValue>()) {
        if (!setEquals(_optionNameSet(candidate), sourceOptions)) {
          continue;
        }
        if (_normalizeName(candidate.withoutOptions().key) ==
            _normalizeName(sourceWithoutOptions.key)) {
          return candidate;
        }
      }
    }

    return null;
  }

  Set<String> _optionNameSet(SensorConfigurationValue value) {
    if (value is! ConfigurableSensorConfigurationValue) {
      return const <String>{};
    }
    return value.options.map((option) => _normalizeName(option.name)).toSet();
  }

  String _normalizeName(String value) => value.trim().toLowerCase();
}

class _OptionToggleTile extends StatelessWidget {
  final SensorConfigurationOption option;
  final Color accentColor;
  final bool selected;
  final ValueChanged<bool> onChanged;

  const _OptionToggleTile({
    required this.option,
    required this.accentColor,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final foreground = selected ? accentColor : colorScheme.onSurface;
    final (title, subtitle) = _copyForOption(option);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOut,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: selected
            ? accentColor.withValues(alpha: 0.06)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: (selected ? accentColor : colorScheme.outlineVariant)
              .withValues(alpha: selected ? 0.35 : 0.25),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(
            getSensorConfigurationOptionIcon(option),
            size: 14,
            color: foreground,
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: foreground,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 1),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          height: 1.15,
                        ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Switch.adaptive(
            value: selected,
            activeThumbColor: colorScheme.surface,
            activeTrackColor: accentColor,
            inactiveThumbColor: colorScheme.surface,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  (String, String?) _copyForOption(SensorConfigurationOption option) {
    if (option is StreamSensorConfigOption) {
      return (
        'Live stream to phone',
        'Send to app via Bluetooth.',
      );
    }
    if (option is RecordSensorConfigOption) {
      return (
        'Record to SD card',
        'Include this sensor in on-device recordings. Turn this data target off to complete recording and close the file.',
      );
    }
    return (option.name, null);
  }
}
