import 'package:flutter/material.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart';
import 'package:open_wearable/view_models/wearables_provider.dart';
import 'package:provider/provider.dart';

import 'stereo_pair_option_selector.dart';

/// Selects the firmware-defined power saving mode for a wearable.
class PowerSavingModeWidget extends StatefulWidget {
  final Wearable device;
  final StereoPairApplyScope applyScope;

  const PowerSavingModeWidget({
    super.key,
    required this.device,
    this.applyScope = StereoPairApplyScope.userSelectable,
  });

  @override
  State<PowerSavingModeWidget> createState() => _PowerSavingModeWidgetState();
}

class _PowerSavingModeWidgetState extends State<PowerSavingModeWidget> {
  late Future<Map<String, List<PowerSavingMode>>> _modesByDeviceFuture;

  @override
  void initState() {
    super.initState();
    _modesByDeviceFuture = _loadSupportedModes();
  }

  @override
  void didUpdateWidget(covariant PowerSavingModeWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.device != widget.device ||
        oldWidget.applyScope != widget.applyScope) {
      _modesByDeviceFuture = _loadSupportedModes();
    }
  }

  Future<Map<String, List<PowerSavingMode>>> _loadSupportedModes() async {
    final wearables = context.read<WearablesProvider>().wearables;
    final modesByDevice = <String, List<PowerSavingMode>>{};
    final manager = widget.device.requireCapability<PowerSavingModeManager>();
    modesByDevice[widget.device.deviceId] =
        await manager.readSupportedPowerSavingModes();

    final pairedWearable = await _findPairedWearable(wearables);
    if (pairedWearable != null &&
        pairedWearable.hasCapability<PowerSavingModeManager>()) {
      modesByDevice[pairedWearable.deviceId] = await pairedWearable
          .requireCapability<PowerSavingModeManager>()
          .readSupportedPowerSavingModes();
    }

    return modesByDevice;
  }

  Future<Wearable?> _findPairedWearable(List<Wearable> wearables) async {
    if (!widget.device.hasCapability<StereoDevice>()) {
      return null;
    }

    final pairedStereo =
        await widget.device.requireCapability<StereoDevice>().pairedDevice;
    if (pairedStereo == null) {
      return null;
    }

    for (final wearable in wearables) {
      if (wearable.deviceId == widget.device.deviceId ||
          !wearable.hasCapability<StereoDevice>()) {
        continue;
      }
      if (identical(wearable.requireCapability<StereoDevice>(), pairedStereo)) {
        return wearable;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, List<PowerSavingMode>>>(
      future: _modesByDeviceFuture,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _PowerSavingModeStatus(
            trailing: null,
            errorText:
                'Failed to load power saving mode: ${_describeError(snapshot.error!)}',
          );
        }

        final modesByDevice = snapshot.data;
        if (modesByDevice == null) {
          return const _PowerSavingModeStatus(
            trailing: SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }

        return StereoPairOptionSelector<PowerSavingMode, _PowerSavingModeData>(
          device: widget.device,
          applyScope: widget.applyScope,
          title: 'Power Saving Mode',
          description: 'Choose the idle auto-off behavior.',
          supportsSetting: (wearable) =>
              wearable.hasCapability<PowerSavingModeManager>(),
          managerFor: (wearable) => _PowerSavingModeData(
            manager: wearable.requireCapability<PowerSavingModeManager>(),
            modes: modesByDevice[wearable.deviceId] ?? const [],
          ),
          readSelection: (data) => data.manager.readPowerSavingMode(),
          applySelection: (data, mode) => data.manager.setPowerSavingMode(mode),
          optionsFor: (data) => data.modes,
          supportsOption: (data, mode) =>
              data.modes.any((candidate) => _modesEqualById(candidate, mode)),
          equalsSelection: _modesEqualById,
          optionLabel: (mode) => mode.name,
          optionIcon: (_) => Icons.battery_saver_rounded,
          loadErrorText: (error) =>
              'Failed to load power saving mode: ${_describeError(error)}',
          applyErrorText: (
            error, {
            required bool primaryApplied,
            required bool appliedToPair,
          }) {
            final detail = _describeError(error);
            if (primaryApplied && appliedToPair) {
              return 'Applied to this device, but failed on paired device: $detail';
            }
            return 'Failed to apply power saving mode: $detail';
          },
        );
      },
    );
  }
}

class _PowerSavingModeData {
  final PowerSavingModeManager manager;
  final List<PowerSavingMode> modes;

  const _PowerSavingModeData({
    required this.manager,
    required this.modes,
  });
}

class _PowerSavingModeStatus extends StatelessWidget {
  final Widget? trailing;
  final String? errorText;

  const _PowerSavingModeStatus({
    this.trailing,
    this.errorText,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Choose the idle auto-off behavior.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (errorText != null) ...[
            const SizedBox(height: 8),
            Text(
              errorText!,
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

bool _modesEqualById(PowerSavingMode? a, PowerSavingMode b) {
  return a != null && a.id == b.id;
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
