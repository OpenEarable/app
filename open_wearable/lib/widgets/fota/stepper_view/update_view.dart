import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:mcumgr_flutter/mcumgr_flutter.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart';
import 'package:open_wearable/models/fota_post_update_verification.dart';
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
  static const int _resetValidateLoopTransitionThreshold = 3;

  bool _lastReportedRunning = false;
  bool _startRequested = false;
  bool _verificationStarted = false;
  bool _verificationCancelled = false;
  ArmedFotaPostUpdateVerification? _verification;
  bool _isVerificationPending = false;
  FotaPostUpdateVerificationResult? _verificationResult;
  Future<List<McuLogMessage>>? _recoveryLogSnapshot;
  bool _loopWarningHandled = false;
  String? _lastResetValidateStage;
  StreamSubscription<Set<String>>? _verificationPendingSubscription;
  int _resetValidateLoopTransitions = 0;

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
    _verificationPendingSubscription?.cancel();
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
        final updateProvider = context.read<FirmwareUpdateRequestProvider>();
        unawaited(_updateVerification(state, updateProvider));
        await _maybeShowLoopWarning(
          state: state,
          updateProvider: updateProvider,
        );
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

  // The updater can also reset before uploading to clear an old pending image.
  // Only the reset after Test/Confirm starts post-update verification.
  bool _isVerificationReset(UpdateState state) =>
      state is UpdateFirmwareStateHistory &&
      state.currentState?.stage == 'Reset' &&
      state.history
          .any((entry) => entry.stage == 'Test' || entry.stage == 'Confirm');

  bool _isNativeSuccess(UpdateState state) =>
      state is UpdateFirmwareStateHistory &&
      state.isComplete &&
      state.history.isNotEmpty &&
      state.history.last is UpdateCompleteSuccess;

  // TEST_ONLY can remain in Reset for the configured 90-second swap estimate.
  // A new connection reporting the expected firmware is already verified.
  bool _hasVerificationResult(UpdateState state) =>
      _verificationResult != null &&
      (_isVerificationReset(state) || _isNativeSuccess(state));

  bool _isUpdateInProgress(UpdateState state) {
    if (state is UpdateInitial || _hasVerificationResult(state)) return false;
    if (state is UpdateFirmwareStateHistory) {
      return !state.isComplete || _isVerificationPending;
    }
    return true;
  }

  Future<void> _updateVerification(
    UpdateState state,
    FirmwareUpdateRequestProvider provider,
  ) async {
    final coordinator = FotaPostUpdateVerificationCoordinator.instance;
    if (state is UpdateFirmwareStateHistory &&
        state.isComplete &&
        !_isNativeSuccess(state)) {
      _verificationCancelled = true;
      final verification = _verification;
      if (verification != null) {
        coordinator.cancel(verification.verificationId);
        dismissFotaVerificationBannerById(context, verification.verificationId);
      }
      return;
    }
    if (_verificationStarted ||
        (!_isVerificationReset(state) && !_isNativeSuccess(state))) {
      return;
    }
    _verificationStarted = true;
    final verification = await coordinator.armFromUpdateRequest(
      request: provider.updateParameters,
      selectedWearable: provider.selectedWearable,
      preResolvedWearableName: widget.preResolvedWearableName,
      preResolvedSideLabel: widget.preResolvedSideLabel,
      connectionBeforeReset:
          _isVerificationReset(state) ? provider.selectedWearable : null,
    );
    if (verification == null) return;
    if (_verificationCancelled) {
      coordinator.cancel(verification.verificationId);
      return;
    }
    if (!mounted) return;
    _verification = verification;
    _bindVerificationLifecycle(verification.verificationId);
    if (_isVerificationPending) {
      showFotaVerificationBanner(
        context,
        verificationId: verification.verificationId,
        wearableName: verification.wearableName,
        sideLabel: verification.sideLabel,
        deadline: verification.deadline,
      );
    }
  }

  /// Keeps the countdown and page completion tied to actual reconnect validation.
  void _bindVerificationLifecycle(String verificationId) {
    _verificationPendingSubscription?.cancel();
    final coordinator = FotaPostUpdateVerificationCoordinator.instance;
    void refresh() {
      if (!mounted) return;
      setState(() {
        _isVerificationPending =
            coordinator.isVerificationPending(verificationId);
        _verificationResult = coordinator.resultFor(verificationId);
      });
      if (!_isVerificationPending) {
        dismissFotaVerificationBannerById(context, verificationId);
      }
      _reportRunningState(
        _isUpdateInProgress(context.read<UpdateBloc>().state),
      );
    }

    _verificationPendingSubscription =
        coordinator.pendingVerificationIds.listen((_) => refresh());
    refresh();
  }

  /// Shows a one-time warning when the update appears to restart image uploads
  /// more often than the selected firmware package should require.
  Future<void> _maybeShowLoopWarning({
    required UpdateState state,
    required FirmwareUpdateRequestProvider updateProvider,
  }) async {
    if (_loopWarningHandled || !_isUpdateInProgress(state)) {
      return;
    }

    final currentState = state is UpdateFirmwareStateHistory
        ? state.currentState
        : state is UpdateFirmware
            ? state
            : null;
    final stage = currentState?.stage;

    if (_looksLikeResetValidateLoop(stage)) {
      await _showLoopWarningDialog(
        updateProvider: updateProvider,
        details:
            'The update appears to be bouncing between reset and validate. This can mean the wearable is stuck in a FOTA loop and there may be a problem.',
      );
      return;
    }

    if (currentState is! UpdateProgressFirmware) {
      return;
    }

    final expectedImageCount =
        _expectedImageCount(updateProvider.updateParameters);
    final suspectedLoopThreshold = expectedImageCount;
    if (currentState.imageNumber <= suspectedLoopThreshold) {
      return;
    }

    await _showLoopWarningDialog(
      updateProvider: updateProvider,
      details:
          'The update appears to be repeating image uploads more often than expected. This can mean the wearable is stuck in a FOTA loop and there may be a problem.',
    );
  }

  /// Tracks repeated `Reset <-> Validate` oscillation and returns true when the
  /// update appears stuck between those two states.
  bool _looksLikeResetValidateLoop(String? stage) {
    final normalizedStage = stage?.trim().toLowerCase();
    final isLoopStage =
        normalizedStage == 'reset' || normalizedStage == 'validate';

    if (!isLoopStage) {
      _lastResetValidateStage = null;
      _resetValidateLoopTransitions = 0;
      return false;
    }

    if (_lastResetValidateStage == null) {
      _lastResetValidateStage = normalizedStage;
      return false;
    }

    if (_lastResetValidateStage == normalizedStage) {
      return false;
    }

    _lastResetValidateStage = normalizedStage;
    _resetValidateLoopTransitions++;

    return _resetValidateLoopTransitions >=
        _resetValidateLoopTransitionThreshold;
  }

  /// Presents the generic loop warning and optionally links to slot info.
  Future<void> _showLoopWarningDialog({
    required FirmwareUpdateRequestProvider updateProvider,
    required String details,
  }) async {
    _loopWarningHandled = true;
    final wearable = updateProvider.selectedWearable;
    final supportsSlotInfo =
        wearable?.hasCapability<FotaSlotInfoCapability>() ?? false;

    final action = await showPlatformDialog<_LoopWarningAction>(
      context: context,
      builder: (_) => PlatformAlertDialog(
        title: const Text('Firmware update may be stuck'),
        content: Text(
          '$details\n\n'
          '${supportsSlotInfo ? 'You can inspect the reported image slots for recovery hints, or ignore this warning and continue waiting.' : 'You can ignore this warning and continue waiting.'}',
        ),
        actions: <Widget>[
          PlatformDialogAction(
            child: const Text('Ignore'),
            onPressed: () =>
                Navigator.of(context).pop(_LoopWarningAction.ignore),
          ),
          if (supportsSlotInfo)
            PlatformDialogAction(
              cupertino: (_, __) => CupertinoDialogActionData(
                isDefaultAction: true,
              ),
              child: const Text('Open Image Slots'),
              onPressed: () =>
                  Navigator.of(context).pop(_LoopWarningAction.openSlots),
            ),
        ],
      ),
    );

    if (!mounted ||
        action != _LoopWarningAction.openSlots ||
        wearable == null ||
        !supportsSlotInfo) {
      return;
    }

    final bloc = context.read<UpdateBloc>();
    var state = bloc.state;
    if (state is! UpdateFirmwareStateHistory || !state.isComplete) {
      final aborted = bloc.stream.firstWhere(
        (state) => state is UpdateFirmwareStateHistory && state.isComplete,
      );
      bloc.add(AbortUpdate());
      state = await aborted;
    }
    if (!mounted) return;

    // Slot inspection disposes the native updater for this device. Preserve
    // its log after cancellation and before opening the recovery page.
    if (state is UpdateFirmwareStateHistory) {
      _recoveryLogSnapshot = state.updateManager?.logger.readLogs();
      try {
        await _recoveryLogSnapshot;
      } catch (_) {
        // Keep the failed future so Show Log reports the original read error.
      }
    }
    if (!mounted) return;
    context.push('/fota/slots', extra: wearable);
  }

  /// Estimates how many image uploads the current firmware package should need.
  int _expectedImageCount(FirmwareUpdateRequest request) {
    if (request is SingleImageFirmwareUpdateRequest) {
      return 1;
    }
    if (request is MultiImageFirmwareUpdateRequest) {
      final imageCount = request.firmwareImages?.length;
      if (imageCount != null && imageCount > 0) {
        return imageCount;
      }
      return 2;
    }
    return 1;
  }

  /// Requests explicit confirmation before aborting an active update.
  Future<void> _confirmAbortUpdate(BuildContext context) async {
    final updateBloc = this.context.read<UpdateBloc>();
    final shouldAbort = await showPlatformDialog<bool>(
      context: context,
      builder: (_) => PlatformAlertDialog(
        title: const Text('Abort firmware update?'),
        content: const Text(
          'Aborting a firmware update can leave the device in an incomplete state until the update is started again.\n\nDo you want to abort the update now?',
        ),
        actions: <Widget>[
          PlatformDialogAction(
            child: const Text('Keep Updating'),
            onPressed: () => Navigator.of(context).pop(false),
          ),
          PlatformDialogAction(
            cupertino: (_, __) => CupertinoDialogActionData(
              isDestructiveAction: true,
            ),
            child: const Text('Abort Update'),
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );

    if (!mounted || shouldAbort != true) {
      return;
    }

    updateBloc.add(AbortUpdate());
  }

  /// Builds the destructive abort action shown while an update is active.
  Widget _abortButton(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () => _confirmAbortUpdate(context),
        style: OutlinedButton.styleFrom(
          foregroundColor: colorScheme.error,
          side: BorderSide(
            color: colorScheme.error.withValues(alpha: 0.55),
          ),
        ),
        icon: const Icon(Icons.cancel_outlined, size: 18),
        label: const Text('Abort Update'),
      ),
    );
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
        const SizedBox(height: 12),
        _abortButton(context),
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
    final verificationFinished = _hasVerificationResult(state);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // The handler announces upload before the native updater starts it.
        // Only the native upload progress belongs in the completed steps.
        for (final entry in history.where(
          (entry) =>
              entry.stage != 'Upload firmware' ||
              entry is UpdateProgressFirmware,
        )) ...[
          _historyEntry(context, entry),
          const SizedBox(height: 8),
        ],
        if (currentState != null && !verificationFinished) ...[
          _currentStatePanel(context, state),
          const SizedBox(height: 10),
        ],
        if (!state.isComplete && !verificationFinished) ...[
          _abortButton(context),
          const SizedBox(height: 10),
        ],
        if (_isVerificationPending) ...[
          _successPanel(context),
          const SizedBox(height: 10),
        ],
        if (verificationFinished) ...[
          _completedStep(
            context,
            _verificationResult!.message,
            failed: !_verificationResult!.success,
          ),
          const SizedBox(height: 10),
        ],
        if (state.isComplete && state.updateManager?.logger != null) ...[
          OutlinedButton.icon(
            onPressed: () {
              context.push(
                '/view',
                extra: LoggerScreen(
                  logger: state.updateManager!.logger,
                  logSnapshot: _recoveryLogSnapshot,
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
    return _completedStep(
      context,
      state is UpdateCompleteFailure
          ? '${state.stage}: ${state.error}'
          : state.stage == 'Upload'
              ? 'Upload firmware'
              : state.stage,
      failed: state is UpdateCompleteFailure,
    );
  }

  Widget _completedStep(
    BuildContext context,
    String message, {
    bool failed = false,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
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
              message,
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
    return _isVerificationReset(state)
        ? 'Reset and verify'
        : currentState.stage;
  }

  Widget _successPanel(BuildContext context) {
    final verification = _verification!;
    return FotaVerificationBanner(
      deadline: verification.deadline,
      wearableName: verification.wearableName,
      sideLabel: verification.sideLabel,
      showUploadCompleted: false,
      // The coordinator owns the timeout and replaces this with its result.
      onDismiss: () {},
    );
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

enum _LoopWarningAction {
  ignore,
  openSlots,
}
