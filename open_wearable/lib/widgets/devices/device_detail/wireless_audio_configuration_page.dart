import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart';
import 'package:open_wearable/view_models/wireless_audio_configuration_controller.dart';
import 'package:open_wearable/widgets/app_toast.dart';
import 'package:open_wearable/widgets/common/app_section_card.dart';
import 'package:open_wearable/widgets/sensors/sensor_page_spacing.dart';

/// Advanced, capability-aware wireless-audio settings for one wearable.
class WirelessAudioConfigurationPage extends StatefulWidget {
  /// Creates the page for a wearable that exposes
  /// [WirelessAudioConfigurationManager].
  const WirelessAudioConfigurationPage({super.key, required this.device});

  /// Device whose Bluetooth audio policy is configured.
  final Wearable device;

  @override
  State<WirelessAudioConfigurationPage> createState() =>
      _WirelessAudioConfigurationPageState();
}

class _WirelessAudioConfigurationPageState
    extends State<WirelessAudioConfigurationPage> {
  late final WirelessAudioConfigurationController _controller;
  bool _persist = false;

  @override
  void initState() {
    super.initState();
    _controller = WirelessAudioConfigurationController(
      widget.device.requireCapability<WirelessAudioConfigurationManager>(),
    )..addListener(_handleControllerChanged);
    _controller.load();
  }

  void _handleControllerChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_handleControllerChanged)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PlatformScaffold(
      appBar: PlatformAppBar(title: const Text('Wireless audio')),
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_controller.isLoading && _controller.capabilities == null) {
      return const Center(child: CircularProgressIndicator.adaptive());
    }
    if (_controller.loadError != null || _controller.capabilities == null) {
      return _LoadError(onRetry: _controller.load);
    }

    final capabilities = _controller.capabilities!;
    final supportsPersistence = _hasBit(capabilities.feature_flags, 1);
    final sections = <Widget>[
      AppSectionCard(
        title: 'Configuration behavior',
        subtitle:
            'Changes affect this device and may require reconnecting or restarting an audio stream.',
        child: SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          value: supportsPersistence && _persist,
          onChanged: supportsPersistence && !_controller.isMutating
              ? (value) => setState(() => _persist = value)
              : null,
          secondary: const Icon(Icons.save_outlined),
          title: const Text('Keep changes after restart'),
          subtitle: Text(
            supportsPersistence
                ? 'Off applies changes only for this device session.'
                : 'Persistent configuration is not supported by this firmware.',
          ),
        ),
      ),
      if (_supportsSection(capabilities, 0))
        _configurationCard(
          title: 'ACL connection',
          subtitle:
              'Connection interval, peripheral latency, and supervision timeout.',
          icon: Icons.link_rounded,
          value: _aclSummary(_controller.aclConnection?.policy),
          enabled: _supportsCommand(capabilities, 0) &&
              capabilities.supported_acl_policy_mask != 0,
          onEdit: () => _editAclConnection(capabilities),
        ),
      if (_supportsSection(capabilities, 1))
        _configurationCard(
          title: 'ACL radio',
          subtitle: 'Preferred PHY and data-length behavior.',
          icon: Icons.cell_tower_rounded,
          value: _radioSummary(_controller.aclRadio?.policy),
          enabled: _supportsCommand(capabilities, 1),
          onEdit: () => _editAclRadio(capabilities),
        ),
      if (_supportsSection(capabilities, 2))
        _configurationCard(
          title: 'Unicast Server QoS',
          subtitle:
              'Preferences advertised during subsequent LE Audio codec setup.',
          icon: Icons.graphic_eq_rounded,
          value: _qosSummary(_controller.qos?.preferences),
          enabled: _supportsCommand(capabilities, 2),
          onEdit: () => _editQos(capabilities),
        ),
      if (_controller.runtimeState != null)
        _RuntimeStateCard(state: _controller.runtimeState!),
      if (_supportsCommand(capabilities, 4))
        AppSectionCard(
          title: 'Defaults',
          subtitle:
              'Clear saved overrides and restore the firmware defaults for every audio section.',
          child: Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              onPressed:
                  _controller.isMutating ? null : _confirmRestoreDefaults,
              icon: const Icon(Icons.restore_rounded),
              label: const Text('Restore defaults'),
            ),
          ),
        ),
    ];

    return ListView.separated(
      padding: SensorPageSpacing.pagePaddingWithBottomInset(context),
      itemCount: sections.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, index) => sections[index],
    );
  }

  Widget _configurationCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required String value,
    required bool enabled,
    required VoidCallback onEdit,
  }) {
    return AppSectionCard(
      title: title,
      subtitle: subtitle,
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(icon),
        title: Text(value),
        subtitle:
            Text(enabled ? 'Tap to configure' : 'Read-only on this firmware'),
        trailing: enabled ? const Icon(Icons.chevron_right_rounded) : null,
        onTap: enabled && !_controller.isMutating ? onEdit : null,
      ),
    );
  }

  Future<void> _editAclConnection(
    WirelessAudioConfigurationCapabilities capabilities,
  ) async {
    final draft = _AclDraft.from(
      _controller.aclConnection?.policy,
      capabilities,
    );
    final policy =
        await showDialog<WirelessAudioConfigurationAclConnectionPolicy>(
      context: context,
      builder: (_) => _AclPolicyDialog(
        capabilities: capabilities,
        initial: draft,
      ),
    );
    if (policy == null || !mounted) return;
    await _runMutation(
      () => _controller.setAclConnectionPolicy(policy, persist: _persist),
    );
  }

  Future<void> _editAclRadio(
    WirelessAudioConfigurationCapabilities capabilities,
  ) async {
    final draft = _RadioDraft.from(_controller.aclRadio?.policy, capabilities);
    final policy = await showDialog<WirelessAudioConfigurationAclRadioPolicy>(
      context: context,
      builder: (_) => _RadioPolicyDialog(
        capabilities: capabilities,
        initial: draft,
      ),
    );
    if (policy == null || !mounted) return;
    await _runMutation(
      () => _controller.setAclRadioPolicy(policy, persist: _persist),
    );
  }

  Future<void> _editQos(
    WirelessAudioConfigurationCapabilities capabilities,
  ) async {
    final preferences =
        await showDialog<WirelessAudioConfigurationUnicastServerQosPreferences>(
      context: context,
      builder: (_) => _QosDialog(
        capabilities: capabilities,
        initial: _QosDraft.from(_controller.qos?.preferences, capabilities),
      ),
    );
    if (preferences == null || !mounted) return;
    await _runMutation(
      () => _controller.setQosPreferences(preferences, persist: _persist),
    );
  }

  Future<void> _confirmRestoreDefaults() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Restore audio defaults?'),
        content: const Text(
          'This clears persistent overrides for all supported wireless-audio sections.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Restore'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await _runMutation(_controller.restoreDefaults);
    }
  }

  Future<void> _runMutation(
    Future<WirelessAudioConfigurationCommandResult> Function() operation,
  ) async {
    try {
      final result = await operation();
      if (!mounted) return;
      AppToast.show(
        context,
        message: _resultMessage(result),
        type: AppToastType.success,
        icon: Icons.check_circle_outline_rounded,
      );
    } catch (error) {
      if (!mounted) return;
      AppToast.show(
        context,
        message: _errorMessage(error),
        type: AppToastType.error,
        icon: Icons.error_outline_rounded,
      );
    }
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.onRetry});

  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.bluetooth_disabled_rounded, size: 40),
            const SizedBox(height: 12),
            const Text('Could not read wireless-audio settings.'),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}

