part of '../sensor_chart.dart';

class _AxisConfigurationPanel extends StatelessWidget {
  final Color axisColor;
  final bool visible;
  final _AxisFilterConfig filter;
  final _FilterFrequencyBounds frequencyBounds;
  final ValueChanged<bool> onVisibleChanged;
  final ValueChanged<_AxisFilterConfig> onFilterChanged;
  final VoidCallback onApplyFilterToAll;
  final VoidCallback onResetChannel;

  const _AxisConfigurationPanel({
    super.key,
    required this.axisColor,
    required this.visible,
    required this.filter,
    required this.frequencyBounds,
    required this.onVisibleChanged,
    required this.onFilterChanged,
    required this.onApplyFilterToAll,
    required this.onResetChannel,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      children: [
        _ChannelVisibilityTile(
          accentColor: axisColor,
          visible: visible,
          onChanged: onVisibleChanged,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Divider(
            height: 1,
            thickness: 1,
            color: colorScheme.outlineVariant.withValues(alpha: 0.65),
          ),
        ),
        _FilterToggleTile(
          accentColor: axisColor,
          icon: Icons.trending_down_rounded,
          title: 'Low-pass filter',
          subtitle: 'Attenuates components above the cutoff.',
          value: filter.lowPassEnabled,
          onChanged: (value) {
            onFilterChanged(
              filter.copyWith(lowPassEnabled: value).clampedTo(
                    frequencyBounds,
                  ),
            );
          },
          child: _SingleCutoffFields(
            frequencyHz: filter.lowPassCutoffHz,
            order: filter.lowPassOrder,
            frequencyBounds: frequencyBounds,
            frequencyLabel: 'Cutoff frequency',
            frequencyHelperText: 'Low-pass cutoff frequency.',
            orderLabel: 'Low-pass order',
            extraFrequencyValidator: (value) {
              if (filter.highPassEnabled && value <= filter.highPassCutoffHz) {
                return 'Must be above high-pass cutoff.';
              }
              return null;
            },
            onChanged: (frequencyHz, order) {
              onFilterChanged(
                filter
                    .copyWith(
                      lowPassEnabled: true,
                      lowPassCutoffHz: frequencyHz,
                      lowPassOrder: order,
                    )
                    .clampedTo(frequencyBounds),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        _FilterToggleTile(
          accentColor: axisColor,
          icon: Icons.trending_up_rounded,
          title: 'High-pass filter',
          subtitle: 'Attenuates components below the cutoff.',
          value: filter.highPassEnabled,
          onChanged: (value) {
            onFilterChanged(
              filter.copyWith(highPassEnabled: value).clampedTo(
                    frequencyBounds,
                  ),
            );
          },
          child: _SingleCutoffFields(
            frequencyHz: filter.highPassCutoffHz,
            order: filter.highPassOrder,
            frequencyBounds: frequencyBounds,
            frequencyLabel: 'Cutoff frequency',
            frequencyHelperText: 'High-pass cutoff frequency.',
            orderLabel: 'High-pass order',
            extraFrequencyValidator: (value) {
              if (filter.lowPassEnabled && value >= filter.lowPassCutoffHz) {
                return 'Must be below low-pass cutoff.';
              }
              return null;
            },
            onChanged: (frequencyHz, order) {
              onFilterChanged(
                filter
                    .copyWith(
                      highPassEnabled: true,
                      highPassCutoffHz: frequencyHz,
                      highPassOrder: order,
                    )
                    .clampedTo(frequencyBounds),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        _FilterToggleTile(
          accentColor: axisColor,
          icon: Icons.horizontal_rule_rounded,
          title: 'Notch filter',
          subtitle: 'Attenuates one frequency band.',
          value: filter.notchEnabled,
          onChanged: (value) {
            onFilterChanged(
              filter.copyWith(notchEnabled: value).clampedTo(frequencyBounds),
            );
          },
          child: _NotchFields(
            centerHz: filter.notchCenterHz,
            widthHz: filter.notchWidthHz,
            order: filter.notchOrder,
            frequencyBounds: frequencyBounds,
            onChanged: (centerHz, widthHz, order) {
              onFilterChanged(
                filter
                    .copyWith(
                      notchEnabled: true,
                      notchCenterHz: centerHz,
                      notchWidthHz: widthHz,
                      notchOrder: order,
                    )
                    .clampedTo(frequencyBounds),
              );
            },
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            TextButton.icon(
              onPressed: onResetChannel,
              icon: const Icon(Icons.restart_alt_rounded, size: 18),
              label: const Text('Reset'),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: onApplyFilterToAll,
              icon: const Icon(Icons.copy_all_rounded, size: 18),
              label: const Text('Apply to all'),
            ),
          ],
        ),
      ],
    );
  }
}

class _ChannelVisibilityTile extends StatelessWidget {
  final Color accentColor;
  final bool visible;
  final ValueChanged<bool> onChanged;

  const _ChannelVisibilityTile({
    required this.accentColor,
    required this.visible,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return _FilterToggleTile(
      accentColor: accentColor,
      icon: visible ? Icons.visibility_rounded : Icons.visibility_off_rounded,
      title: 'Show channel',
      subtitle: 'Hide or show this channel in the graph.',
      value: visible,
      onChanged: onChanged,
    );
  }
}

class _FilterToggleTile extends StatelessWidget {
  final Color accentColor;
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final Widget? child;

  const _FilterToggleTile({
    required this.accentColor,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final foreground = value ? accentColor : colorScheme.onSurface;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOut,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: value ? accentColor.withValues(alpha: 0.06) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: (value ? accentColor : colorScheme.outlineVariant)
              .withValues(alpha: value ? 0.35 : 0.25),
        ),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(icon, size: 15, color: foreground),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: foreground,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            height: 1.15,
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Switch.adaptive(
                value: value,
                activeThumbColor: colorScheme.surface,
                activeTrackColor: accentColor,
                inactiveThumbColor: colorScheme.surface,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                onChanged: onChanged,
              ),
            ],
          ),
          if (value && child != null) ...[
            const SizedBox(height: 10),
            child!,
          ],
        ],
      ),
    );
  }
}

class _SingleCutoffFields extends StatefulWidget {
  final double frequencyHz;
  final int order;
  final _FilterFrequencyBounds frequencyBounds;
  final String frequencyLabel;
  final String frequencyHelperText;
  final String orderLabel;
  final String? Function(double value)? extraFrequencyValidator;
  final void Function(double frequencyHz, int order) onChanged;

  const _SingleCutoffFields({
    required this.frequencyHz,
    required this.order,
    required this.frequencyBounds,
    required this.frequencyLabel,
    required this.frequencyHelperText,
    required this.orderLabel,
    required this.onChanged,
    this.extraFrequencyValidator,
  });

  @override
  State<_SingleCutoffFields> createState() => _SingleCutoffFieldsState();
}

class _SingleCutoffFieldsState extends State<_SingleCutoffFields> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _frequencyController;
  late final TextEditingController _orderController;

  @override
  void initState() {
    super.initState();
    _frequencyController = TextEditingController(
      text: _formatNumber(widget.frequencyHz),
    );
    _orderController = TextEditingController(text: widget.order.toString());
  }

  @override
  void didUpdateWidget(covariant _SingleCutoffFields oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.frequencyHz != oldWidget.frequencyHz) {
      _replaceText(_frequencyController, _formatNumber(widget.frequencyHz));
    }
    if (widget.order != oldWidget.order) {
      _replaceText(_orderController, widget.order.toString());
    }
  }

  @override
  void dispose() {
    _frequencyController.dispose();
    _orderController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      child: Column(
        children: [
          _FrequencyInputField(
            controller: _frequencyController,
            label: widget.frequencyLabel,
            helperText: widget.frequencyHelperText,
            validator: _validateFrequency,
            onChanged: _commitIfValid,
          ),
          const SizedBox(height: 10),
          _OrderInputField(
            controller: _orderController,
            label: widget.orderLabel,
            validator: _validateOrder,
            onChanged: _commitIfValid,
          ),
        ],
      ),
    );
  }

  void _commitIfValid() {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    widget.onChanged(
      double.parse(_frequencyController.text),
      int.parse(_orderController.text),
    );
  }

  String? _validateFrequency(String? value) {
    final parsed = _parseFrequency(value);
    if (parsed == null) {
      return 'Enter a number.';
    }
    final rangeError = _validateFrequencyRange(parsed, widget.frequencyBounds);
    if (rangeError != null) {
      return rangeError;
    }
    return widget.extraFrequencyValidator?.call(parsed);
  }

  String? _validateOrder(String? value) => _validateFilterOrder(value);
}

class _NotchFields extends StatefulWidget {
  final double centerHz;
  final double widthHz;
  final int order;
  final _FilterFrequencyBounds frequencyBounds;
  final void Function(double centerHz, double widthHz, int order) onChanged;

