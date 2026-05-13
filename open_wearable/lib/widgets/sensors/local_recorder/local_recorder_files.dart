import 'local_recorder_storage.dart';

class Files {
  static Future<String?> pickDirectory() => pickRecordingDirectory();

  static Future<bool> isDirectoryEmpty(String path) =>
      isRecordingDirectoryEmpty(path);
}
