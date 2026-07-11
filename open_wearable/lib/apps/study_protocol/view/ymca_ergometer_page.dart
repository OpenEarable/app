import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';

import 'package:open_wearable/apps/study_protocol/model/study_devices.dart';
import 'package:open_wearable/apps/study_protocol/model/study_session.dart';
import 'package:open_wearable/apps/study_protocol/model/ymca_ergometer_controller.dart';
import 'package:open_wearable/apps/study_protocol/model/ymca_models.dart';
import 'package:open_wearable/apps/study_protocol/view/study_flow.dart';
import 'package:open_wearable/apps/study_protocol/widgets/recording_file_size_card.dart';
import 'package:open_wearable/apps/study_protocol/widgets/timer_ring.dart';

/// Guided modified YMCA ergometer test.
///
/// Runs continuous physiological recording while the experimenter enters a
/// heart rate and actual wattage every minute. Stages advance automatically
/// once a stage has run at least three minutes at a steady heart rate, and the
/// submaximal target heart rate is always visible so the test can be aborted.
class YmcaErgometerPage extends StatefulWidget {
  final StudySession session;
  final StudyDeviceSet deviceSet;
  final String directory;

  const YmcaErgometerPage({
    super.key,
    required this.session,
    required this.deviceSet,
    required this.directory,
  });

  @override
  State<YmcaErgometerPage> createState() => _YmcaErgometerPageState();
}

/// One entered measurement (heart rate + actual wattage).
class _MeasurementInput {
  final int heartRate;
  final int actualWatt;

  const _MeasurementInput({required this.heartRate, required this.actualWatt});
}

class _YmcaErgometerPageState extends State<YmcaErgometerPage> {
  static const Duration _recoveryQuestionnaireReminderInterval =
      Duration(minutes: 5);

  late final YmcaErgometerController _controller;
  final TextEditingController _hrController = TextEditingController();
  final TextEditingController _wattController = TextEditingController();
  final TextEditingController _endHrController = TextEditingController();

  Timer? _recoveryQuestionnaireReminderTimer;
  bool _dialogActive = false;
  bool _recoveryQuestionnaireReminderActive = false;
  bool _recoveryQuestionnaireDialogVisible = false;
  bool _recoveryQuestionnaireEndShown = false;
  bool _recoveryQuestionnaireFinalPending = false;
  bool _starting = false;
  bool _endingMeasurement = false;
  bool _stoppingRecording = false;

  bool get _isBusy => _starting || _endingMeasurement || _stoppingRecording;

  @override
  void initState() {
    super.initState();
    _controller = YmcaErgometerController(
      session: widget.session,
      deviceSet: widget.deviceSet,
      directory: widget.directory,
    );
    _controller.addListener(_onControllerChanged);
  }

  @override
  void dispose() {
    _recoveryQuestionnaireReminderTimer?.cancel();
    _controller.removeListener(_onControllerChanged);
    _controller.dispose();
    _hrController.dispose();
    _wattController.dispose();
    _endHrController.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    if (_isBusy) {
      return;
    }
    setState(() => _starting = true);
    try {
      await _controller.start();
    } catch (e) {
      await _showError('Failed to start the ergometer test: $e');
    } finally {
      if (mounted) {
        setState(() => _starting = false);
      }
    }
  }

  void _advance() {
    advanceStudyPhase(
      context: context,
      current: StudyPhase.ergometer,
      session: widget.session,
      deviceSet: widget.deviceSet,
      directory: widget.directory,
    );
  }

  void _onControllerChanged() {
    _syncRecoveryQuestionnaireReminders();
    unawaited(_processQueue());
  }

  void _syncRecoveryQuestionnaireReminders() {
    if (widget.session.timerTestMode ||
        _controller.status != ErgoStatus.recovering) {
      _cancelRecoveryQuestionnaireReminders(resetEndReminder: true);
      return;
    }

    if (!_controller.isRecoveryFinished &&
        !_recoveryQuestionnaireReminderActive) {
      _startRecoveryQuestionnaireReminders();
    }

    if (_controller.recoveryRemaining <= Duration.zero) {
      _showRecoveryQuestionnaireEndReminder();
      return;
    }

    if (_controller.isRecoveryFinished) {
      _cancelRecoveryQuestionnaireReminders(resetEndReminder: false);
    }
  }

