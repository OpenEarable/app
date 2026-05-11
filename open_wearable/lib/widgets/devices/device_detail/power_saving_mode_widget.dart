import 'package:flutter/material.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart';
import 'package:open_wearable/view_models/wearables_provider.dart';
import 'package:provider/provider.dart';

import 'stereo_pair_option_selector.dart';

/// Selects the firmware-defined power saving mode for a wearable.
class PowerSavingModeWidget extends StatefulWidget {
  /// The wearable whose power saving mode should be configured.
  final Wearable device;

  /// Defines whether the selection can target the paired device.
  final StereoPairApplyScope applyScope;

  /// Explicit paired wearable used by combined stereo-pair surfaces.
  final Wearable? pairedDeviceOverride;

  const PowerSavingModeWidget({
    super.key,
    required this.device,
    this.applyScope = StereoPairApplyScope.userSelectable,
    this.pairedDeviceOverride,
  });

  @override
  State<PowerSavingModeWidget> createState() => _PowerSavingModeWidgetState();
}

class _PowerSavingModeWidgetState extends State<PowerSavingModeWidget> {
  List<PowerSavingMode> _supportedModes = const [];
  PowerSavingMode? _selectedMode;
  PowerSavingMode? _primaryMode;
  PowerSavingMode? _pairedMode;
  PowerSavingModeManager? _pairedManager;
  Wearable? _pairedWearable;
  bool _pairModesDiffer = false;
  bool _isLoading = true;
  bool _isApplying = false;
  bool _applyToStereoPair = false;
  String? _errorText;

  PowerSavingModeManager get _manager =>
      widget.device.requireCapability<PowerSavingModeManager>();

  @override
  void initState() {
    super.initState();
    _loadState();
  }

