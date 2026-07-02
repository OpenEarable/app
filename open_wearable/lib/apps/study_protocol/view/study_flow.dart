import 'package:flutter/widgets.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';

import 'package:open_wearable/apps/study_protocol/model/study_devices.dart';
import 'package:open_wearable/apps/study_protocol/model/study_session.dart';
import 'package:open_wearable/apps/study_protocol/view/timed_phase_page.dart';
import 'package:open_wearable/apps/study_protocol/view/ymca_ergometer_page.dart';

/// Ordered phases of one study session.
///
/// Each phase is a separate recording; all recordings are written into the same
/// session directory.
enum StudyPhase { baseline, ergometer, recovery, treadmill }

/// The order in which phases run.
const List<StudyPhase> studyPhaseOrder = [
  StudyPhase.baseline,
  StudyPhase.ergometer,
  StudyPhase.recovery,
  StudyPhase.treadmill,
];

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
  StudyPhase.recovery: TimedPhaseConfig(
    title: 'Recovery',
    stepLabel: 'Step 3 · Recovery',
    instruction: 'Recover and sit calmly for 15 minutes. '
        'The recording stops automatically when the timer ends.',
    duration: Duration(minutes: 15),
    respibanFileLabel: 'recovery',
    earablePrefixSuffix: 'rec_',
  ),
  StudyPhase.treadmill: TimedPhaseConfig(
    title: 'Treadmill',
    stepLabel: 'Step 4 · Treadmill',
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

/// Advances from [current] to the next phase, or returns to the recordings list
/// when [current] is the final phase.
void advanceStudyPhase({
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
  // Replace so back navigation does not return to a finished phase.
  Navigator.of(context).pushReplacement(
    platformPageRoute(
      context: context,
      builder: (_) => buildStudyPhasePage(
        phase: next,
        session: session,
        deviceSet: deviceSet,
        directory: directory,
      ),
    ),
  );
}