  void _startRecoveryQuestionnaireReminders() {
    _recoveryQuestionnaireReminderActive = true;
    _recoveryQuestionnaireEndShown = false;
    _recoveryQuestionnaireFinalPending = false;
    _recoveryQuestionnaireReminderTimer?.cancel();
    _recoveryQuestionnaireReminderTimer = Timer.periodic(
      _recoveryQuestionnaireReminderInterval,
      (_) => _onRecoveryQuestionnaireReminderTick(),
    );
    unawaited(_showRecoveryQuestionnaireReminder());
  }

  void _onRecoveryQuestionnaireReminderTick() {
    if (!mounted ||
        widget.session.timerTestMode ||
        _controller.status != ErgoStatus.recovering) {
      _cancelRecoveryQuestionnaireReminders(resetEndReminder: true);
      return;
    }
    if (_controller.recoveryRemaining <= Duration.zero) {
      _showRecoveryQuestionnaireEndReminder();
      return;
    }
    if (_controller.isRecoveryFinished) {
      _cancelRecoveryQuestionnaireReminders(resetEndReminder: false);
      return;
    }
    unawaited(_showRecoveryQuestionnaireReminder());
  }

  void _showRecoveryQuestionnaireEndReminder() {
    if (_recoveryQuestionnaireEndShown) {
      return;
    }
    _recoveryQuestionnaireEndShown = true;
    _recoveryQuestionnaireReminderTimer?.cancel();
    _recoveryQuestionnaireReminderTimer = null;
    _recoveryQuestionnaireReminderActive = false;
    unawaited(_showRecoveryQuestionnaireReminder(isFinal: true));
  }

  void _cancelRecoveryQuestionnaireReminders({
    required bool resetEndReminder,
  }) {
    _recoveryQuestionnaireReminderTimer?.cancel();
    _recoveryQuestionnaireReminderTimer = null;
    _recoveryQuestionnaireReminderActive = false;
    if (resetEndReminder) {
      _recoveryQuestionnaireEndShown = false;
      _recoveryQuestionnaireFinalPending = false;
    }
  }

