import 'package:flutter/widgets.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';

import 'package:open_wearable/apps/study_protocol/model/study_devices.dart';
import 'package:open_wearable/apps/study_protocol/model/study_session.dart';
import 'package:open_wearable/apps/study_protocol/view/study_seal_check_page.dart';
import 'package:open_wearable/apps/study_protocol/view/timed_phase_page.dart';
import 'package:open_wearable/apps/study_protocol/view/ymca_ergometer_page.dart';

/// Ordered phases of one study session.
///
/// Each phase is a separate recording; all recordings are written into the same
/// session directory. The recovery phase is part of the ergometer test (it runs
/// automatically when the test ends, on the same recording), so it is not a
/// separate phase here.
enum StudyPhase { baseline, ergometer, treadmill }

/// The order in which phases run.
const List<StudyPhase> studyPhaseOrder = [
  StudyPhase.baseline,
  StudyPhase.ergometer,
  StudyPhase.treadmill,
];

extension StudyPhaseInfo on StudyPhase {
  String get title => switch (this) {
        StudyPhase.baseline => 'Baseline',
        StudyPhase.ergometer => 'Ergometer',
        StudyPhase.treadmill => 'Treadmill',
      };
}

/// Static configuration for a fixed-duration recording phase.
class TimedPhaseConfig {
  final String title;
  final String stepLabel;
  final String instruction;
  final Duration duration;
  final String respibanFileLabel;
  final String earablePrefixSuffix;

  const TimedPhaseConfig({
    required this.title,
    required this.stepLabel,
    required this.instruction,
    required this.duration,
    required this.respibanFileLabel,
    required this.earablePrefixSuffix,
  });
}

/// Configuration for the timed phases (the ergometer test has its own page).
const Map<StudyPhase, TimedPhaseConfig> studyTimedPhaseConfigs = {
  StudyPhase.baseline: TimedPhaseConfig(
    title: 'Baseline',
    stepLabel: 'Step 1 · Baseline',
    instruction: 'Sit still and breathe normally for 15 minutes. '
        'The recording stops automatically when the timer ends.',
    duration: Duration(minutes: 15),
    respibanFileLabel: 'baseline',
    earablePrefixSuffix: 'base_',
  ),
  StudyPhase.treadmill: TimedPhaseConfig(
    title: 'Treadmill',
    stepLabel: 'Step 3 · Treadmill',
    instruction: 'Run on the treadmill for 5 minutes. '
        'The recording stops automatically when the timer ends.',
    duration: Duration(minutes: 5),
    respibanFileLabel: 'treadmill',
    earablePrefixSuffix: 'tread_',
  ),
};

/// Builds the page for [phase].
Widget buildStudyPhasePage({
  required StudyPhase phase,
  required StudySession session,
  required StudyDeviceSet deviceSet,
  required String directory,
}) {
  if (phase == StudyPhase.ergometer) {
    return YmcaErgometerPage(
      session: session,
      deviceSet: deviceSet,
      directory: directory,
    );
  }
  return TimedPhasePage(
    phase: phase,
    config: studyTimedPhaseConfigs[phase]!,
    session: session,
    deviceSet: deviceSet,
    directory: directory,
  );
}

/// Builds the mandatory seal check that precedes [phase].
Widget buildStudyPhaseEntryPage({
  required StudyPhase phase,
  required StudySession session,
  required StudyDeviceSet deviceSet,
  required String directory,
}) {
  return Builder(
    builder: (context) => StudySealCheckPage(
      phaseName: phase.name,
      phaseTitle: phase.title,
      position: StudySealCheckPosition.start,
      session: session,
      deviceSet: deviceSet,
      directory: directory,
      actionLabel: 'Start ${phase.title.toLowerCase()}',
      onSkip: () async {
        final shouldSkip = await showPlatformDialog<bool>(
              context: context,
              builder: (dialogContext) => PlatformAlertDialog(
                title: PlatformText('Skip ${phase.title} unit?'),
                content: PlatformText(
                  'This skips the complete unit: start seal check, '
                  '${phase.title.toLowerCase()} phase, and end seal check.',
                ),
                actions: [
                  PlatformDialogAction(
                    child: PlatformText('Cancel'),
                    onPressed: () => Navigator.pop(dialogContext, false),
                  ),
                  PlatformDialogAction(
                    child: PlatformText('Skip unit'),
                    onPressed: () => Navigator.pop(dialogContext, true),
                  ),
                ],
              ),
            ) ??
            false;
        if (!shouldSkip || !context.mounted) {
          return;
        }
        _skipStudyPhaseUnit(
          context: context,
          current: phase,
          session: session,
          deviceSet: deviceSet,
          directory: directory,
        );
      },
      onContinue: () {
        Navigator.of(context).pushReplacement(
          platformPageRoute(
            context: context,
            builder: (_) => buildStudyPhasePage(
              phase: phase,
              session: session,
              deviceSet: deviceSet,
              directory: directory,
            ),
          ),
        );
      },
    ),
  );
}

