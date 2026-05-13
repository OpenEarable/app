import 'dart:convert';
import 'dart:typed_data';

import 'package:shared_preferences/shared_preferences.dart';

import 'local_recorder_models.dart';

const String _storageKey = 'open_wearable.local_recorder.web_recordings.v1';

Future<String?> pickRecordingDirectory() async {
  final prefs = await SharedPreferences.getInstance();
  final folder = _createFolder(name: _recordingFolderName());
  final folders = _readFolders(prefs);
  folders.removeWhere((entry) => entry.path == folder.path);
  folders.add(folder);
  await _writeFolders(prefs, folders);
  return folder.path;
}

Future<List<LocalRecorderRecordingFolder>> listRecordingFolders() async {
  final prefs = await SharedPreferences.getInstance();
  final folders = _readFolders(prefs)
    ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  return folders;
}

Future<bool> isRecordingDirectoryEmpty(String path) async {
  final prefs = await SharedPreferences.getInstance();
  final folders = _readFolders(prefs);
  final match = folders.where((entry) => entry.path == path).toList();
  return match.isEmpty || match.first.files.isEmpty;
}

Future<void> deleteRecordingFolder(String path) async {
  final prefs = await SharedPreferences.getInstance();
  final folders = _readFolders(prefs)
    ..removeWhere((entry) => entry.path == path);
  await _writeFolders(prefs, folders);
}

Future<void> persistRecordingFolderFiles(
  String path,
  List<LocalRecorderDraftFile> files,
) async {
  final prefs = await SharedPreferences.getInstance();
  final folders = _readFolders(prefs);
  final folderIndex = folders.indexWhere((entry) => entry.path == path);
  final updatedFolder = _createFolder(
    name: _recordingFolderName(),
    path: path,
    files: files,
  );

  if (folderIndex == -1) {
    folders.add(updatedFolder);
  } else {
    folders[folderIndex] = updatedFolder;
  }

  await _writeFolders(prefs, folders);
}

Future<Uint8List> readRecordingFileBytes(
    LocalRecorderRecordingFile file) async {
  final prefs = await SharedPreferences.getInstance();
  final folders = _readFolders(prefs);
  for (final folder in folders) {
    final selected = folder.files.where((entry) => entry.path == file.path);
    if (selected.isNotEmpty) {
      final recordingFile = selected.first;
      if (recordingFile is _WebRecordingFile) {
        return base64Decode(recordingFile.contentBase64);
      }
      break;
    }
  }
  throw StateError('Recording file not found');
}

Future<String> readRecordingFileText(LocalRecorderRecordingFile file) async {
  return utf8.decode(await readRecordingFileBytes(file));
}

LocalRecorderRecordingFolder _createFolder({
  required String name,
  String? path,
  List<LocalRecorderDraftFile> files = const [],
}) {
  final folderPath = path ?? 'web-${DateTime.now().microsecondsSinceEpoch}';
  final now = DateTime.now();
  final recordingFiles = files
      .map(
        (file) => _WebRecordingFile(
          path: '$folderPath/${file.name}',
          name: file.name,
          sizeBytes: utf8.encode(file.content).length,
          updatedAt: now,
          mimeType: file.mimeType,
          contentBase64: base64Encode(utf8.encode(file.content)),
        ),
      )
      .toList();

  return LocalRecorderRecordingFolder(
    path: folderPath,
    name: name,
    updatedAt: now,
    files: recordingFiles,
  );
}

String _recordingFolderName() {
  final timestamp = DateTime.now().toIso8601String();
  return 'OpenWearable_Recording_$timestamp';
}

List<LocalRecorderRecordingFolder> _readFolders(SharedPreferences prefs) {
  final raw = prefs.getString(_storageKey);
  if (raw == null || raw.isEmpty) {
    return <LocalRecorderRecordingFolder>[];
  }

  final decoded = jsonDecode(raw);
  if (decoded is! Map<String, dynamic>) {
    return <LocalRecorderRecordingFolder>[];
  }

  final folders = decoded['folders'];
  if (folders is! List) {
    return <LocalRecorderRecordingFolder>[];
  }

  return folders.whereType<Map>().map(_folderFromJson).toList();
}

Future<void> _writeFolders(
  SharedPreferences prefs,
  List<LocalRecorderRecordingFolder> folders,
) async {
  final payload = <String, dynamic>{
    'folders': folders.map(_folderToJson).toList(),
  };
  await prefs.setString(_storageKey, jsonEncode(payload));
}

Map<String, dynamic> _folderToJson(LocalRecorderRecordingFolder folder) {
  return <String, dynamic>{
    'path': folder.path,
    'name': folder.name,
    'updatedAt': folder.updatedAt.toIso8601String(),
    'files': folder.files.map(_fileToJson).toList(),
  };
}

Map<String, dynamic> _fileToJson(LocalRecorderRecordingFile file) {
  if (file is _WebRecordingFile) {
    return <String, dynamic>{
      'path': file.path,
      'name': file.name,
      'sizeBytes': file.sizeBytes,
      'updatedAt': file.updatedAt.toIso8601String(),
      'mimeType': file.mimeType,
      'contentBase64': file.contentBase64,
    };
  }

  return <String, dynamic>{
    'path': file.path,
    'name': file.name,
    'sizeBytes': file.sizeBytes,
    'updatedAt': file.updatedAt.toIso8601String(),
    'mimeType': file.mimeType,
    'contentBase64': '',
  };
}

LocalRecorderRecordingFolder _folderFromJson(Map json) {
  final files = (json['files'] as List? ?? const [])
      .whereType<Map>()
      .map(_fileFromJson)
      .toList();

  return LocalRecorderRecordingFolder(
    path: json['path'] as String? ?? 'unknown',
    name: json['name'] as String? ?? 'Recording',
    updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0),
    files: files,
  );
}

LocalRecorderRecordingFile _fileFromJson(Map json) {
  return _WebRecordingFile(
    path: json['path'] as String? ?? 'unknown/file.csv',
    name: json['name'] as String? ?? 'file.csv',
    sizeBytes: (json['sizeBytes'] as num?)?.toInt() ?? 0,
    updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0),
    mimeType: json['mimeType'] as String? ?? 'text/csv',
    contentBase64: json['contentBase64'] as String? ?? '',
  );
}

class _WebRecordingFile extends LocalRecorderRecordingFile {
  final String contentBase64;

  const _WebRecordingFile({
    required super.path,
    required super.name,
    required super.sizeBytes,
    required super.updatedAt,
    required this.contentBase64,
    super.mimeType = 'text/csv',
  });
}
