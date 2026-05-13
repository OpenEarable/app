import 'package:open_file/open_file.dart';
import 'package:share_plus/share_plus.dart';

import 'local_recorder_models.dart';

Future<void> localRecorderShareFile(LocalRecorderRecordingFile file) async {
  await SharePlus.instance.share(
    ShareParams(
      files: [XFile(file.path)],
      subject: 'OpenWearable Recording File',
    ),
  );
}

Future<void> localRecorderShareFolder(LocalRecorderRecordingFolder folder) async {
  await SharePlus.instance.share(
    ShareParams(
      files: folder.files.map((entry) => XFile(entry.path)).toList(),
      subject: 'OpenWearable Recording',
    ),
  );
}

Future<void> localRecorderOpenRecordingFile(LocalRecorderRecordingFile file) async {
  final result = await OpenFile.open(
    file.path,
    type: 'text/comma-separated-values',
  );

  if (result.type != ResultType.done) {
    throw StateError(result.message);
  }
}