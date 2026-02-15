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
                  sensorConfigNotifier.addSensorConfiguration(
                    sensorConfiguration,
                    value,
                  );
                },
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
        'Include this sensor in on-device recordings.',
      );
    }
    return (option.name, null);
  }
}
