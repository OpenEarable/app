import 'dart:html' as html;

import 'package:share_plus/share_plus.dart';

import 'local_recorder_models.dart';
import 'local_recorder_storage.dart';

Future<void> localRecorderShareFile(LocalRecorderRecordingFile file) async {
  final bytes = await readRecordingFileBytes(file);
  await SharePlus.instance.share(
    ShareParams(
      files: [
        XFile.fromData(
          bytes,
          name: file.name,
          mimeType: file.mimeType,
        ),
      ],
      subject: 'OpenWearable Recording File',
    ),
  );
}

Future<void> localRecorderShareFolder(LocalRecorderRecordingFolder folder) async {
  final files = <XFile>[];
  for (final file in folder.files) {
    final bytes = await readRecordingFileBytes(file);
    files.add(
      XFile.fromData(
        bytes,
        name: file.name,
        mimeType: file.mimeType,
      ),
    );
  }

  await SharePlus.instance.share(
    ShareParams(
      files: files,
      subject: 'OpenWearable Recording',
    ),
  );
}

Future<void> localRecorderOpenRecordingFile(LocalRecorderRecordingFile file) async {
  final bytes = await readRecordingFileBytes(file);
  final blob = html.Blob([bytes], file.mimeType);
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.window.open(url, '_blank');
}