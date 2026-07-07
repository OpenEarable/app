import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart';

import 'package:open_wearable/apps/audio_response_measure/audio_response_measurement_view.dart';
import 'package:open_wearable/apps/study_protocol/model/study_devices.dart';
import 'package:open_wearable/apps/study_protocol/model/study_seal_check_storage.dart';
import 'package:open_wearable/apps/study_protocol/model/study_session.dart';

enum StudySealCheckPosition {
  start('start', 'Before'),
  end('end', 'After');

  final String filenameToken;
  final String label;

  const StudySealCheckPosition(this.filenameToken, this.label);
}

/// Mandatory seal check immediately before or after a DecoupEar phase.
class StudySealCheckPage extends StatelessWidget {
  final String phaseName;
  final String phaseTitle;
  final StudySealCheckPosition position;
  final StudySession session;
  final StudyDeviceSet deviceSet;
  final String directory;
  final String actionLabel;
  final VoidCallback onContinue;
  final VoidCallback? onSkip;

  const StudySealCheckPage({
    super.key,
    required this.phaseName,
    required this.phaseTitle,
    required this.position,
    required this.session,
    required this.deviceSet,
    required this.directory,
    required this.actionLabel,
    required this.onContinue,
    this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    final left = deviceSet.earables.left.getCapability<AudioResponseManager>();
    final right =
        deviceSet.earables.right.getCapability<AudioResponseManager>();

    if (left == null || right == null) {
      return PlatformScaffold(
        appBar: PlatformAppBar(title: PlatformText('Seal check')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'The seal check is unavailable. Both OpenEarables must expose '
              'the Audio Response capability.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return AudioResponseMeasurementView(
      left: left,
      right: right,
      title: '$phaseTitle seal check · ${position.label}',
      saveResult: (result) => saveStudySealCheckResult(
        directory: directory,
        probandId: session.probandId,
        phase: phaseName,
        position: position.filenameToken,
        result: result,
      ),
      resultActionLabel: actionLabel,
      onResultAction: onContinue,
      preMeasurementAction: onSkip,
      preMeasurementActionLabel: 'Skip $phaseTitle unit',
    );
  }
}