class _RuntimeStateCard extends StatelessWidget {
  const _RuntimeStateCard({required this.state});

  final WirelessAudioConfigurationRuntimeState state;

  @override
  Widget build(BuildContext context) {
    final rows = <(String, String)>[];
    if (_hasBit(state.validity_flags, 0)) {
      rows.add(('Connection', _lifecycleLabel(state.lifecycle_state)));
      rows.add(('ACL interval', _formatMicroseconds(state.acl_interval_us)));
    }
    if (_hasBit(state.validity_flags, 1)) {
      rows.add(
        (
          'ACL PHY',
          'TX ${_phyLabel(state.transmit_phy)} · RX ${_phyLabel(state.receive_phy)}',
        ),
      );
    }
    if (_hasBit(state.validity_flags, 3)) {
      rows.add(
        (
          'LC3',
          '${state.lc3_sampling_frequency_hz ~/ 1000} kHz · '
              '${_formatMicroseconds(state.lc3_frame_duration_us)} frames',
        ),
      );
    }
    if (_hasBit(state.validity_flags, 4)) {
      rows.add(
        (
          'ISO QoS',
          '${state.iso_maximum_sdu_octets} bytes · '
              '${state.iso_maximum_transport_latency_ms} ms latency',
        ),
      );
    }
    if (_hasBit(state.validity_flags, 6)) {
      rows.add(
        (
          'Diagnostics',
          '${state.audio_underrun_count} underruns · '
              '${state.acl_adjustment_count} ACL adjustments',
        ),
      );
    }

    return AppSectionCard(
      title: 'Effective runtime state',
      subtitle:
          'Read-only values negotiated by the Bluetooth controller and peer.',
      child: Column(
        children: [
          for (var index = 0; index < rows.length; index++) ...[
            _ValueRow(label: rows[index].$1, value: rows[index].$2),
            if (index < rows.length - 1) const Divider(height: 18),
          ],
        ],
      ),
    );
  }
}

