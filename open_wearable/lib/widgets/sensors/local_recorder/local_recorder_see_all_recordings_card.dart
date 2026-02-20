import 'package:flutter/material.dart';
import 'package:open_wearable/widgets/sensors/sensor_page_spacing.dart';

class LocalRecorderSeeAllRecordingsTile extends StatelessWidget {
  final int recordingCount;
  final VoidCallback onTap;

  const LocalRecorderSeeAllRecordingsTile({
    super.key,
    required this.recordingCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (recordingCount <= 1) {
      return const SizedBox.shrink();
    }

    return Card(
      margin: const EdgeInsets.only(bottom: SensorPageSpacing.sectionGap),
      child: ListTile(
        leading: const Icon(Icons.folder_copy_outlined),
        title: const Text('See all recordings'),
        subtitle: Text('$recordingCount recording folders'),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: onTap,
      ),
    );
  }
}
