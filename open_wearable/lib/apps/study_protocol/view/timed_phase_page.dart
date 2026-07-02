import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';

import 'package:open_wearable/apps/study_protocol/model/study_devices.dart';
import 'package:open_wearable/apps/study_protocol/model/study_recording_status.dart';
import 'package:open_wearable/apps/study_protocol/model/study_session.dart';
import 'package:open_wearable/apps/study_protocol/model/timed_recording_controller.dart';
import 'package:open_wearable/apps/study_protocol/view/study_flow.dart';
import 'package:open_wearable/apps/study_protocol/widgets/timer_ring.dart';

/// Generic fixed-duration recording phase (baseline, recovery, treadmill).
///
/// Records continuously on the OpenEarable pair and RESPIRABAN for the phase
/// [config] duration, shows a countdown ring, and continues to the next phase
/// when complete. Every phase must be actively started and can be skipped.
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
  bool _isBusy = false;

  @override
  void initState() {
    super.initState();
    _controller = TimedRecordingController(
      duration: widget.config.duration,
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
    setState(() => _isBusy = true);
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
        setState(() => _isBusy = false);
      }
    }
  }

  Future<void> _stop() async {
    final shouldStop = await _confirm(
      'Stop ${widget.config.title.toLowerCase()}?',
      'The phase is not finished yet. Stopping now will end the recording on '
          'all devices.',
      confirmLabel: 'Stop',
    );
    if (shouldStop) {
      await _controller.stop();
    }
  }

  Future<void> _skip() async {
    final shouldSkip = await _confirm(
      'Skip ${widget.config.title.toLowerCase()}?',
      'This phase will be skipped and the next phase will start.',
      confirmLabel: 'Skip',
    );
    if (!shouldSkip || !mounted) {
      return;
    }
    if (_controller.isRecording) {
      await _controller.stop();
    }
    if (mounted) {
      _advance();
    }
  }

  void _advance() {
    advanceStudyPhase(
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
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) {
              _stop();
            }
          },
          child: PlatformScaffold(
            material: (_, __) => MaterialScaffoldData(
              resizeToAvoidBottomInset: false,
            ),
            cupertino: (_, __) => CupertinoPageScaffoldData(
              resizeToAvoidBottomInset: false,
            ),
            appBar: PlatformAppBar(
              title: PlatformText(widget.config.title),
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
                      widget.config.instruction,
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
                          if (_controller.warning != null) ...[
                            const SizedBox(height: 20),
                            _WarningBanner(message: _controller.warning!),
                          ],
                        ],
                      ),
                    ),
                    _buildActionButton(status),
                    if (status != StudyRecordingStatus.completed) ...[
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: PlatformTextButton(
                          onPressed: _skip,
                          child: PlatformText('Skip ${widget.config.title}'),
                        ),
                      ),
                    ],
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
            onPressed: _stop,
            material: (_, __) => MaterialElevatedButtonData(
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
                foregroundColor: Theme.of(context).colorScheme.onError,
              ),
            ),
            child: PlatformText('Stop'),
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
          Expanded(
            child: Text(message, style: theme.textTheme.bodySmall),
          ),
        ],
      ),
    );
  }
}
