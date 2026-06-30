import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';

import 'package:open_wearable/apps/study_protocol/model/study_devices.dart';
import 'package:open_wearable/apps/study_protocol/model/study_recording_controller.dart';
import 'package:open_wearable/apps/study_protocol/model/study_recording_status.dart';
import 'package:open_wearable/apps/study_protocol/widgets/timer_ring.dart';

/// Guided 5-minute baseline step.
///
/// Starts synchronized recording on the OpenEarable pair (microphone + IMU to
/// SD card) and the RESPIRABAN (Belt + IMU, streamed to a phone-side CSV), runs
/// a countdown ring, and stops both devices automatically when it elapses.
class StudyBaselinePage extends StatefulWidget {
  final String probandId;
  final StudyDeviceSet deviceSet;

  const StudyBaselinePage({
    super.key,
    required this.probandId,
    required this.deviceSet,
  });

  @override
  State<StudyBaselinePage> createState() => _StudyBaselinePageState();
}

class _StudyBaselinePageState extends State<StudyBaselinePage> {
  final StudyRecordingController _controller = StudyRecordingController();
  bool _isBusy = false;

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

  Future<void> _startBaseline() async {
    setState(() => _isBusy = true);
    try {
      await _controller.start(
        probandId: widget.probandId,
        deviceSet: widget.deviceSet,
      );
    } catch (e) {
      await _showError('Failed to start the baseline recording: $e');
    } finally {
      if (mounted) {
        setState(() => _isBusy = false);
      }
    }
  }

  Future<void> _stopBaseline() async {
    final shouldStop = await showPlatformDialog<bool>(
          context: context,
          builder: (dialogContext) => PlatformAlertDialog(
            title: PlatformText('Stop baseline?'),
            content: PlatformText(
              'The baseline is not finished yet. Stopping now will end the '
              'recording on all devices.',
            ),
            actions: [
              PlatformDialogAction(
                child: PlatformText('Keep recording'),
                onPressed: () => Navigator.pop(dialogContext, false),
              ),
              PlatformDialogAction(
                cupertino: (_, __) => CupertinoDialogActionData(
                  isDestructiveAction: true,
                ),
                child: PlatformText('Stop'),
                onPressed: () => Navigator.pop(dialogContext, true),
              ),
            ],
          ),
        ) ??
        false;

    if (shouldStop) {
      await _controller.stop();
    }
  }

  Future<void> _showError(String message) async {
    if (!mounted) {
      return;
    }
    await showPlatformDialog(
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
              _stopBaseline();
            }
          },
          child: PlatformScaffold(
            // The page has no text inputs; ignoring the bottom inset avoids a
            // transient layout overflow while the keyboard from the proband-id
            // dialog is still animating away.
            material: (_, __) => MaterialScaffoldData(
              resizeToAvoidBottomInset: false,
            ),
            cupertino: (_, __) => CupertinoPageScaffoldData(
              resizeToAvoidBottomInset: false,
            ),
            appBar: PlatformAppBar(
              title: PlatformText('Baseline'),
            ),
            body: SafeArea(
              child: _buildBody(context, status, isRecording),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBody(
    BuildContext context,
    StudyRecordingStatus status,
    bool isRecording,
  ) {
    final theme = Theme.of(context);
    final caption = switch (status) {
      StudyRecordingStatus.idle => 'Ready',
      StudyRecordingStatus.recording => 'Recording',
      StudyRecordingStatus.completed => 'Completed',
    };

    // LayoutBuilder + scrollable intrinsic height keeps the centered ring and
    // bottom button layout while guaranteeing the page can never overflow,
    // regardless of screen height or transient viewport insets.
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
                    _StepHeader(probandId: widget.probandId),
                    const SizedBox(height: 8),
                    Text(
                      'Sit still and breathe normally for 5 minutes. The '
                      'recording stops automatically when the timer ends.',
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
                    _buildActionButton(status, isRecording),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildActionButton(StudyRecordingStatus status, bool isRecording) {
    switch (status) {
      case StudyRecordingStatus.idle:
        return SizedBox(
          width: double.infinity,
          child: PlatformElevatedButton(
            onPressed: _isBusy ? null : _startBaseline,
            child: PlatformText(_isBusy ? 'Starting…' : 'Start baseline'),
          ),
        );
      case StudyRecordingStatus.recording:
        return SizedBox(
          width: double.infinity,
          child: PlatformElevatedButton(
            onPressed: _stopBaseline,
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
            onPressed: () => Navigator.of(context).pop(),
            child: PlatformText('Done'),
          ),
        );
    }
  }
}

class _StepHeader extends StatelessWidget {
  final String probandId;

  const _StepHeader({required this.probandId});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Text(
          'Step 1 of 1 · Baseline',
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
            child: Text(
              message,
              style: theme.textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}
