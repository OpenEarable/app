import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';

import 'package:open_wearable/apps/study_protocol/model/study_devices.dart';
import 'package:open_wearable/apps/study_protocol/model/study_recording_status.dart';
import 'package:open_wearable/apps/study_protocol/model/study_session.dart';
import 'package:open_wearable/apps/study_protocol/model/timed_recording_controller.dart';
import 'package:open_wearable/apps/study_protocol/view/study_flow.dart';
import 'package:open_wearable/apps/study_protocol/widgets/recording_file_size_card.dart';
import 'package:open_wearable/apps/study_protocol/widgets/timer_ring.dart';

/// Generic fixed-duration recording phase (baseline, treadmill).
///
/// Records continuously on the OpenEarable pair and RespiBAN for the phase
/// [config] duration, shows a countdown ring, and continues to the next phase
/// when complete. Every phase must be actively started; skipping the complete
/// seal-check/phase/seal-check unit is offered before this page is entered.
class TimedPhasePage extends StatefulWidget {
  final StudyPhase phase;
  final TimedPhaseConfig config;
  final StudySession session;
  final StudyDeviceSet deviceSet;
  final String directory;

  const TimedPhasePage({
    super.key,
    required this.phase,
    required this.config,
    required this.session,
    required this.deviceSet,
    required this.directory,
  });

  @override
  State<TimedPhasePage> createState() => _TimedPhasePageState();
}

class _TimedPhasePageState extends State<TimedPhasePage> {
  late final TimedRecordingController _controller;
  bool _isStarting = false;
  bool _isStopping = false;

  bool get _isBusy => _isStarting || _isStopping;