class _ValueRow extends StatelessWidget {
  const _ValueRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(label)),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

enum _AclKind { controllerDefault, fixed, preferredRange, adaptiveLinear }

class _AclDraft {
  _AclDraft({
    required this.kind,
    required this.minimumInterval,
    required this.maximumInterval,
    required this.peripheralLatency,
    required this.supervisionTimeout,
    required this.underrunIncrease,
    required this.recoveryDecrease,
    required this.recoveryPeriod,
    required this.minimumUpdatePeriod,
  });

  _AclKind kind;
  int minimumInterval;
  int maximumInterval;
  int peripheralLatency;
  int supervisionTimeout;
  int underrunIncrease;
  int recoveryDecrease;
  int recoveryPeriod;
  int minimumUpdatePeriod;

  factory _AclDraft.from(
    WirelessAudioConfigurationAclConnectionPolicy? configured,
    WirelessAudioConfigurationCapabilities capabilities,
  ) {
    final policy = configured?.policy;
    var minimum = capabilities.minimum_acl_interval_us;
    var maximum = capabilities.maximum_acl_interval_us;
    var latency = 0;
    var timeout = capabilities.minimum_acl_supervision_timeout_ms;
    var increase = capabilities.acl_interval_resolution_us;
    var decrease = capabilities.acl_interval_resolution_us;
    var recovery = 1000;
    var update = 1000;
    var kind = _AclKind.controllerDefault;
    if (policy is WirelessAudioConfigurationFixedAclPolicy) {
      kind = _AclKind.fixed;
      minimum = maximum = policy.interval_us;
      latency = policy.peripheral_latency;
      timeout = policy.supervision_timeout_ms;
    } else if (policy is WirelessAudioConfigurationPreferredRangeAclPolicy) {
      kind = _AclKind.preferredRange;
      minimum = policy.minimum_interval_us;
      maximum = policy.maximum_interval_us;
      latency = policy.peripheral_latency;
      timeout = policy.supervision_timeout_ms;
    } else if (policy is WirelessAudioConfigurationAdaptiveLinearAclPolicy) {
      kind = _AclKind.adaptiveLinear;
      minimum = policy.minimum_interval_us;
      maximum = policy.maximum_interval_us;
      latency = policy.peripheral_latency;
      timeout = policy.supervision_timeout_ms;
      increase = policy.underrun_increase_step_us;
      decrease = policy.recovery_decrease_step_us;
      recovery = policy.recovery_period_ms;
      update = policy.minimum_update_period_ms;
    }
    return _AclDraft(
      kind: kind,
      minimumInterval: minimum,
      maximumInterval: maximum,
      peripheralLatency: latency,
      supervisionTimeout: timeout,
      underrunIncrease: increase,
      recoveryDecrease: decrease,
      recoveryPeriod: recovery,
      minimumUpdatePeriod: update,
    );
  }
}

class _AclPolicyDialog extends StatefulWidget {
  const _AclPolicyDialog({required this.capabilities, required this.initial});

  final WirelessAudioConfigurationCapabilities capabilities;
  final _AclDraft initial;

  @override
  State<_AclPolicyDialog> createState() => _AclPolicyDialogState();
}

