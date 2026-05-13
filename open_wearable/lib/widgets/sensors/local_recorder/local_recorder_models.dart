class LocalRecorderRecordingFile {
  final String path;
  final String name;
  final int sizeBytes;
  final DateTime updatedAt;
  final String mimeType;

  const LocalRecorderRecordingFile({
    required this.path,
    required this.name,
    required this.sizeBytes,
    required this.updatedAt,
    this.mimeType = 'text/csv',
  });
}

class LocalRecorderRecordingFolder {
  final String path;
  final String name;
  final DateTime updatedAt;
  final List<LocalRecorderRecordingFile> files;

  const LocalRecorderRecordingFolder({
    required this.path,
    required this.name,
    required this.updatedAt,
    required this.files,
  });
}

class LocalRecorderDraftFile {
  final String name;
  final String content;
  final String mimeType;

  const LocalRecorderDraftFile({
    required this.name,
    required this.content,
    this.mimeType = 'text/csv',
  });
}

String localRecorderBasename(String path) =>
    path.split(RegExp(r'[\\/]+')).last;

String localRecorderFormatFileSize(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

String localRecorderFormatDateTime(DateTime value) {
  final local = value.toLocal();
  String twoDigits(int n) => n.toString().padLeft(2, '0');
  return '${local.year}-${twoDigits(local.month)}-${twoDigits(local.day)} '
      '${twoDigits(local.hour)}:${twoDigits(local.minute)}';
}