  Future<void> _showRecoveryQuestionnaireReminder({
    bool isFinal = false,
  }) async {
    if (!mounted || widget.session.timerTestMode) {
      return;
    }
    if (_recoveryQuestionnaireDialogVisible) {
      if (isFinal) {
        _recoveryQuestionnaireFinalPending = true;
      }
      return;
    }

    _recoveryQuestionnaireDialogVisible = true;
    try {
      await showPlatformDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => PlatformAlertDialog(
          title: PlatformText(
            isFinal ? 'Recovery questionnaire' : 'Questionnaire reminder',
          ),
          content: PlatformText(
            isFinal
                ? 'The recovery timer has ended. Please fill out the '
                    'questionnaire now.'
                : 'Please fill out the questionnaire now. The recovery timer '
                    'and data recording continue in the background.',
          ),
          actions: [
            PlatformDialogAction(
              child: PlatformText('OK'),
              onPressed: () => Navigator.pop(dialogContext),
            ),
          ],
        ),
      );
    } finally {
      _recoveryQuestionnaireDialogVisible = false;
      if (mounted && _recoveryQuestionnaireFinalPending) {
        _recoveryQuestionnaireFinalPending = false;
        unawaited(_showRecoveryQuestionnaireReminder(isFinal: true));
      }
    }
  }

  /// Drives the measurement/stage/end dialogs one at a time so the background
  /// measurement clock can keep running while a dialog is open.
  Future<void> _processQueue() async {
    if (_dialogActive || !mounted) {
      return;
    }
    _dialogActive = true;
    try {
      while (mounted && _controller.status == ErgoStatus.running) {
        if (_controller.isMeasurementDue) {
          final input = await _showMeasurementEntry();
          if (input != null) {
            await _controller.submitMeasurement(
              heartRate: input.heartRate,
              actualWatt: input.actualWatt,
            );
          } else {
            await _endTest(requireConfirmation: true);
          }
          continue;
        }
        if (_controller.endSuggested) {
          await _showEndSuggestion();
          continue;
        }
        if (_controller.pendingStageMessage != null) {
          await _showStageMessage();
          continue;
        }
        break;
      }
    } finally {
      _dialogActive = false;
    }
  }

  Future<_MeasurementInput?> _showMeasurementEntry() async {
    _hrController.clear();
    _wattController.clear();
    final minute = _controller.dueMeasurementMinute;

    return showPlatformDialog<_MeasurementInput>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        String? error;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final title =
                'Measurement${minute == null ? '' : ' · min $minute'}';
            return PlatformAlertDialog(
              title: PlatformText(title),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Target heart rate: ${_controller.submaxHeartRate} BPM'),
                  const SizedBox(height: 12),
                  _NumberField(
                    controller: _hrController,
                    label: 'Heart rate (BPM)',
                    autofocus: true,
                  ),
                  const SizedBox(height: 10),
                  _NumberField(
                    controller: _wattController,
                    label: 'Actual wattage (W)',
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
              actions: [
                PlatformDialogAction(
                  child: PlatformText('End test'),
                  onPressed: () => Navigator.pop(dialogContext),
                ),
                PlatformDialogAction(
                  child: PlatformText('Save'),
                  onPressed: () {
                    final hr = int.tryParse(_hrController.text.trim());
                    final watt = int.tryParse(_wattController.text.trim());
                    if (hr == null || hr <= 0 || watt == null || watt < 0) {
                      setDialogState(() {
                        error = 'Enter a valid heart rate and wattage.';
                      });
                      return;
                    }
                    Navigator.pop(
                      dialogContext,
                      _MeasurementInput(heartRate: hr, actualWatt: watt),
                    );
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showStageMessage() async {
    final message = _controller.pendingStageMessage;
    if (message == null) {
      return;
    }
    await showPlatformDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => PlatformAlertDialog(
        title: PlatformText('Next stage'),
        content: PlatformText(message),
        actions: [
          PlatformDialogAction(
            child: PlatformText('OK'),
            onPressed: () => Navigator.pop(dialogContext),
          ),
        ],
      ),
    );
    _controller.acknowledgeStageMessage();
  }

  Future<void> _showEndSuggestion() async {
    final shouldEnd = await showPlatformDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) => PlatformAlertDialog(
            title: PlatformText('Target heart rate reached'),
            content: PlatformText(
              'The entered heart rate reached the submaximal target '
              '(${_controller.submaxHeartRate} BPM). End the measurement?',
            ),
            actions: [
              PlatformDialogAction(
                child: PlatformText('Continue'),
                onPressed: () => Navigator.pop(dialogContext, false),
              ),
              PlatformDialogAction(
                cupertino: (_, __) =>
                    CupertinoDialogActionData(isDestructiveAction: true),
                child: PlatformText('End test'),
                onPressed: () => Navigator.pop(dialogContext, true),
              ),
            ],
          ),
        ) ??
        false;

    _controller.dismissEndSuggestion();
    if (!shouldEnd) {
      return;
    }

    // The heart rate that reached the submaximal target was just entered, so
    // reuse it as the end heart rate instead of asking for it again. Ending the
    // test transitions into recovery (recording keeps running); the page shows
    // the recovery countdown from here.
    final measurements = _controller.measurements;
    if (measurements.isNotEmpty) {
      await _controller.end(endHeartRate: measurements.last.heartRate);
    } else {
      await _endTest(requireConfirmation: false);
    }
  }

  Future<void> _confirmManualNextStage() async {
    final confirmed = await _confirm(
      title: 'Skip to next stage?',
      message: 'This advances to the next stage immediately.',
      confirmLabel: 'Next stage',
    );
    if (confirmed) {
      _controller.manualNextStage();
    }
  }

  /// Ends the test: optional confirmation, then the mandatory end heart rate.
  Future<void> _endTest({required bool requireConfirmation}) async {
    if (_endingMeasurement ||
        _stoppingRecording ||
        _controller.status != ErgoStatus.running) {
      return;
    }
    setState(() => _endingMeasurement = true);
    try {
      if (requireConfirmation) {
        final confirmed = await _confirm(
          title: 'End measurement?',
          message: 'This stops recording on all devices and ends the test.',
          confirmLabel: 'End',
          destructive: true,
        );
        if (!confirmed) {
          return;
        }
      }

      final endHeartRate = await _promptEndHeartRate();
      if (endHeartRate == null) {
        return;
      }

      // Ending transitions into the recovery phase: recording keeps running and
      // the page shows the recovery countdown. Advancing happens only once the
      // recovery is finished.
      await _controller.end(endHeartRate: endHeartRate);
    } finally {
      if (mounted) {
        setState(() => _endingMeasurement = false);
      }
    }
  }

  /// Finishes the recovery phase (countdown complete) and continues.
  Future<void> _finishRecovery() async {
    if (_stoppingRecording ||
        _controller.status != ErgoStatus.recovering ||
        _controller.isRecoveryFinished) {
      return;
    }
    setState(() => _stoppingRecording = true);
    try {
      await _controller.finishRecovery();
    } catch (e) {
      await _showError('Failed to stop the recording: $e');
    } finally {
      if (mounted) {
        setState(() => _stoppingRecording = false);
      }
    }
  }

  bool get _isPhaseNavigationLocked {
    final status = _controller.status;
    return _endingMeasurement ||
        _stoppingRecording ||
        status == ErgoStatus.running ||
        (status == ErgoStatus.recovering && !_controller.isRecoveryFinished);
  }

  Future<void> _stopForPhaseNavigation() async {
    if (_stoppingRecording) {
      return;
    }
    final shouldShowProgress = _controller.status == ErgoStatus.running ||
        _controller.status == ErgoStatus.recovering;
    if (shouldShowProgress && mounted) {
      setState(() => _stoppingRecording = true);
    }
    try {
      switch (_controller.status) {
        case ErgoStatus.idle:
        case ErgoStatus.ended:
          return;
        case ErgoStatus.running:
          await _controller.skip();
        case ErgoStatus.recovering:
          await _controller.finishRecovery();
      }
    } finally {
      if (shouldShowProgress && mounted) {
        setState(() => _stoppingRecording = false);
      }
    }
  }

  /// Undoes the last measurement/stage change so it can be re-entered.
  Future<void> _undoLast() async {
    if (!_controller.canUndo) {
      return;
    }
    final confirmed = await _confirm(
      title: 'Go back?',
      message: 'Undo the last step and re-enter it — for example to repeat a '
          'stage.',
      confirmLabel: 'Go back',
    );
    if (confirmed) {
      _controller.undoLastMeasurement();
    }
  }

  /// Goes back to the previous phase (fresh restart), like skip but backwards.
  Future<void> _previousPhase() async {
    if (_isBusy || _isPhaseNavigationLocked) {
      return;
    }
    final confirmed = await _confirm(
      title: 'Go to previous phase?',
      message: 'This stops recording and returns to the previous phase, which '
          'restarts from the beginning.',
      confirmLabel: 'Previous',
    );
    if (!confirmed) {
      return;
    }
    try {
      await _stopForPhaseNavigation();
    } catch (e) {
      await _showError('Failed to stop the recording: $e');
      return;
    }
    if (mounted) {
      goToPreviousStudyPhase(
        context: context,
        current: StudyPhase.ergometer,
        session: widget.session,
        deviceSet: widget.deviceSet,
        directory: widget.directory,
      );
    }
  }

  Future<void> _repeatPhase() async {
    if (_isBusy || _isPhaseNavigationLocked) {
      return;
    }
    final confirmed = await _confirm(
      title: 'Repeat ergometer?',
      message: 'This stops the current recording if needed and restarts the '
          'ergometer unit from its start seal check.',
      confirmLabel: 'Repeat',
    );
    if (!confirmed) {
      return;
    }
    try {
      await _stopForPhaseNavigation();
    } catch (e) {
      await _showError('Failed to stop the recording: $e');
      return;
    }
    if (mounted) {
      repeatStudyPhase(
        context: context,
        current: StudyPhase.ergometer,
        session: widget.session,
        deviceSet: widget.deviceSet,
        directory: widget.directory,
      );
    }
  }

  Future<void> _nextPhase() async {
    if (_isBusy || _isPhaseNavigationLocked) {
      return;
    }
    if (_controller.status == ErgoStatus.recovering &&
        _controller.isRecoveryFinished) {
      _advance();
      return;
    }
    if (_controller.status == ErgoStatus.ended) {
      _advance();
      return;
    }

    final confirmed = await _confirm(
      title: _controller.status == ErgoStatus.idle
          ? 'Skip ergometer?'
          : 'Continue to next phase?',
      message: _controller.status == ErgoStatus.idle
          ? 'This skips the complete ergometer unit.'
          : 'This stops the current recording and continues with the end seal '
              'check.',
      confirmLabel: 'Next',
    );
    if (!confirmed) {
      return;
    }

    try {
      await _stopForPhaseNavigation();
    } catch (e) {
      await _showError('Failed to stop the recording: $e');
      return;
    }
    if (!mounted) {
      return;
    }

    if (_controller.status == ErgoStatus.ended) {
      _advance();
    } else {
      goToNextStudyPhase(
        context: context,
        current: StudyPhase.ergometer,
        session: widget.session,
        deviceSet: widget.deviceSet,
        directory: widget.directory,
      );
    }
  }

  Future<int?> _promptEndHeartRate() async {
    _endHrController.clear();
    return showPlatformDialog<int>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        String? error;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return PlatformAlertDialog(
              title: PlatformText('End heart rate'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Enter the final heart rate to finish the test.'),
                  const SizedBox(height: 12),
                  _NumberField(
                    controller: _endHrController,
                    label: 'End heart rate (BPM)',
                    autofocus: true,
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
              actions: [
                PlatformDialogAction(
                  child: PlatformText('Cancel'),
                  onPressed: () => Navigator.pop(dialogContext),
                ),
                PlatformDialogAction(
                  child: PlatformText('Finish'),
                  onPressed: () {
                    final hr = int.tryParse(_endHrController.text.trim());
                    if (hr == null || hr <= 0) {
                      setDialogState(() => error = 'Enter a valid heart rate.');
                      return;
                    }
                    Navigator.pop(dialogContext, hr);
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<bool> _confirm({
    required String title,
    required String message,
    required String confirmLabel,
    bool destructive = false,
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
                cupertino: destructive
                    ? (_, __) =>
                        CupertinoDialogActionData(isDestructiveAction: true)
                    : null,
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

  String _formatDuration(Duration duration) {
    final totalSeconds = duration.inSeconds;
    final minutes = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final status = _controller.status;
        final isRecovering = status == ErgoStatus.recovering;
        final navigationLocked = _isPhaseNavigationLocked;
        return PopScope(
          canPop: !navigationLocked,
          onPopInvokedWithResult: (didPop, result) {},
          child: PlatformScaffold(
            material: (_, __) =>
                MaterialScaffoldData(resizeToAvoidBottomInset: false),
            cupertino: (_, __) =>
                CupertinoPageScaffoldData(resizeToAvoidBottomInset: false),
            appBar: PlatformAppBar(
              title: PlatformText(isRecovering ? 'Recovery' : 'Ergometer Test'),
              automaticallyImplyLeading: !navigationLocked,
              trailingActions: [
                // During recovery the controls live in the body; the test
                // navigation actions apply only before/while measuring.
                if (!isRecovering) ...[
                  if (_controller.canUndo)
                    PlatformTextButton(
                      onPressed: _isBusy ? null : _undoLast,
                      child: PlatformText('Undo'),
                    ),
                ],
              ],
            ),
            body: SafeArea(child: _buildBody(context)),
          ),
        );
      },
    );
  }

  Widget _buildStartScreen(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const Spacer(),
          Icon(
            Icons.directions_bike,
            size: 56,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(height: 16),
          Text(
            'Step 2 · Ergometer test',
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Modified YMCA ergometer test',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Recording starts when you start the test. Enter the heart rate and '
            'actual wattage each minute. Target heart rate: '
            '${_controller.submaxHeartRate} BPM.'
            '${widget.session.timerTestMode ? '\n\nTest mode: measurement and recovery timers use 10 seconds.' : ''}',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: PlatformElevatedButton(
              onPressed: _isBusy ? null : _start,
              child: PlatformText(
                _starting ? 'Starting…' : 'Start ergometer test',
              ),
            ),
          ),
          const SizedBox(height: 12),
          _buildPhaseNavigation(),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_starting) {
      return const Center(child: CircularProgressIndicator());
    }
    switch (_controller.status) {
      case ErgoStatus.idle:
        return _buildStartScreen(context);
      case ErgoStatus.recovering:
        return _buildRecoveryView(context);
      case ErgoStatus.running:
      case ErgoStatus.ended:
        return _buildRunningBody(context);
    }
  }

  Widget _buildRecoveryView(BuildContext context) {
    final theme = Theme.of(context);
    final finished = _controller.isRecoveryFinished;
    final recoveryProgress = finished ? 1.0 : _controller.recoveryProgress;
    final recoveryRemaining =
        finished ? Duration.zero : _controller.recoveryRemaining;
    final canRetryStop =
        !finished && _controller.recoveryRemaining <= Duration.zero;
    final canFinishEarly =
        !finished && _controller.recoveryRemaining > Duration.zero;

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
                    Text(
                      'Recovery',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      finished
                          ? 'Recovery complete. Recording has stopped — continue '
                              'to the next phase.'
                          : 'Recover and sit calmly. Recording continues on all '
                              'devices until the timer ends.',
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
                            progress: recoveryProgress,
                            label: _formatDuration(recoveryRemaining),
                            caption: finished ? 'Complete' : 'Recovery',
                          ),
                          const SizedBox(height: 16),
                          RecordingFileSizeCard(
                            sizeBytes: _controller.respibanFileSizeBytes,
                            deltaBytes: _controller.respibanFileSizeDeltaBytes,
                            isRecording: !finished,
                          ),
                          if (_controller.warning != null) ...[
                            const SizedBox(height: 20),
                            _WarningBanner(message: _controller.warning!),
                          ],
                        ],
                      ),
                    ),
                    if (canRetryStop || canFinishEarly) ...[
                      SizedBox(
                        width: double.infinity,
                        child: PlatformElevatedButton(
                          onPressed:
                              _stoppingRecording ? null : _finishRecovery,
                          child: _stoppingRecording
                              ? _BusyButtonLabel(
                                  label: 'Stopping…',
                                  color: theme.colorScheme.primary,
                                )
                              : PlatformText(
                                  canRetryStop
                                      ? 'Retry stop recording'
                                      : 'Finish recovery early',
                                ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    _buildPhaseNavigation(highlightNext: finished),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildRunningBody(BuildContext context) {
    final measurements = _controller.measurements;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Column(
            children: [
              _TargetHeartRateCard(
                submaxHeartRate: _controller.submaxHeartRate,
                maxHeartRate: _controller.maxHeartRate,
              ),
              const SizedBox(height: 12),
              _StageCard(
                stage: _controller.currentStage,
                targetWatt: _controller.currentTargetWatt,
                totalElapsed: _formatDuration(_controller.elapsed),
                nextMeasurementIn: _formatDuration(
                  _controller.timeToNextMeasurement,
                ),
              ),
              const SizedBox(height: 12),
              RecordingFileSizeCard(
                sizeBytes: _controller.respibanFileSizeBytes,
                deltaBytes: _controller.respibanFileSizeDeltaBytes,
                isRecording: _controller.status == ErgoStatus.running,
              ),
              if (_controller.warning != null) ...[
                const SizedBox(height: 12),
                _WarningBanner(message: _controller.warning!),
              ],
            ],
          ),
        ),
        Expanded(child: _HistoryList(measurements: measurements)),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: PlatformElevatedButton(
                        onPressed: _isBusy ? null : _confirmManualNextStage,
                        material: (_, __) => MaterialElevatedButtonData(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(
                              context,
                            ).colorScheme.secondaryContainer,
                            foregroundColor: Theme.of(
                              context,
                            ).colorScheme.onSecondaryContainer,
                          ),
                        ),
                        child: PlatformText('Next stage'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: PlatformElevatedButton(
                        onPressed: _isBusy
                            ? null
                            : () => _endTest(requireConfirmation: true),
                        material: (_, __) => MaterialElevatedButtonData(
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                Theme.of(context).colorScheme.error,
                            foregroundColor:
                                Theme.of(context).colorScheme.onError,
                          ),
                        ),
                        child: _endingMeasurement
                            ? _BusyButtonLabel(
                                label: 'Ending…',
                                color: Theme.of(context).colorScheme.primary,
                              )
                            : PlatformText('End test'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _buildPhaseNavigation(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPhaseNavigation({bool highlightNext = false}) {
    final navigationLocked = _isBusy || _isPhaseNavigationLocked;
    return Row(
      children: [
        Expanded(
          child: PlatformTextButton(
            onPressed: navigationLocked ? null : _previousPhase,
            child: const _NavigationButtonLabel(
              icon: Icons.arrow_back,
              label: 'Previous',
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: PlatformTextButton(
            onPressed: navigationLocked ? null : _repeatPhase,
            child: const _NavigationButtonLabel(
              icon: Icons.replay,
              label: 'Repeat',
              iconAfterLabel: true,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: highlightNext
              ? PlatformElevatedButton(
                  onPressed: navigationLocked ? null : _nextPhase,
                  child: const _NavigationButtonLabel(
                    icon: Icons.arrow_forward,
                    label: 'Next',
                    iconAfterLabel: true,
                  ),
                )
              : PlatformTextButton(
                  onPressed: navigationLocked ? null : _nextPhase,
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

class _NumberField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final bool autofocus;

  const _NumberField({
    required this.controller,
    required this.label,
    this.autofocus = false,
  });

  @override
  Widget build(BuildContext context) {
    return PlatformTextField(
      controller: controller,
      autofocus: autofocus,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      hintText: label,
      material: (_, __) =>
          MaterialTextFieldData(decoration: InputDecoration(labelText: label)),
    );
  }
}

class _TargetHeartRateCard extends StatelessWidget {
  final int submaxHeartRate;
  final int maxHeartRate;

  const _TargetHeartRateCard({
    required this.submaxHeartRate,
    required this.maxHeartRate,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF835B58), Color(0xFFB48A86)],
        ),
      ),
      child: Column(
        children: [
          Text(
            'Target heart rate (submax)',
            style: theme.textTheme.labelLarge?.copyWith(
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$submaxHeartRate BPM',
            style: theme.textTheme.displaySmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            'Max HR $maxHeartRate BPM',
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.white.withValues(alpha: 0.85),
            ),
          ),
        ],
      ),
    );
  }
}

class _StageCard extends StatelessWidget {
  final int stage;
  final int? targetWatt;
  final String totalElapsed;
  final String nextMeasurementIn;

  const _StageCard({
    required this.stage,
    required this.targetWatt,
    required this.totalElapsed,
    required this.nextMeasurementIn,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final stageLabel = stage == 0 ? 'Warm-up' : 'Stage $stage';
    final wattLabel =
        targetWatt == null ? 'Set resistance' : 'Set $targetWatt W';

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total time',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  totalElapsed,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontFeatures: const [FontFeature.tabularFigures()],
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const Divider(height: 18),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        stageLabel,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        wattLabel,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Next measurement',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      nextMeasurementIn,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontFeatures: const [FontFeature.tabularFigures()],
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryList extends StatelessWidget {
  final List<ErgoMeasurement> measurements;

  const _HistoryList({required this.measurements});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (measurements.isEmpty) {
      return Center(
        child: Text(
          'Measurements will appear here every minute.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    final reversed = measurements.reversed.toList(growable: false);
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: reversed.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return _HistoryRow(
            cells: const ['Min', 'Stage', 'Watt', 'HR'],
            isHeader: true,
          );
        }
        final measurement = reversed[index - 1];
        return _HistoryRow(
          cells: [
            '${measurement.minute}',
            measurement.stage == 0 ? 'WU' : '${measurement.stage}',
            '${measurement.actualWatt}',
            '${measurement.heartRate}',
          ],
        );
      },
    );
  }
}

class _HistoryRow extends StatelessWidget {
  final List<String> cells;
  final bool isHeader;

  const _HistoryRow({required this.cells, this.isHeader = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = isHeader
        ? theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700)
        : theme.textTheme.bodyMedium;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          for (final cell in cells) Expanded(child: Text(cell, style: style)),
        ],
      ),
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
      width: double.infinity,
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