  @override
  void initState() {
    super.initState();
    _controller = TimedRecordingController(
      duration: widget.config.durationFor(widget.session),
      respibanFileLabel: widget.config.respibanFileLabel,
      earablePrefixSuffix: widget.config.earablePrefixSuffix,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _formatDuration(Duration duration) {
    final totalSeconds = duration.inSeconds;
    final minutes = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  Future<void> _start() async {
    if (_isBusy) {
      return;
    }
    setState(() => _isStarting = true);
    try {
      await _controller.start(
        probandId: widget.session.probandId,
        deviceSet: widget.deviceSet,
        directory: widget.directory,
      );
    } catch (e) {
      await _showError('Failed to start the recording: $e');
    } finally {
      if (mounted) {
        setState(() => _isStarting = false);
      }
    }
  }

  Future<void> _stop() async {
    if (_isStopping || !_controller.isRecording) {
      return;
    }
    final shouldStop = await _confirm(
      'Stop ${widget.config.title.toLowerCase()}?',
      'The phase is not finished yet. Stopping now will end the recording on '
          'all devices.',
      confirmLabel: 'Stop',
    );
    if (shouldStop) {
      await _stopRecording();
    }
  }

  Future<void> _stopRecording({bool rethrowOnError = false}) async {
    if (_isStopping || !_controller.isRecording) {
      return;
    }
    setState(() => _isStopping = true);
    try {
      await _controller.stop();
    } catch (e) {
      await _showError('Failed to stop the recording: $e');
      if (rethrowOnError) {
        rethrow;
      }
    } finally {
      if (mounted) {
        setState(() => _isStopping = false);
      }
    }
  }

  Future<void> _stopIfRecording() => _stopRecording(rethrowOnError: true);

  void _advance() {
    advanceStudyPhase(
      context: context,
      current: widget.phase,
      session: widget.session,
      deviceSet: widget.deviceSet,
      directory: widget.directory,
    );
  }

  /// Goes back to the previous phase (fresh restart), like skip but backwards.
  Future<void> _previousPhase() async {
    if (_isBusy || _controller.isRecording) {
      return;
    }
    final shouldGoBack = await _confirm(
      'Go to previous phase?',
      'This leaves ${widget.config.title.toLowerCase()} and returns to the '
          'previous phase, which restarts from the beginning.',
      confirmLabel: 'Previous',
    );
    if (!shouldGoBack || !mounted) {
      return;
    }
    await _stopIfRecording();
    if (mounted) {
      goToPreviousStudyPhase(
        context: context,
        current: widget.phase,
        session: widget.session,
        deviceSet: widget.deviceSet,
        directory: widget.directory,
      );
    }
  }

  Future<void> _repeatPhase() async {
    if (_isBusy || _controller.isRecording) {
      return;
    }
    final shouldRepeat = await _confirm(
      'Repeat ${widget.config.title.toLowerCase()}?',
      'This stops the current recording if needed and restarts this phase from '
          'its start seal check.',
      confirmLabel: 'Repeat',
    );
    if (!shouldRepeat || !mounted) {
      return;
    }
    await _stopIfRecording();
    if (mounted) {
      repeatStudyPhase(
        context: context,
        current: widget.phase,
        session: widget.session,
        deviceSet: widget.deviceSet,
        directory: widget.directory,
      );
    }
  }

  Future<void> _nextPhase() async {
    if (_isBusy) {
      return;
    }
    final status = _controller.status;
    if (status == StudyRecordingStatus.completed) {
      _advance();
      return;
    }

    final isRecording = status == StudyRecordingStatus.recording;
    if (isRecording) {
      return;
    }
    final shouldContinue = await _confirm(
      'Skip ${widget.config.title.toLowerCase()}?',
      'This skips this phase and continues with the next phase.',
      confirmLabel: 'Next',
    );
    if (!shouldContinue || !mounted) {
      return;
    }

    goToNextStudyPhase(
      context: context,
      current: widget.phase,
      session: widget.session,
      deviceSet: widget.deviceSet,
      directory: widget.directory,
    );
  }

  Future<bool> _confirm(
    String title,
    String message, {
    required String confirmLabel,
  }) async {
    return await showPlatformDialog<bool>(
          context: context,
          builder: (dialogContext) => PlatformAlertDialog(
            title: PlatformText(title),
            content: PlatformText(message),
            actions: [
              PlatformDialogAction(
                child: PlatformText('Cancel'),
                onPressed: () => Navigator.pop(dialogContext, false),
              ),
              PlatformDialogAction(
                child: PlatformText(confirmLabel),
                onPressed: () => Navigator.pop(dialogContext, true),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _showError(String message) async {
    if (!mounted) {
      return;
    }
    await showPlatformDialog<void>(
      context: context,
      builder: (dialogContext) => PlatformAlertDialog(
        title: PlatformText('Error'),
        content: PlatformText(message),
        actions: [
          PlatformDialogAction(
            child: PlatformText('OK'),
            onPressed: () => Navigator.pop(dialogContext),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final status = _controller.status;
        final isRecording = status == StudyRecordingStatus.recording;

        return PopScope(
          canPop: !isRecording,
          onPopInvokedWithResult: (didPop, result) {},
          child: PlatformScaffold(
            material: (_, __) =>
                MaterialScaffoldData(resizeToAvoidBottomInset: false),
            cupertino: (_, __) =>
                CupertinoPageScaffoldData(resizeToAvoidBottomInset: false),
            appBar: PlatformAppBar(
              title: PlatformText(widget.config.title),
              automaticallyImplyLeading: !isRecording,
            ),
            body: SafeArea(child: _buildBody(context, status)),
          ),
        );
      },
    );
  }

  Widget _buildBody(BuildContext context, StudyRecordingStatus status) {
    final theme = Theme.of(context);
    final caption = switch (status) {
      StudyRecordingStatus.idle => 'Ready',
      StudyRecordingStatus.recording => 'Recording',
      StudyRecordingStatus.completed => 'Completed',
    };

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: IntrinsicHeight(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    _StepHeader(
                      stepLabel: widget.config.stepLabel,
                      probandId: widget.session.probandId,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.session.timerTestMode
                          ? '${widget.config.instruction}\n\nTest mode: this '
                              'phase uses a 10 second timer.'
                          : widget.config.instruction,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          TimerRing(
                            progress: _controller.progress,
                            label: _formatDuration(_controller.remaining),
                            caption: caption,
                          ),
                          if (status != StudyRecordingStatus.idle) ...[
                            const SizedBox(height: 16),
                            RecordingFileSizeCard(
                              sizeBytes: _controller.respibanFileSizeBytes,
                              deltaBytes:
                                  _controller.respibanFileSizeDeltaBytes,
                              isRecording:
                                  status == StudyRecordingStatus.recording,
                            ),
                          ],
                          if (_controller.warning != null) ...[
                            const SizedBox(height: 20),
                            _WarningBanner(message: _controller.warning!),
                          ],
                        ],
                      ),
                    ),
                    if (status != StudyRecordingStatus.completed) ...[
                      _buildActionButton(status),
                      const SizedBox(height: 12),
                    ],
                    _buildPhaseNavigation(status),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildActionButton(StudyRecordingStatus status) {
    switch (status) {
      case StudyRecordingStatus.idle:
        return SizedBox(
          width: double.infinity,
          child: PlatformElevatedButton(
            onPressed: _isBusy ? null : _start,
            child: PlatformText(
              _isBusy
                  ? 'Starting…'
                  : 'Start ${widget.config.title.toLowerCase()}',
            ),
          ),
        );
      case StudyRecordingStatus.recording:
        return SizedBox(
          width: double.infinity,
          child: PlatformElevatedButton(
            onPressed: _isStopping ? null : _stop,
            material: (_, __) => MaterialElevatedButtonData(
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
                foregroundColor: Theme.of(context).colorScheme.onError,
              ),
            ),
            child: _isStopping
                ? _BusyButtonLabel(
                    label: 'Stopping…',
                    color: Theme.of(context).colorScheme.onError,
                  )
                : PlatformText('Stop'),
          ),
        );
      case StudyRecordingStatus.completed:
        return SizedBox(
          width: double.infinity,
          child: PlatformElevatedButton(
            onPressed: _advance,
            child: PlatformText('Continue'),
          ),
        );
    }
  }

  Widget _buildPhaseNavigation(StudyRecordingStatus status) {
    final isRecording = status == StudyRecordingStatus.recording;
    return Row(
      children: [
        Expanded(
          child: PlatformTextButton(
            onPressed: _isBusy || isRecording ? null : _previousPhase,
            child: const _NavigationButtonLabel(
              icon: Icons.arrow_back,
              label: 'Previous',
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: PlatformTextButton(
            onPressed: _isBusy || isRecording ? null : _repeatPhase,
            child: const _NavigationButtonLabel(
              icon: Icons.replay,
              label: 'Repeat',
              iconAfterLabel: true,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: status == StudyRecordingStatus.completed
              ? PlatformElevatedButton(
                  onPressed: _isBusy ? null : _nextPhase,
                  child: const _NavigationButtonLabel(
                    icon: Icons.arrow_forward,
                    label: 'Next',
                    iconAfterLabel: true,
                  ),
                )
              : PlatformTextButton(
                  onPressed: _isBusy || isRecording ? null : _nextPhase,
                  child: const _NavigationButtonLabel(
                    icon: Icons.arrow_forward,
                    label: 'Next',
                    iconAfterLabel: true,
                  ),
                ),
        ),
      ],
    );
  }
}

class _NavigationButtonLabel extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool iconAfterLabel;

  const _NavigationButtonLabel({
    required this.icon,
    required this.label,
    this.iconAfterLabel = false,
  });

  @override
  Widget build(BuildContext context) {
    final iconWidget = Icon(icon, size: 18);
    final labelWidget = PlatformText(label);
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: iconAfterLabel
          ? [
              labelWidget,
              const SizedBox(width: 6),
              iconWidget,
            ]
          : [
              iconWidget,
              const SizedBox(width: 6),
              labelWidget,
            ],
    );
  }
}

class _BusyButtonLabel extends StatelessWidget {
  final String label;
  final Color color;

  const _BusyButtonLabel({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: color,
          ),
        ),
        const SizedBox(width: 8),
        PlatformText(label),
      ],
    );
  }
}

class _StepHeader extends StatelessWidget {
  final String stepLabel;
  final String probandId;

  const _StepHeader({required this.stepLabel, required this.probandId});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Text(
          stepLabel,
          style: theme.textTheme.labelLarge?.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Proband $probandId',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _WarningBanner extends StatelessWidget {
  final String message;

  const _WarningBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.warning_amber_rounded,
            color: theme.colorScheme.error,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(message, style: theme.textTheme.bodySmall)),
        ],
      ),
    );
  }
}