class _AclPolicyDialogState extends State<_AclPolicyDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _AclDraft _draft = widget.initial;

  @override
  Widget build(BuildContext context) {
    final supportedKinds = _AclKind.values.where((kind) {
      return _hasBit(
        widget.capabilities.supported_acl_policy_mask,
        kind.index,
      );
    }).toList();
    if (!supportedKinds.contains(_draft.kind)) {
      _draft.kind = supportedKinds.first;
    }

    return _SettingsDialog(
      title: 'ACL connection',
      onSave: _save,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<_AclKind>(
              initialValue: _draft.kind,
              decoration: const InputDecoration(labelText: 'Policy'),
              items: [
                for (final kind in supportedKinds)
                  DropdownMenuItem(
                    value: kind,
                    child: Text(_aclKindLabel(kind)),
                  ),
              ],
              onChanged: (kind) => setState(() => _draft.kind = kind!),
            ),
            const SizedBox(height: 12),
            if (_draft.kind != _AclKind.controllerDefault) ...[
              if (_draft.kind != _AclKind.fixed)
                _IntegerField(
                  label: 'Minimum interval (µs)',
                  initialValue: _draft.minimumInterval,
                  onSaved: (value) => _draft.minimumInterval = value,
                  validator: _intervalValidator(widget.capabilities),
                ),
              _IntegerField(
                label: _draft.kind == _AclKind.fixed
                    ? 'Interval (µs)'
                    : 'Maximum interval (µs)',
                initialValue: _draft.kind == _AclKind.fixed
                    ? _draft.minimumInterval
                    : _draft.maximumInterval,
                onSaved: (value) {
                  if (_draft.kind == _AclKind.fixed) {
                    _draft.minimumInterval = _draft.maximumInterval = value;
                  } else {
                    _draft.maximumInterval = value;
                  }
                },
                validator: _intervalValidator(widget.capabilities),
              ),
              _IntegerField(
                label: 'Peripheral latency',
                initialValue: _draft.peripheralLatency,
                onSaved: (value) => _draft.peripheralLatency = value,
                validator: _rangeValidator(
                  0,
                  widget.capabilities.maximum_acl_peripheral_latency,
                ),
              ),
              _IntegerField(
                label: 'Supervision timeout (ms)',
                initialValue: _draft.supervisionTimeout,
                onSaved: (value) => _draft.supervisionTimeout = value,
                validator: _rangeValidator(
                  widget.capabilities.minimum_acl_supervision_timeout_ms,
                  widget.capabilities.maximum_acl_supervision_timeout_ms,
                ),
              ),
            ],
            if (_draft.kind == _AclKind.adaptiveLinear) ...[
              _IntegerField(
                label: 'Underrun increase step (µs)',
                initialValue: _draft.underrunIncrease,
                onSaved: (value) => _draft.underrunIncrease = value,
                validator: _positiveValidator,
              ),
              _IntegerField(
                label: 'Recovery decrease step (µs)',
                initialValue: _draft.recoveryDecrease,
                onSaved: (value) => _draft.recoveryDecrease = value,
                validator: _positiveValidator,
              ),
              _IntegerField(
                label: 'Recovery period (ms)',
                initialValue: _draft.recoveryPeriod,
                onSaved: (value) => _draft.recoveryPeriod = value,
                validator: _positiveValidator,
              ),
              _IntegerField(
                label: 'Minimum update period (ms)',
                initialValue: _draft.minimumUpdatePeriod,
                onSaved: (value) => _draft.minimumUpdatePeriod = value,
                validator: _positiveValidator,
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();
    if (_draft.minimumInterval > _draft.maximumInterval) {
      _showValidationError(
        context,
        'Minimum interval must not exceed maximum interval.',
      );
      return;
    }
    final requiredTimeout =
        (2 * (_draft.peripheralLatency + 1) * _draft.maximumInterval / 1000)
                .floor() +
            1;
    if (_draft.kind != _AclKind.controllerDefault &&
        _draft.supervisionTimeout < requiredTimeout) {
      _showValidationError(
        context,
        'Supervision timeout must be at least $requiredTimeout ms for this interval and latency.',
      );
      return;
    }

    final WirelessAudioConfigurationAclConnectionPolicy policy;
    switch (_draft.kind) {
      case _AclKind.controllerDefault:
        policy = WirelessAudioConfigurationAclConnectionPolicy
            .controllerDefaultAclPolicy(
          WirelessAudioConfigurationControllerDefaultAclPolicy(reserved: 0),
        );
      case _AclKind.fixed:
        policy = WirelessAudioConfigurationAclConnectionPolicy.fixedAclPolicy(
          WirelessAudioConfigurationFixedAclPolicy(
            interval_us: _draft.minimumInterval,
            peripheral_latency: _draft.peripheralLatency,
            supervision_timeout_ms: _draft.supervisionTimeout,
          ),
        );
      case _AclKind.preferredRange:
        policy = WirelessAudioConfigurationAclConnectionPolicy
            .preferredRangeAclPolicy(
          WirelessAudioConfigurationPreferredRangeAclPolicy(
            minimum_interval_us: _draft.minimumInterval,
            maximum_interval_us: _draft.maximumInterval,
            peripheral_latency: _draft.peripheralLatency,
            supervision_timeout_ms: _draft.supervisionTimeout,
          ),
        );
      case _AclKind.adaptiveLinear:
        policy = WirelessAudioConfigurationAclConnectionPolicy
            .adaptiveLinearAclPolicy(
          WirelessAudioConfigurationAdaptiveLinearAclPolicy(
            minimum_interval_us: _draft.minimumInterval,
            maximum_interval_us: _draft.maximumInterval,
            underrun_increase_step_us: _draft.underrunIncrease,
            recovery_decrease_step_us: _draft.recoveryDecrease,
            recovery_period_ms: _draft.recoveryPeriod,
            minimum_update_period_ms: _draft.minimumUpdatePeriod,
            peripheral_latency: _draft.peripheralLatency,
            supervision_timeout_ms: _draft.supervisionTimeout,
          ),
        );
    }
    Navigator.pop(context, policy);
  }
}

enum _RadioKind { automatic, preferred }

class _RadioDraft {
  _RadioDraft({
    required this.kind,
    required this.transmitPhyMask,
    required this.receivePhyMask,
    required this.dataOctets,
    required this.dataTime,
  });

  _RadioKind kind;
  int transmitPhyMask;
  int receivePhyMask;
  int dataOctets;
  int dataTime;

  factory _RadioDraft.from(
    WirelessAudioConfigurationAclRadioPolicy? configured,
    WirelessAudioConfigurationCapabilities capabilities,
  ) {
    final policy = configured?.policy;
    if (policy is WirelessAudioConfigurationPreferredAclRadioPolicy) {
      return _RadioDraft(
        kind: _RadioKind.preferred,
        transmitPhyMask: policy.transmit_phy_mask,
        receivePhyMask: policy.receive_phy_mask,
        dataOctets: policy.transmit_max_data_octets,
        dataTime: policy.transmit_max_time_us,
      );
    }
    return _RadioDraft(
      kind: _RadioKind.automatic,
      transmitPhyMask: capabilities.supported_phy_mask,
      receivePhyMask: capabilities.supported_phy_mask,
      dataOctets: 0,
      dataTime: 0,
    );
  }
}

class _RadioPolicyDialog extends StatefulWidget {
  const _RadioPolicyDialog({required this.capabilities, required this.initial});

  final WirelessAudioConfigurationCapabilities capabilities;
  final _RadioDraft initial;

  @override
  State<_RadioPolicyDialog> createState() => _RadioPolicyDialogState();
}

class _RadioPolicyDialogState extends State<_RadioPolicyDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _RadioDraft _draft = widget.initial;

  @override
  Widget build(BuildContext context) {
    return _SettingsDialog(
      title: 'ACL radio',
      onSave: _save,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<_RadioKind>(
              initialValue: _draft.kind,
              decoration: const InputDecoration(labelText: 'Policy'),
              items: const [
                DropdownMenuItem(
                  value: _RadioKind.automatic,
                  child: Text('Automatic'),
                ),
                DropdownMenuItem(
                  value: _RadioKind.preferred,
                  child: Text('Preferred values'),
                ),
              ],
              onChanged: (value) => setState(() => _draft.kind = value!),
            ),
            if (_draft.kind == _RadioKind.preferred) ...[
              const SizedBox(height: 16),
              _PhySelector(
                label: 'Transmit PHY',
                supportedMask: widget.capabilities.supported_phy_mask,
                value: _draft.transmitPhyMask,
                onChanged: (value) =>
                    setState(() => _draft.transmitPhyMask = value),
              ),
              _PhySelector(
                label: 'Receive PHY',
                supportedMask: widget.capabilities.supported_phy_mask,
                value: _draft.receivePhyMask,
                onChanged: (value) =>
                    setState(() => _draft.receivePhyMask = value),
              ),
              _IntegerField(
                label: 'Maximum TX data octets (0 = automatic)',
                initialValue: _draft.dataOctets,
                onSaved: (value) => _draft.dataOctets = value,
                validator: _zeroOrRangeValidator(
                  widget.capabilities.minimum_acl_data_octets,
                  widget.capabilities.maximum_acl_data_octets,
                ),
              ),
              _IntegerField(
                label: 'Maximum TX time in µs (0 = automatic)',
                initialValue: _draft.dataTime,
                onSaved: (value) => _draft.dataTime = value,
                validator: _zeroOrRangeValidator(
                  widget.capabilities.minimum_acl_data_time_us,
                  widget.capabilities.maximum_acl_data_time_us,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();
    final policy = _draft.kind == _RadioKind.automatic
        ? WirelessAudioConfigurationAclRadioPolicy.automaticAclRadioPolicy(
            WirelessAudioConfigurationAutomaticAclRadioPolicy(reserved: 0),
          )
        : WirelessAudioConfigurationAclRadioPolicy.preferredAclRadioPolicy(
            WirelessAudioConfigurationPreferredAclRadioPolicy(
              transmit_phy_mask: _draft.transmitPhyMask,
              receive_phy_mask: _draft.receivePhyMask,
              transmit_max_data_octets: _draft.dataOctets,
              transmit_max_time_us: _draft.dataTime,
            ),
          );
    Navigator.pop(context, policy);
  }
}

class _QosDraft {
  _QosDraft({
    required this.directionMask,
    required this.unframed,
    required this.phyMask,
    required this.retransmissions,
    required this.transportLatency,
    required this.minimumDelay,
    required this.maximumDelay,
    required this.preferredMinimumDelay,
    required this.preferredMaximumDelay,
  });

  int directionMask;
  bool unframed;
  int phyMask;
  int retransmissions;
  int transportLatency;
  int minimumDelay;
  int maximumDelay;
  int preferredMinimumDelay;
  int preferredMaximumDelay;

  factory _QosDraft.from(
    WirelessAudioConfigurationUnicastServerQosPreferences? configured,
    WirelessAudioConfigurationCapabilities capabilities,
  ) {
    return _QosDraft(
      directionMask: configured?.direction_mask ??
          capabilities.supported_audio_direction_mask,
      unframed: configured?.unframed_supported == 1,
      phyMask:
          configured?.preferred_phy_mask ?? capabilities.supported_phy_mask,
      retransmissions: configured?.preferred_retransmission_number ?? 0,
      transportLatency: configured?.maximum_transport_latency_ms ?? 0,
      minimumDelay: configured?.minimum_presentation_delay_us ??
          capabilities.minimum_presentation_delay_us,
      maximumDelay: configured?.maximum_presentation_delay_us ??
          capabilities.maximum_presentation_delay_us,
      preferredMinimumDelay:
          configured?.preferred_minimum_presentation_delay_us ??
              capabilities.minimum_presentation_delay_us,
      preferredMaximumDelay:
          configured?.preferred_maximum_presentation_delay_us ??
              capabilities.maximum_presentation_delay_us,
    );
  }
}

class _QosDialog extends StatefulWidget {
  const _QosDialog({required this.capabilities, required this.initial});

  final WirelessAudioConfigurationCapabilities capabilities;
  final _QosDraft initial;

  @override
  State<_QosDialog> createState() => _QosDialogState();
}

class _QosDialogState extends State<_QosDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _QosDraft _draft = widget.initial;

  @override
  Widget build(BuildContext context) {
    return _SettingsDialog(
      title: 'Unicast Server QoS',
      onSave: _save,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Directions', style: Theme.of(context).textTheme.titleSmall),
            _MaskCheckbox(
              label: 'Sink (audio received by device)',
              bit: 0,
              supportedMask: widget.capabilities.supported_audio_direction_mask,
              value: _draft.directionMask,
              onChanged: (value) =>
                  setState(() => _draft.directionMask = value),
            ),
            _MaskCheckbox(
              label: 'Source (audio sent by device)',
              bit: 1,
              supportedMask: widget.capabilities.supported_audio_direction_mask,
              value: _draft.directionMask,
              onChanged: (value) =>
                  setState(() => _draft.directionMask = value),
            ),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('Unframed ISO supported'),
              value: _draft.unframed,
              onChanged: (value) => setState(() => _draft.unframed = value),
            ),
            _PhySelector(
              label: 'Preferred PHY',
              supportedMask: widget.capabilities.supported_phy_mask,
              value: _draft.phyMask,
              onChanged: (value) => setState(() => _draft.phyMask = value),
            ),
            _IntegerField(
              label: 'Preferred retransmissions',
              initialValue: _draft.retransmissions,
              onSaved: (value) => _draft.retransmissions = value,
              validator: _rangeValidator(
                0,
                widget.capabilities.maximum_preferred_retransmission_number,
              ),
            ),
            _IntegerField(
              label: 'Maximum transport latency (ms)',
              initialValue: _draft.transportLatency,
              onSaved: (value) => _draft.transportLatency = value,
              validator: _rangeValidator(
                0,
                widget.capabilities.maximum_transport_latency_ms,
              ),
            ),
            _IntegerField(
              label: 'Minimum presentation delay (µs)',
              initialValue: _draft.minimumDelay,
              onSaved: (value) => _draft.minimumDelay = value,
              validator: _rangeValidator(
                widget.capabilities.minimum_presentation_delay_us,
                widget.capabilities.maximum_presentation_delay_us,
              ),
            ),
            _IntegerField(
              label: 'Maximum presentation delay (µs)',
              initialValue: _draft.maximumDelay,
              onSaved: (value) => _draft.maximumDelay = value,
              validator: _rangeValidator(
                widget.capabilities.minimum_presentation_delay_us,
                widget.capabilities.maximum_presentation_delay_us,
              ),
            ),
            _IntegerField(
              label: 'Preferred minimum delay (µs)',
              initialValue: _draft.preferredMinimumDelay,
              onSaved: (value) => _draft.preferredMinimumDelay = value,
              validator: _rangeValidator(
                widget.capabilities.minimum_presentation_delay_us,
                widget.capabilities.maximum_presentation_delay_us,
              ),
            ),
            _IntegerField(
              label: 'Preferred maximum delay (µs)',
              initialValue: _draft.preferredMaximumDelay,
              onSaved: (value) => _draft.preferredMaximumDelay = value,
              validator: _rangeValidator(
                widget.capabilities.minimum_presentation_delay_us,
                widget.capabilities.maximum_presentation_delay_us,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();
    if (_draft.directionMask == 0) {
      _showValidationError(context, 'Select at least one supported direction.');
      return;
    }
    if (_draft.minimumDelay > _draft.maximumDelay ||
        _draft.preferredMinimumDelay > _draft.preferredMaximumDelay ||
        _draft.preferredMinimumDelay < _draft.minimumDelay ||
        _draft.preferredMaximumDelay > _draft.maximumDelay) {
      _showValidationError(
        context,
        'Preferred delays must form a valid range inside the supported delay range.',
      );
      return;
    }
    Navigator.pop(
      context,
      WirelessAudioConfigurationUnicastServerQosPreferences(
        direction_mask: _draft.directionMask,
        unframed_supported: _draft.unframed ? 1 : 0,
        preferred_phy_mask: _draft.phyMask,
        preferred_retransmission_number: _draft.retransmissions,
        maximum_transport_latency_ms: _draft.transportLatency,
        minimum_presentation_delay_us: _draft.minimumDelay,
        maximum_presentation_delay_us: _draft.maximumDelay,
        preferred_minimum_presentation_delay_us: _draft.preferredMinimumDelay,
        preferred_maximum_presentation_delay_us: _draft.preferredMaximumDelay,
      ),
    );
  }
}

class _SettingsDialog extends StatelessWidget {
  const _SettingsDialog({
    required this.title,
    required this.child,
    required this.onSave,
  });

  final String title;
  final Widget child;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(title),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(child: child),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: onSave, child: const Text('Apply')),
      ],
    );
  }
}

class _IntegerField extends StatelessWidget {
  const _IntegerField({
    required this.label,
    required this.initialValue,
    required this.onSaved,
    required this.validator,
  });

  final String label;
  final int initialValue;
  final ValueChanged<int> onSaved;
  final String? Function(String?) validator;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        initialValue: '$initialValue',
        decoration: InputDecoration(labelText: label),
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        validator: validator,
        onSaved: (value) => onSaved(int.parse(value!)),
      ),
    );
  }
}