  const _NotchFields({
    required this.centerHz,
    required this.widthHz,
    required this.order,
    required this.frequencyBounds,
    required this.onChanged,
  });

  @override
  State<_NotchFields> createState() => _NotchFieldsState();
}

class _NotchFieldsState extends State<_NotchFields> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _centerController;
  late final TextEditingController _widthController;
  late final TextEditingController _orderController;

  @override
  void initState() {
    super.initState();
    _centerController = TextEditingController(
      text: _formatNumber(widget.centerHz),
    );
    _widthController = TextEditingController(
      text: _formatNumber(widget.widthHz),
    );
    _orderController = TextEditingController(text: widget.order.toString());
  }

  @override
  void didUpdateWidget(covariant _NotchFields oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.centerHz != oldWidget.centerHz) {
      _replaceText(_centerController, _formatNumber(widget.centerHz));
    }
    if (widget.widthHz != oldWidget.widthHz) {
      _replaceText(_widthController, _formatNumber(widget.widthHz));
    }
    if (widget.order != oldWidget.order) {
      _replaceText(_orderController, widget.order.toString());
    }
  }

  @override
  void dispose() {
    _centerController.dispose();
    _widthController.dispose();
    _orderController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      child: Column(
        children: [
          _FrequencyInputField(
            controller: _centerController,
            label: 'Center',
            helperText: 'Center frequency of the attenuated band.',
            validator: _validateCenter,
            onChanged: _commitIfValid,
          ),
          const SizedBox(height: 10),
          _FrequencyInputField(
            controller: _widthController,
            label: 'Width',
            helperText: 'Bandwidth around the center frequency.',
            validator: _validateWidth,
            onChanged: _commitIfValid,
          ),
          const SizedBox(height: 10),
          _OrderInputField(
            controller: _orderController,
            label: 'Notch order',
            helperText:
                'Even notch order; higher values deepen the attenuated band.',
            validator: _validateNotchOrder,
            onChanged: _commitIfValid,
          ),
        ],
      ),
    );
  }

  void _commitIfValid() {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    widget.onChanged(
      double.parse(_centerController.text),
      double.parse(_widthController.text),
      int.parse(_orderController.text),
    );
  }

  String? _validateCenter(String? value) {
    final parsed = _parseFrequency(value);
    if (parsed == null) {
      return 'Enter a number.';
    }
    final rangeError = _validateFrequencyRange(parsed, widget.frequencyBounds);
    if (rangeError != null) {
      return rangeError;
    }
    return _validateNotchEdges(centerHz: parsed);
  }

  String? _validateWidth(String? value) {
    final parsed = _parseFrequency(value);
    if (parsed == null) {
      return 'Enter a number.';
    }
    if (parsed < widget.frequencyBounds.minCutoffHz) {
      return 'Use at least ${_formatNumber(widget.frequencyBounds.minCutoffHz)} Hz.';
    }
    if (parsed > widget.frequencyBounds.maxCutoffHz) {
      return 'Use up to ${_formatNumber(widget.frequencyBounds.maxCutoffHz)} Hz.';
    }
    return _validateNotchEdges(widthHz: parsed);
  }

  String? _validateNotchEdges({
    double? centerHz,
    double? widthHz,
  }) {
    final center = centerHz ?? _parseFrequency(_centerController.text);
    final width = widthHz ?? _parseFrequency(_widthController.text);
    if (center == null || width == null) {
      return null;
    }

    final lowEdge = center - width / 2;
    final highEdge = center + width / 2;
    if (lowEdge < widget.frequencyBounds.minCutoffHz ||
        highEdge > widget.frequencyBounds.maxCutoffHz) {
      return 'Keep the band within ${_formatNumber(widget.frequencyBounds.minCutoffHz)}-${_formatNumber(widget.frequencyBounds.maxCutoffHz)} Hz.';
    }
    return null;
  }
}

