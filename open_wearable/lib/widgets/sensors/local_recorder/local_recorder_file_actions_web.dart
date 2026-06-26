import 'dart:js_interop';

import 'package:share_plus/share_plus.dart';
import 'package:web/web.dart' as web;

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
      subject: 'OpenWearables Recording File',
    ),
  );
}

Future<void> localRecorderShareFolder(
  LocalRecorderRecordingFolder folder,
) async {
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
      subject: 'OpenWearables Recording',
    ),
  );
}

Future<void> localRecorderOpenRecordingFile(
  LocalRecorderRecordingFile file,
) async {
  final bytes = await readRecordingFileBytes(file);
  final blob = web.Blob(
    <JSUint8Array>[bytes.toJS].toJS,
    web.BlobPropertyBag(type: file.mimeType),
  );
  final url = web.URL.createObjectURL(blob);
  web.window.open(url, '_blank');
}