  @override
  void didUpdateWidget(covariant PowerSavingModeWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.device != widget.device ||
        oldWidget.applyScope != widget.applyScope ||
        oldWidget.pairedDeviceOverride != widget.pairedDeviceOverride) {
      _loadState();
    }
  }

  Future<void> _loadState() async {
    setState(() {
      _isLoading = true;
      _isApplying = false;
      _errorText = null;
    });

    final wearables = context.read<WearablesProvider>().wearables;

    try {
      final supportedModes = await _manager.readSupportedPowerSavingModes();
      final primaryMode = await _manager.readPowerSavingMode();
      final pairedWearable = await _findPairedWearable(wearables: wearables);

      PowerSavingModeManager? pairedManager;
      PowerSavingMode? pairedMode;
      if (pairedWearable != null &&
          pairedWearable.hasCapability<PowerSavingModeManager>()) {
        pairedManager =
            pairedWearable.requireCapability<PowerSavingModeManager>();
        pairedMode = await pairedManager.readPowerSavingMode();
      }

      final pairModesDiffer =
          pairedMode != null && pairedMode.id != primaryMode.id;

      if (!mounted) {
        return;
      }

      setState(() {
        _supportedModes = supportedModes;
        _selectedMode = pairModesDiffer &&
                widget.applyScope == StereoPairApplyScope.pairOnly
            ? null
            : _modeFromList(supportedModes, primaryMode);
        _primaryMode = primaryMode;
        _pairedMode = pairedMode;
        _pairedManager = pairedManager;
        _pairedWearable = pairedWearable;
        _pairModesDiffer = pairModesDiffer;
        _applyToStereoPair = switch (widget.applyScope) {
          StereoPairApplyScope.pairOnly => pairedManager != null,
          StereoPairApplyScope.individualOnly => false,
          StereoPairApplyScope.userSelectable => pairedManager != null,
        };
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorText =
            'Failed to load power saving mode: ${_describeError(error)}';
        _isLoading = false;
      });
    }
  }

  PowerSavingMode _modeFromList(
    List<PowerSavingMode> modes,
    PowerSavingMode mode,
  ) {
    return modes.firstWhere(
      (candidate) => candidate.id == mode.id,
      orElse: () => mode,
    );
  }

  Future<Wearable?> _findPairedWearable({
    required List<Wearable> wearables,
  }) async {
    final pairedDeviceOverride = widget.pairedDeviceOverride;
    if (pairedDeviceOverride != null &&
        pairedDeviceOverride.deviceId != widget.device.deviceId) {
      return pairedDeviceOverride;
    }

    if (!widget.device.hasCapability<StereoDevice>()) {
      return null;
    }

    final pairedStereo =
        await widget.device.requireCapability<StereoDevice>().pairedDevice;
    if (pairedStereo == null) {
      return null;
    }

    for (final candidate in wearables) {
      if (candidate.deviceId == widget.device.deviceId) {
        continue;
      }
      if (!candidate.hasCapability<StereoDevice>()) {
        continue;
      }
      if (identical(
        candidate.requireCapability<StereoDevice>(),
        pairedStereo,
      )) {
        return candidate;
      }
    }

    return null;
  }

  Future<bool> _managerSupportsMode(
    PowerSavingModeManager manager,
    PowerSavingMode mode,
  ) async {
    final modes = await manager.readSupportedPowerSavingModes();
    return modes.any((candidate) => candidate.id == mode.id);
  }

  Future<void> _onModeSelected(PowerSavingMode? mode) async {
    if (mode == null || _isApplying || _isLoading) {
      return;
    }

    final previousSelection = _selectedMode;
    final previousPrimaryMode = _primaryMode;
    final previousPairedMode = _pairedMode;
    final previousPairModesDiffer = _pairModesDiffer;
    final shouldApplyToPair = switch (widget.applyScope) {
      StereoPairApplyScope.pairOnly => true,
      StereoPairApplyScope.individualOnly => false,
      StereoPairApplyScope.userSelectable => _applyToStereoPair,
    };
    final pairedManager = shouldApplyToPair ? _pairedManager : null;

    setState(() {
      _selectedMode = mode;
      _primaryMode = mode;
      if (pairedManager != null) {
        _pairedMode = mode;
      }
      _pairModesDiffer = false;
      _isApplying = true;
      _errorText = null;
    });

    var primaryApplied = false;
    try {
      await _manager.setPowerSavingMode(mode);
      primaryApplied = true;

      if (pairedManager != null) {
        if (!await _managerSupportsMode(pairedManager, mode)) {
          throw StateError(
            'Paired device does not support ${mode.name}.',
          );
        }
        await pairedManager.setPowerSavingMode(mode);
      }
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        if (!primaryApplied || pairedManager == null) {
          _selectedMode = previousSelection;
          _primaryMode = previousPrimaryMode;
          _pairedMode = previousPairedMode;
          _pairModesDiffer = previousPairModesDiffer;
        } else if (widget.applyScope == StereoPairApplyScope.pairOnly) {
          _selectedMode = null;
          _primaryMode = mode;
          _pairedMode = previousPairedMode;
          _pairModesDiffer = true;
        }

        final detail = _describeError(error);
        _errorText = primaryApplied && pairedManager != null
            ? 'Applied to this device, but failed on paired device: $detail'
            : 'Failed to apply power saving mode: $detail';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isApplying = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pairName = _pairedWearable?.name;
    final selectedValue = _selectedMode == null
        ? null
        : _supportedModes
            .where((mode) => mode.id == _selectedMode!.id)
            .firstOrNull;

    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Power Saving Mode',
                  style: theme.textTheme.titleSmall,
                ),
              ),
              if (_isLoading)
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: theme.colorScheme.primary,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Choose the idle auto-off behavior.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (_pairedManager != null &&
              widget.applyScope == StereoPairApplyScope.userSelectable) ...[
            const SizedBox(height: 4),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              dense: true,
              value: _applyToStereoPair,
              onChanged: _isApplying || _isLoading
                  ? null
                  : (value) {
                      setState(() {
                        _applyToStereoPair = value;
                      });
                    },
              title: const Text('Apply to stereo pair'),
              subtitle: Text(
                _applyToStereoPair
                    ? pairName == null
                        ? 'Left and right devices change together.'
                        : 'Also update $pairName.'
                    : 'Only update this device.',
              ),
            ),
          ],
          const SizedBox(height: 8),
          DropdownButtonFormField<PowerSavingMode>(
            key: ValueKey(selectedValue?.id),
            initialValue: selectedValue,
            isExpanded: true,
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
              prefixIcon: const Icon(Icons.power_settings_new_rounded),
              enabled: !_isApplying && !_isLoading,
            ),
            hint: Text(
              _pairModesDiffer &&
                      widget.applyScope == StereoPairApplyScope.pairOnly
                  ? 'Left and right use different modes'
                  : 'Select mode',
            ),
            items: _supportedModes
                .map(
                  (mode) => DropdownMenuItem<PowerSavingMode>(
                    value: mode,
                    child: Text(
                      mode.name,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(),
            onChanged: _isApplying || _isLoading ? null : _onModeSelected,
          ),
          if (_pairModesDiffer &&
              _pairedMode != null &&
              widget.applyScope != StereoPairApplyScope.individualOnly) ...[
            const SizedBox(height: 8),
            Text(
              'Paired device currently uses ${_pairedMode!.name}.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          if (_isApplying) ...[
            const SizedBox(height: 8),
            const LinearProgressIndicator(minHeight: 2),
          ],
          if (_errorText != null) ...[
            const SizedBox(height: 8),
            Text(
              _errorText!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

String _describeError(Object error) {
  final text = error.toString().trim();
  if (text.startsWith('Exception: ')) {
    return text.substring('Exception: '.length);
  }
  if (text.startsWith('StateError: ')) {
    return text.substring('StateError: '.length);
  }
  return text;
}