class _FrequencyInputField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String helperText;
  final FormFieldValidator<String> validator;
  final VoidCallback onChanged;

  const _FrequencyInputField({
    required this.controller,
    required this.label,
    required this.helperText,
    required this.validator,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
      ],
      decoration: _filterInputDecoration(
        context,
        label: label,
        helperText: helperText,
        suffixText: 'Hz',
      ),
      validator: validator,
      onChanged: (_) => onChanged(),
    );
  }
}

class _OrderInputField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String helperText;
  final FormFieldValidator<String> validator;
  final VoidCallback onChanged;

  const _OrderInputField({
    required this.controller,
    required this.label,
    required this.validator,
    required this.onChanged,
    this.helperText =
        'Butterworth order; higher values steepen the transition band.',
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: _filterInputDecoration(
        context,
        label: label,
        helperText: helperText,
      ),
      validator: validator,
      onChanged: (_) => onChanged(),
    );
  }
}

InputDecoration _filterInputDecoration(
  BuildContext context, {
  required String label,
  required String helperText,
  String? suffixText,
}) {
  final colorScheme = Theme.of(context).colorScheme;
  return InputDecoration(
    labelText: label,
    helperText: helperText,
    helperMaxLines: 2,
    errorMaxLines: 2,
    suffixText: suffixText,
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
      vertical: 9,
    ),
  );
}

