import 'dart:io';

import 'package:flutter_archive/flutter_archive.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

Future<void> localRecorderShareFile(File file) async {
  await SharePlus.instance.share(
    ShareParams(
      files: [XFile(file.path)],
      subject: 'OpenWearable Recording File',
    ),
  );
}

Future<void> localRecorderShareFolder(Directory folder) async {
  final tempDir = await getTemporaryDirectory();
  final zipPath = '${tempDir.path}/${folder.path.split(RegExp(r"[\\\\/]+")).last}.zip';
  final zipFile = File(zipPath);

  await ZipFile.createFromDirectory(
    sourceDir: folder,
    zipFile: zipFile,
    recurseSubDirs: true,
  );

  try {
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(zipFile.path)],
        subject: 'OpenWearable Recording',
      ),
    );
  } finally {
    if (await zipFile.exists()) {
      await zipFile.delete();
    }
  }
}

Future<OpenResult> localRecorderOpenRecordingFile(File file) {
  return OpenFile.open(
    file.path,
    type: 'text/comma-separated-values',
  );
}
