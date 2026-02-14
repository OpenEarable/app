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
                  selected: sensorConfigNotifier
                      .getSelectedConfigurationOptions(
                        sensorConfiguration,
                      )
                      .contains(targetOptions[i]),
                  onChanged: (enabled) {
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
                ),
                if (i < targetOptions.length - 1)
                  Divider(
                    height: 10,
                    thickness: 0.6,
                    color: colorScheme.outlineVariant.withValues(alpha: 0.4),
                  ),
              ],
            ],
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
    final (title, subtitle) = _copyForOption(option);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOut,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: selected
            ? colorScheme.primary.withValues(alpha: 0.06)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: (selected ? colorScheme.primary : colorScheme.outlineVariant)
              .withValues(alpha: selected ? 0.35 : 0.25),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            getSensorConfigurationOptionIcon(option),
            size: 14,
            color: foreground,
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Column(
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
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Switch.adaptive(
            value: selected,
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
        'Send this sensor over Bluetooth for live data view.',
      );
    }
    if (option is RecordSensorConfigOption) {
      return (
        'Record to SD card',
        'Include this sensor in on-device recordings.',
      );
    }
    return (option.name, null);
  }
}
