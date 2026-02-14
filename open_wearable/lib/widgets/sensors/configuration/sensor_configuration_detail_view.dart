import 'package:flutter/material.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart';
import 'package:open_wearable/view_models/sensor_configuration_provider.dart';
import 'package:provider/provider.dart';

import 'sensor_config_option_icon_factory.dart';

class SensorConfigurationDetailView extends StatelessWidget {
  final SensorConfiguration sensorConfiguration;

  const SensorConfigurationDetailView({
    super.key,
    required this.sensorConfiguration,
  });

  @override
  Widget build(BuildContext context) {
    final sensorConfigNotifier = context.watch<SensorConfigurationProvider>();
    final selectedValue =
        sensorConfigNotifier.getSelectedConfigurationValue(sensorConfiguration);
    final selectableValues = sensorConfigNotifier
        .getSensorConfigurationValues(sensorConfiguration, distinct: true)
        .where((value) => _isVisibleValue(value, selectedValue))
        .toList(growable: false);
    final dropdownSelection =
        _resolveSelection(selectableValues, selectedValue);
    final colorScheme = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
      children: [
        if (sensorConfiguration is ConfigurableSensorConfiguration) ...[
          _DetailSectionCard(
            title: 'Data Targets',
            subtitle: 'Choose where this sensor stream is routed.',
            child: Column(
              children: (sensorConfiguration as ConfigurableSensorConfiguration)
                  .availableOptions
                  .map(
                    (option) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _OptionToggleTile(
                        option: option,
                        selected: sensorConfigNotifier
                            .getSelectedConfigurationOptions(
                              sensorConfiguration,
                            )
                            .contains(option),
                        onChanged: (enabled) {
                          if (enabled) {
                            sensorConfigNotifier.addSensorConfigurationOption(
                              sensorConfiguration,
                              option,
                            );
                          } else {
                            sensorConfigNotifier
                                .removeSensorConfigurationOption(
                              sensorConfiguration,
                              option,
                            );
                          }
                        },
                      ),
                    ),
                  )
                  .toList(growable: false),
            ),
          ),
          const SizedBox(height: 8),
        ],
        _DetailSectionCard(
          title: 'Sampling Rate',
          subtitle: 'Set how often this sensor is sampled.',
          child: selectableValues.isEmpty
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
                        color:
                            colorScheme.outlineVariant.withValues(alpha: 0.55),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color:
                            colorScheme.outlineVariant.withValues(alpha: 0.55),
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
                    sensorConfigNotifier.addSensorConfiguration(
                      sensorConfiguration,
                      value,
                    );
                  },
                ),
        ),
        const SizedBox(height: 8),
        Text(
          'Changes are staged locally. Use "Apply Profiles" to push them to the device.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
        ),
      ],
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
}

class _DetailSectionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;

  const _DetailSectionCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 9),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            subtitle,
            style: theme.textTheme.labelMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _OptionToggleTile extends StatelessWidget {
  final SensorConfigurationOption option;
  final bool selected;
  final ValueChanged<bool> onChanged;

  const _OptionToggleTile({
    required this.option,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final foreground = selected ? colorScheme.primary : colorScheme.onSurface;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: (selected ? colorScheme.primary : colorScheme.outlineVariant)
              .withValues(alpha: selected ? 0.35 : 0.5),
        ),
      ),
      child: Row(
        children: [
          Icon(
            getSensorConfigurationOptionIcon(option),
            size: 14,
            color: foreground,
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              option.name,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
          Switch.adaptive(
            value: selected,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
