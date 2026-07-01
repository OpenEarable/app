import 'package:share_plus/share_plus.dart';

import 'package:open_wearable/widgets/sensors/local_recorder/local_recorder_file_actions.dart';
import 'package:open_wearable/widgets/sensors/local_recorder/local_recorder_models.dart';
import 'package:open_wearable/widgets/sensors/local_recorder/local_recorder_storage.dart';

/// Shares all files of a study recording, using the recording folder name as
/// the share subject so the recording is identified by its proband/session.
Future<void> shareStudyFolder(LocalRecorderRecordingFolder folder) async {
  final files = <XFile>[];
  for (final file in folder.files) {
    final bytes = await readRecordingFileBytes(file);
    files.add(XFile.fromData(bytes, name: file.name, mimeType: file.mimeType));
  }
  await SharePlus.instance.share(
    ShareParams(files: files, subject: folder.name),
  );
}

/// Shares a single study recording file, using the file name as the subject.
Future<void> shareStudyFile(LocalRecorderRecordingFile file) async {
  final bytes = await readRecordingFileBytes(file);
  await SharePlus.instance.share(
    ShareParams(
      files: [
        XFile.fromData(bytes, name: file.name, mimeType: file.mimeType),
      ],
      subject: file.name,
    ),
  );
}

/// Opens a study recording file with the platform default handler.
Future<void> openStudyFile(LocalRecorderRecordingFile file) =>
    localRecorderOpenRecordingFile(file);
