import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart';
import 'package:open_wearable/view_models/sensor_configuration_provider.dart';
import 'package:open_wearable/widgets/sensors/configuration/sensor_configuration_detail_view.dart';
import 'package:provider/provider.dart';

import 'sensor_config_option_icon_factory.dart';

const double _kSensorStatusPillHeight = 22;

/// A row that displays a sensor configuration and allows the user to select a value.
///
/// The selected value is added to the [SensorConfigurationProvider].
class SensorConfigurationValueRow extends StatelessWidget {
  final SensorConfiguration sensorConfiguration;

  const SensorConfigurationValueRow({
    super.key,
    required this.sensorConfiguration,
  });

  @override
  Widget build(BuildContext context) {
    const sensorOnGreen = Color(0xFF2E7D32);
    final sensorConfigNotifier = context.watch<SensorConfigurationProvider>();
    final colorScheme = Theme.of(context).colorScheme;
    final isOn = _isOn(sensorConfigNotifier, sensorConfiguration);
    final selectedValue =
        sensorConfigNotifier.getSelectedConfigurationValue(sensorConfiguration);
    final selectedOptions =
        sensorConfiguration is ConfigurableSensorConfiguration
            ? sensorConfigNotifier
                .getSelectedConfigurationOptions(
                  sensorConfiguration,
                )
                .toList(growable: false)
            : const <SensorConfigurationOption>[];

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 2, 12, 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => _openConfigurationSheet(context, sensorConfigNotifier),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(2, 8, 2, 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: isOn ? 3 : 2,
                  height: 26,
                  decoration: BoxDecoration(
                    color: (isOn ? sensorOnGreen : colorScheme.outlineVariant)
                        .withValues(alpha: isOn ? 0.7 : 0.6),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(width: 6),
                Icon(
                  isOn ? Icons.sensors_rounded : Icons.sensors_off_rounded,
                  size: 14,
                  color: isOn ? sensorOnGreen : colorScheme.outline,
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    sensorConfiguration.name,
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
                if (selectedOptions.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  _OptionsCompactBadge(
                    options: selectedOptions,
                  ),
                ],
                const SizedBox(width: 6),
                _SamplingRatePill(
                  label: _statusPillLabel(selectedValue, isOn: isOn),
                  enabled: isOn,
                ),
                const SizedBox(width: 2),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 16,
                  color: colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openConfigurationSheet(
    BuildContext context,
    SensorConfigurationProvider sensorConfigNotifier,
  ) {
    showPlatformModalSheet<void>(
      context: context,
      builder: (modalContext) {
        return ChangeNotifierProvider.value(
          value: sensorConfigNotifier,
          child: SafeArea(
            child: SizedBox(
              height: MediaQuery.of(modalContext).size.height * 0.82,
              child: Material(
                color: Theme.of(modalContext).colorScheme.surface,
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
                                Text(
                                  sensorConfiguration.name,
                                  style: Theme.of(modalContext)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(
                                        fontWeight: FontWeight.w700,
                                      ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Adjust data targets and sampling rate.',
                                  style: Theme.of(modalContext)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                        color: Theme.of(modalContext)
                                            .colorScheme
                                            .onSurfaceVariant,
                                      ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            tooltip: 'Close',
                            onPressed: () => Navigator.of(modalContext).pop(),
                            icon: const Icon(Icons.close_rounded, size: 20),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: SensorConfigurationDetailView(
                        sensorConfiguration: sensorConfiguration,
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
  }

  String _statusPillLabel(
    SensorConfigurationValue? value, {
    required bool isOn,
  }) {
    if (!isOn) {
      return 'Off';
    }
    if (value is SensorFrequencyConfigurationValue) {
      return _formatFrequency(value.frequencyHz);
    }
    return 'On';
  }

  String _formatFrequency(double hz) {
    if ((hz - hz.roundToDouble()).abs() < 0.01) {
      return '${hz.round()} Hz';
    }
    if (hz >= 10) {
      return '${hz.toStringAsFixed(1)} Hz';
    }
    return '${hz.toStringAsFixed(2)} Hz';
  }

  bool _isOn(SensorConfigurationProvider notifier, SensorConfiguration config) {
    bool isOn = false;
    if (config is ConfigurableSensorConfiguration) {
      isOn = notifier.getSelectedConfigurationOptions(config).isNotEmpty;
    } else if (config is SensorFrequencyConfiguration) {
      SensorFrequencyConfigurationValue? value =
          notifier.getSelectedConfigurationValue(config)
              as SensorFrequencyConfigurationValue?;
      isOn = value?.frequencyHz != null && value!.frequencyHz > 0;
    } else {
      isOn = true;
    }

    return isOn;
  }
}

class _OptionsCompactBadge extends StatelessWidget {
  final List<SensorConfigurationOption> options;

  const _OptionsCompactBadge({
    required this.options,
  });

  @override
  Widget build(BuildContext context) {
    const sensorOnGreen = Color(0xFF2E7D32);
    final colorScheme = Theme.of(context).colorScheme;
    final visibleCount = options.length > 2 ? 2 : options.length;
    final remainingCount = options.length - visibleCount;

    return SizedBox(
      height: _kSensorStatusPillHeight,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: sensorOnGreen.withValues(alpha: 0.38),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < visibleCount; i++) ...[
              Icon(
                getSensorConfigurationOptionIcon(options[i]) ??
                    Icons.tune_rounded,
                size: 10,
                color: sensorOnGreen,
              ),
              if (i < visibleCount - 1) const SizedBox(width: 3),
            ],
            if (remainingCount > 0) ...[
              const SizedBox(width: 4),
              Text(
                '+$remainingCount',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: sensorOnGreen,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SamplingRatePill extends StatelessWidget {
  final String label;
  final bool enabled;

  const _SamplingRatePill({
    required this.label,
    required this.enabled,
  });

  @override
  Widget build(BuildContext context) {
    const sensorOnGreen = Color(0xFF2E7D32);
    final colorScheme = Theme.of(context).colorScheme;
    final foreground = enabled ? sensorOnGreen : colorScheme.onSurfaceVariant;

    return SizedBox(
      height: _kSensorStatusPillHeight,
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 7),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: foreground.withValues(alpha: 0.42),
          ),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 38),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: foreground,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
      ),
    );
  }
}
