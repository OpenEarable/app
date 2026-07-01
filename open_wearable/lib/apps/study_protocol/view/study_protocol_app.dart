import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';

import 'package:open_wearable/apps/study_protocol/view/study_recordings_list_page.dart';

/// Entry point for the study protocol app.
///
/// The recordings list is always available so past recordings can be browsed,
/// shared and deleted without any device connected. The device requirement (a
/// stereo pair of OpenEarables plus a Plux RESPIRABAN) is enforced only when
/// the user starts a new recording.
class StudyProtocolApp extends StatelessWidget {
  const StudyProtocolApp({super.key});

  @override
  Widget build(BuildContext context) {
    return PlatformScaffold(
      appBar: PlatformAppBar(
        title: PlatformText('Study Protocol'),
      ),
      body: const StudyRecordingsList(),
    );
  }
}
