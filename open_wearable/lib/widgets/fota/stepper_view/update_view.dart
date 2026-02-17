import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart';
import 'package:open_wearable/models/fota_post_update_verification.dart';
import 'package:open_wearable/widgets/app_banner.dart';
import 'package:open_wearable/widgets/fota/fota_verification_banner.dart';

import '../logger_screen/logger_screen.dart';

class UpdateStepView extends StatefulWidget {
  final bool autoStart;
  final ValueChanged<bool>? onUpdateRunningChanged;
  final String? preResolvedWearableName;
  final String? preResolvedSideLabel;

  const UpdateStepView({
    super.key,
    this.autoStart = true,
    this.onUpdateRunningChanged,
    this.preResolvedWearableName,
    this.preResolvedSideLabel,
  });

  @override
  State<UpdateStepView> createState() => _UpdateStepViewState();
}

class _UpdateStepViewState extends State<UpdateStepView> {
  static const Color _successGreen = Color(0xFF2E7D32);

  bool _lastReportedRunning = false;
  bool _startRequested = false;
  bool _verificationBannerShown = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final bloc = context.read<UpdateBloc>();
      final state = bloc.state;
      if (widget.autoStart && state is UpdateInitial) {
        setState(() {
          _startRequested = true;
        });
        _reportRunningState(true);
        bloc.add(BeginUpdateProcess());
        return;
      }
      _reportRunningState(_isUpdateInProgress(state));
    });
  }

  @override
  void dispose() {
    if (_lastReportedRunning) {
      widget.onUpdateRunningChanged?.call(false);
    }
    super.dispose();
  }

  void _reportRunningState(bool running) {
    if (_lastReportedRunning == running) {
      return;
    }
    _lastReportedRunning = running;
    if (!running && _startRequested) {
      setState(() {
        _startRequested = false;
      });
    }
    widget.onUpdateRunningChanged?.call(running);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FirmwareUpdateRequestProvider>();
    final request = provider.updateParameters;

    return BlocConsumer<UpdateBloc, UpdateState>(
      listener: (context, state) async {
        _reportRunningState(_isUpdateInProgress(state));
        if (state is UpdateFirmwareStateHistory &&
            state.isComplete &&
            state.history.isNotEmpty &&
            state.history.last is UpdateCompleteSuccess) {
          if (_verificationBannerShown) {
            return;
          }
          _verificationBannerShown = true;
          final updateProvider = context.read<FirmwareUpdateRequestProvider>();
          final armedVerification = await FotaPostUpdateVerificationCoordinator
              .instance
              .armFromUpdateRequest(
            request: updateProvider.updateParameters,
            selectedWearable: updateProvider.selectedWearable,
            preResolvedWearableName: widget.preResolvedWearableName,
            preResolvedSideLabel: widget.preResolvedSideLabel,
          );
          if (!mounted || armedVerification == null) {
            return;
          }
          showFotaVerificationBanner(
            this.context,
            verificationId: armedVerification.verificationId,
            wearableName: armedVerification.wearableName,
            sideLabel: armedVerification.sideLabel,
          );
        }
      },
      builder: (context, state) {
        return switch (state) {
          UpdateInitial() => _buildInitial(context, request),
          UpdateFirmwareStateHistory() => _buildHistory(context, state),
          UpdateFirmware() => _buildPendingState(context, state.stage),
        };
      },
    );
  }

  bool _isUpdateInProgress(UpdateState state) {
    if (state is UpdateInitial) {
      return false;
    }
    if (state is UpdateFirmwareStateHistory) {
      return !state.isComplete;
    }
    return true;
  }

  Widget _buildInitial(
    BuildContext context,
    FirmwareUpdateRequest request,
  ) {
    final firmware = request.firmware;
    if (firmware == null) {
      return Text(
        'No firmware selected. Go back and choose firmware.',
        style: Theme.of(context).textTheme.bodyMedium,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _firmwareInfoCard(context, firmware),
        const SizedBox(height: 12),
        _buildPendingState(context, 'Starting update...'),
      ],
    );
  }

  Widget _buildPendingState(BuildContext context, String stage) {
    const neutralBackground = Color(0xFFF5F6F7);
    const neutralBorder = Color(0xFFD4D8DE);
    const neutralForeground = Color(0xFF5E6572);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: neutralBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: neutralBorder),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: neutralForeground,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              stage,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistory(
    BuildContext context,
    UpdateFirmwareStateHistory state,
  ) {
    final history = state.history;
    final currentState = state.currentState;
    final showSuccessMessage = state.isComplete &&
        history.isNotEmpty &&
        history.last is UpdateCompleteSuccess;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final entry in history) ...[
          _historyEntry(context, entry),
          const SizedBox(height: 8),
        ],
        if (currentState != null) ...[
          _currentStatePanel(context, state),
          const SizedBox(height: 10),
        ],
        if (showSuccessMessage) ...[
          _successPanel(context),
          const SizedBox(height: 10),
        ],
        if (state.isComplete && state.updateManager?.logger != null) ...[
          OutlinedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => LoggerScreen(
                    logger: state.updateManager!.logger,
                  ),
                ),
              );
            },
            icon: const Icon(Icons.description_outlined, size: 18),
            label: const Text('Show Log'),
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }

  Widget _historyEntry(BuildContext context, UpdateFirmware state) {
    final colorScheme = Theme.of(context).colorScheme;
    final failed = state is UpdateCompleteFailure;
    final foregroundColor = failed ? colorScheme.error : _successGreen;
    final backgroundColor = failed
        ? colorScheme.errorContainer.withValues(alpha: 0.35)
        : _successGreen.withValues(alpha: 0.12);
    final borderColor = failed
        ? colorScheme.error.withValues(alpha: 0.45)
        : _successGreen.withValues(alpha: 0.34);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            failed ? Icons.error_outline_rounded : Icons.check_circle_rounded,
            size: 18,
            color: foregroundColor,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              state.stage,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _currentStatePanel(
    BuildContext context,
    UpdateFirmwareStateHistory state,
  ) {
    final currentState = state.currentState;
    const neutralBackground = Color(0xFFF5F6F7);
    const neutralBorder = Color(0xFFD4D8DE);
    const neutralForeground = Color(0xFF5E6572);
    final progress = currentState is UpdateProgressFirmware
        ? (currentState.progress.clamp(0, 100) / 100.0)
        : null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: neutralBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: neutralBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: neutralForeground,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _currentStateLabel(state),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
            ],
          ),
          if (progress != null) ...[
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: progress,
              minHeight: 4,
              color: neutralForeground,
              backgroundColor: neutralForeground.withValues(alpha: 0.18),
            ),
          ],
        ],
      ),
    );
  }

  String _currentStateLabel(UpdateFirmwareStateHistory state) {
    final currentState = state.currentState;
    if (currentState == null) {
      return 'Preparing update...';
    }
    if (currentState is UpdateProgressFirmware) {
      final core = currentState.imageNumber == 0 ? 'application' : 'network';
      return 'Uploading $core core ${currentState.progress}%';
    }
    return currentState.stage;
  }

  Widget _successPanel(BuildContext context) {
    return const _VerificationWarningPanel();
  }

  Widget _firmwareInfoCard(BuildContext context, SelectedFirmware firmware) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.38),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.6),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.memory_rounded,
            size: 18,
            color: colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  firmware.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _firmwareSubtitle(firmware),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _firmwareSubtitle(SelectedFirmware firmware) {
    if (firmware is RemoteFirmware) {
      return 'Remote firmware • version ${firmware.version}';
    }
    if (firmware is LocalFirmware) {
      final typeLabel = firmware.type == FirmwareType.multiImage
          ? 'Multi-image'
          : 'Single-image';
      return 'Local firmware • $typeLabel';
    }
    return 'Firmware';
  }
}

class _VerificationWarningPanel extends StatefulWidget {
  const _VerificationWarningPanel();

  @override
  State<_VerificationWarningPanel> createState() =>
      _VerificationWarningPanelState();
}

class _VerificationWarningPanelState extends State<_VerificationWarningPanel> {
  static const Duration _total = Duration(minutes: 3);
  late Duration _remaining;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _remaining = _total;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_remaining.inSeconds <= 1) {
        setState(() {
          _remaining = Duration.zero;
        });
        timer.cancel();
      } else {
        setState(() {
          _remaining -= const Duration(seconds: 1);
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _format(Duration duration) {
    final m = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    const warningBackground = Color(0xFFFFECEC);
    const warningForeground = Color(0xFF8A1C1C);

    return AppBanner(
      backgroundColor: warningBackground,
      foregroundColor: warningForeground,
      leadingIcon: Icons.warning_amber_rounded,
      content: Text(
        'Verification in progress, do not reset or power off the device: ${_format(_remaining)}.',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: warningForeground,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}