String? _validateFrequencyRange(
  double value,
  _FilterFrequencyBounds frequencyBounds,
) {
  if (value < frequencyBounds.minCutoffHz ||
      value > frequencyBounds.maxCutoffHz) {
    return 'Use ${_formatNumber(frequencyBounds.minCutoffHz)}-${_formatNumber(frequencyBounds.maxCutoffHz)} Hz.';
  }
  return null;
}

String? _validateFilterOrder(String? value) {
  final parsed = int.tryParse(value?.trim() ?? '');
  if (parsed == null) {
    return 'Enter a whole number.';
  }
  if (parsed < _AxisFilterConfig.minOrder ||
      parsed > _AxisFilterConfig.maxOrder) {
    return 'Use ${_AxisFilterConfig.minOrder}-${_AxisFilterConfig.maxOrder}.';
  }
  return null;
}

String? _validateNotchOrder(String? value) {
  final parsed = int.tryParse(value?.trim() ?? '');
  if (parsed == null) {
    return 'Enter a whole number.';
  }
  if (parsed < _AxisFilterConfig.minNotchOrder ||
      parsed > _AxisFilterConfig.maxNotchOrder ||
      parsed.isOdd) {
    return 'Use 2, 4, 6, or 8.';
  }
  return null;
}

double? _parseFrequency(String? value) {
  final trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) {
    return null;
  }
  return double.tryParse(trimmed);
}

void _replaceText(TextEditingController controller, String value) {
  if (controller.text == value) {
    return;
  }
  controller.value = TextEditingValue(
    text: value,
    selection: TextSelection.collapsed(offset: value.length),
  );
}