class _PhySelector extends StatelessWidget {
  const _PhySelector({
    required this.label,
    required this.supportedMask,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final int supportedMask;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.titleSmall),
          for (final entry in const [
            (0, 'LE 1M'),
            (1, 'LE 2M'),
            (2, 'LE Coded'),
          ])
            _MaskCheckbox(
              label: entry.$2,
              bit: entry.$1,
              supportedMask: supportedMask,
              value: value,
              onChanged: onChanged,
            ),
          Text(
            'No selection leaves PHY choice automatic.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _MaskCheckbox extends StatelessWidget {
  const _MaskCheckbox({
    required this.label,
    required this.bit,
    required this.supportedMask,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final int bit;
  final int supportedMask;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final mask = 1 << bit;
    final supported = supportedMask & mask != 0;
    return CheckboxListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      title: Text(label),
      value: value & mask != 0,
      onChanged: supported
          ? (selected) => onChanged(selected! ? value | mask : value & ~mask)
          : null,
    );
  }
}

String? Function(String?) _intervalValidator(
  WirelessAudioConfigurationCapabilities capabilities,
) {
  return (value) {
    final rangeError = _rangeValidator(
      capabilities.minimum_acl_interval_us,
      capabilities.maximum_acl_interval_us,
    )(value);
    if (rangeError != null) return rangeError;
    final parsed = int.parse(value!);
    if (parsed % capabilities.acl_interval_resolution_us != 0) {
      return 'Use increments of ${capabilities.acl_interval_resolution_us} µs';
    }
    return null;
  };
}

String? Function(String?) _rangeValidator(int minimum, int maximum) {
  return (value) {
    final parsed = int.tryParse(value ?? '');
    if (parsed == null) return 'Enter a whole number';
    if (parsed < minimum || parsed > maximum) return 'Use $minimum–$maximum';
    return null;
  };
}

String? Function(String?) _zeroOrRangeValidator(int minimum, int maximum) {
  return (value) {
    final parsed = int.tryParse(value ?? '');
    if (parsed == null) return 'Enter a whole number';
    if (parsed == 0) return null;
    if (parsed < minimum || parsed > maximum) {
      return 'Use 0 or $minimum–$maximum';
    }
    return null;
  };
}

String? _positiveValidator(String? value) {
  final parsed = int.tryParse(value ?? '');
  if (parsed == null || parsed <= 0) return 'Enter a value greater than zero';
  return null;
}

void _showValidationError(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

bool _hasBit(int mask, int bit) => mask & (1 << bit) != 0;

bool _supportsSection(WirelessAudioConfigurationCapabilities value, int bit) =>
    _hasBit(value.supported_section_mask, bit);

bool _supportsCommand(WirelessAudioConfigurationCapabilities value, int bit) =>
    _hasBit(value.supported_command_mask, bit);

String _aclSummary(WirelessAudioConfigurationAclConnectionPolicy? value) {
  final policy = value?.policy;
  if (policy is WirelessAudioConfigurationFixedAclPolicy) {
    return 'Fixed · ${_formatMicroseconds(policy.interval_us)}';
  }
  if (policy is WirelessAudioConfigurationPreferredRangeAclPolicy) {
    return 'Preferred · ${_formatMicroseconds(policy.minimum_interval_us)}–'
        '${_formatMicroseconds(policy.maximum_interval_us)}';
  }
  if (policy is WirelessAudioConfigurationAdaptiveLinearAclPolicy) {
    return 'Adaptive · ${_formatMicroseconds(policy.minimum_interval_us)}–'
        '${_formatMicroseconds(policy.maximum_interval_us)}';
  }
  if (policy is WirelessAudioConfigurationControllerDefaultAclPolicy) {
    return 'Controller default';
  }
  return 'Configuration unavailable';
}

String _radioSummary(WirelessAudioConfigurationAclRadioPolicy? value) {
  final policy = value?.policy;
  if (policy is WirelessAudioConfigurationPreferredAclRadioPolicy) {
    return 'Preferred · TX ${_phyMaskLabel(policy.transmit_phy_mask)} · '
        'RX ${_phyMaskLabel(policy.receive_phy_mask)}';
  }
  if (policy is WirelessAudioConfigurationAutomaticAclRadioPolicy) {
    return 'Automatic';
  }
  return 'Configuration unavailable';
}

String _qosSummary(
  WirelessAudioConfigurationUnicastServerQosPreferences? value,
) {
  if (value == null) return 'Configuration unavailable';
  final directions = <String>[
    if (_hasBit(value.direction_mask, 0)) 'sink',
    if (_hasBit(value.direction_mask, 1)) 'source',
  ].join(' + ');
  return '${directions.isEmpty ? 'No direction' : directions} · '
      '${value.maximum_transport_latency_ms} ms max latency';
}

String _aclKindLabel(_AclKind kind) => switch (kind) {
      _AclKind.controllerDefault => 'Controller default',
      _AclKind.fixed => 'Fixed interval',
      _AclKind.preferredRange => 'Preferred range',
      _AclKind.adaptiveLinear => 'Adaptive linear',
    };

String _formatMicroseconds(int value) {
  if (value % 1000 == 0) return '${value ~/ 1000} ms';
  return '${value / 1000} ms';
}

String _phyMaskLabel(int mask) {
  final labels = <String>[
    if (_hasBit(mask, 0)) '1M',
    if (_hasBit(mask, 1)) '2M',
    if (_hasBit(mask, 2)) 'Coded',
  ];
  return labels.isEmpty ? 'auto' : labels.join('/');
}

String _phyLabel(int value) => switch (value) {
      1 => '1M',
      2 => '2M',
      3 => 'Coded',
      _ => 'unknown ($value)',
    };

String _lifecycleLabel(int value) => switch (value) {
      0 => 'Disconnected',
      1 => 'Connected',
      2 => 'Codec configured',
      3 => 'QoS configured',
      4 => 'Enabled',
      5 => 'Streaming',
      6 => 'Releasing',
      _ => 'Unknown ($value)',
    };

String _resultMessage(WirelessAudioConfigurationCommandResult result) {
  final message = switch (result.status) {
    0 => 'Wireless-audio settings applied.',
    1 => 'Wireless-audio settings accepted and pending.',
    2 => 'Settings saved. Reconnect audio to apply them.',
    3 => 'Settings saved. Restart the audio stream to apply them.',
    _ => 'Wireless-audio settings updated.',
  };
  return message;
}

String _errorMessage(Object error) {
  if (error is WirelessAudioConfigurationException) {
    return switch (error.result.status) {
      4 => 'This setting is not supported by the device.',
      5 => 'The device rejected an invalid combination of values.',
      6 => 'The device is busy. Try again shortly.',
      _ => 'The device could not apply the wireless-audio setting.',
    };
  }
  return 'Could not update wireless-audio settings.';
}