void _skipStudyPhaseUnit({
  required BuildContext context,
  required StudyPhase current,
  required StudySession session,
  required StudyDeviceSet deviceSet,
  required String directory,
}) {
  final index = studyPhaseOrder.indexOf(current);
  if (index < 0 || index + 1 >= studyPhaseOrder.length) {
    Navigator.of(context).pop();
    return;
  }
  final next = studyPhaseOrder[index + 1];
  Navigator.of(context).pushReplacement(
    platformPageRoute(
      context: context,
      builder: (_) => buildStudyPhaseEntryPage(
        phase: next,
        session: session,
        deviceSet: deviceSet,
        directory: directory,
      ),
    ),
  );
}

Widget _buildStudyPhaseExitPage({
  required StudyPhase phase,
  required StudySession session,
  required StudyDeviceSet deviceSet,
  required String directory,
}) {
  final index = studyPhaseOrder.indexOf(phase);
  final hasNextPhase = index >= 0 && index + 1 < studyPhaseOrder.length;

  return Builder(
    builder: (context) => StudySealCheckPage(
      phaseName: phase.name,
      phaseTitle: phase.title,
      position: StudySealCheckPosition.end,
      session: session,
      deviceSet: deviceSet,
      directory: directory,
      actionLabel: hasNextPhase ? 'Continue' : 'Finish protocol',
      onContinue: () {
        if (!hasNextPhase) {
          Navigator.of(context).pop();
          return;
        }
        final next = studyPhaseOrder[index + 1];
        Navigator.of(context).pushReplacement(
          platformPageRoute(
            context: context,
            builder: (_) => buildStudyPhaseEntryPage(
              phase: next,
              session: session,
              deviceSet: deviceSet,
              directory: directory,
            ),
          ),
        );
      },
    ),
  );
}

/// Advances from [current] to the next phase, or returns to the recordings list
/// when [current] is the final phase.
void advanceStudyPhase({
  required BuildContext context,
  required StudyPhase current,
  required StudySession session,
  required StudyDeviceSet deviceSet,
  required String directory,
}) {
  // Every entered phase passes through its mandatory end check. Whole-unit
  // skips are handled before the start seal check and bypass this page.
  Navigator.of(context).pushReplacement(
    platformPageRoute(
      context: context,
      builder: (_) => _buildStudyPhaseExitPage(
        phase: current,
        session: session,
        deviceSet: deviceSet,
        directory: directory,
      ),
    ),
  );
}

/// Goes back from [current] to the previous phase, or returns to the recordings
/// list when [current] is the first phase. The previous phase restarts fresh.
void goToPreviousStudyPhase({
  required BuildContext context,
  required StudyPhase current,
  required StudySession session,
  required StudyDeviceSet deviceSet,
  required String directory,
}) {
  final index = studyPhaseOrder.indexOf(current);
  if (index <= 0) {
    Navigator.of(context).pop();
    return;
  }
  final previous = studyPhaseOrder[index - 1];
  Navigator.of(context).pushReplacement(
    platformPageRoute(
      context: context,
      builder: (_) => buildStudyPhaseEntryPage(
        phase: previous,
        session: session,
        deviceSet: deviceSet,
        directory: directory,
      ),
    ),
  );
}
