import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:logger/logger.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:open_wearable/view_models/sensor_recorder_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_archive/flutter_archive.dart';

Logger _logger = Logger();

class LocalRecorderView extends StatefulWidget {
  const LocalRecorderView({super.key});

  @override
  State<LocalRecorderView> createState() => _LocalRecorderViewState();
}

class _LocalRecorderViewState extends State<LocalRecorderView> {
  static const MethodChannel platform = MethodChannel('edu.teco.open_folder');
  List<FileSystemEntity> _recordings = [];
  Set<String> _expandedFolders = {}; // Track which folders are expanded

  @override
  void initState() {
    super.initState();
    _listRecordings();
  }

  Future<void> _openFolder(String path) async {
    try {
      if (Platform.isIOS) {
        await platform
            .invokeMethod('openFolder', {'path': "shareddocuments://$path"});
      } else if (Platform.isAndroid) {
        await platform.invokeMethod('openFolder', {'path': path});
      }
    } on PlatformException catch (e) {
      print("Failed to open folder: '${e.message}'.");
    }
  }

  Future<void> _listRecordings() async {
    Directory recordingsDir;

    if (Platform.isAndroid) {
      Directory? dir = await getExternalStorageDirectory();
      if (dir == null) return;
      recordingsDir = dir;
    } else if (Platform.isIOS) {
      recordingsDir = await getIOSDirectory();
    } else {
      return;
    }

    if (!await recordingsDir.exists()) {
      setState(() {
        _recordings = [];
      });
      return;
    }

    List<FileSystemEntity> entities = recordingsDir.listSync();

    // Filter only directories that start with "OpenWearable_Recording"
    _recordings = entities
        .where((entity) =>
            entity is Directory &&
            entity.path.contains('OpenWearable_Recording'))
        .toList();

    // Sort by modification time (newest first)
    _recordings.sort((a, b) {
      return b.statSync().changed.compareTo(a.statSync().changed);
    });

    setState(() {});
  }

  List<FileSystemEntity> _getFilesInFolder(Directory folder) {
    try {
      return folder.listSync(recursive: false).whereType<File>().toList()
        ..sort(
          (a, b) => a.path.split('/').last.compareTo(b.path.split('/').last),
        );
    } catch (e) {
      _logger.e('Error listing files in folder: $e');
      return [];
    }
  }

  void _deleteRecording(FileSystemEntity entity) async {
    if (entity.existsSync()) {
      try {
        if (entity is Directory) {
          entity.deleteSync(recursive: true);
        } else {
          entity.deleteSync();
        }
        _listRecordings();
      } catch (e) {
        _logger.e('Error deleting recording: $e');
      }
    }
  }

  String _formatFileSize(File file) {
    int bytes = file.lengthSync();
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Future<void> _shareFile(File file) async {
    try {
      final result = await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          subject: 'OpenWearable Recording File',
        ),
      );

      if (result.status == ShareResultStatus.success) {
        _logger.i('File shared successfully');
      }
    } catch (e) {
      _logger.e('Error sharing file: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to share file: $e')),
        );
      }
    }
  }

  Future<void> _shareFolder(Directory folder) async {
    try {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Creating zip file...')),
        );
      }

      final tempDir = await getTemporaryDirectory();
      final zipPath = '${tempDir.path}/${folder.path.split("/").last}.zip';
      final zipFile = File(zipPath);

      await ZipFile.createFromDirectory(
        sourceDir: folder,
        zipFile: zipFile,
        recurseSubDirs: true,
      );

      final result = await SharePlus.instance.share(
        ShareParams(
          files: [XFile(zipFile.path)],
          subject: 'OpenWearable Recording',
        ),
      );

      if (result.status == ShareResultStatus.success) {
        _logger.i('Folder shared successfully');
      }

      if (await zipFile.exists()) {
        await zipFile.delete();
      }
    } catch (e) {
      _logger.e('Error sharing folder: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to share folder: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SensorRecorderProvider>(
      builder: (context, recorder, _) {
        final isRecording = recorder.isRecording;
        final canRecord = recorder.hasSensorsConnected || isRecording;

        final tileColor = isRecording ? Colors.green.shade300 : null;
        final icon = isRecording ? Icons.stop : Icons.fiber_manual_record;
        final iconColor = isRecording
            ? Colors.white
            : (recorder.hasSensorsConnected ? Colors.red : Colors.grey);

        final subtitle = isRecording
            ? 'Tap to stop recording'
            : recorder.hasSensorsConnected
                ? 'Tap to start recording'
                : 'Connect a device to enable recording';

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(10),
              child: Card(
                color: tileColor,
                child: ListTile(
                  //enabled: canRecord,
                  title: PlatformText('Local Recorder'),
                  subtitle: PlatformText(subtitle),
                  trailing: Icon(icon, color: iconColor),
                  onTap: !canRecord
                      ? () {
                          _logger.w('Recording not available');
                        }
                      : () async {
                          if (isRecording) {
                            _logger.i('Stopping local recording');
                            recorder.stopRecording();
                            await _listRecordings(); // Refresh list
                            return;
                          }

                          final dir = await _pickDirectory();
                          if (dir == null) return;

                          // Check if directory is empty
                          if (!await _isDirectoryEmpty(dir)) {
                            if (!context.mounted) return;
                            final proceed = await _askOverwriteConfirmation(
                              context,
                              dir,
                            );
                            if (!proceed) return;
                          }

                          recorder.startRecording(dir);
                          await _listRecordings(); // Refresh list
                        },
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Recordings",
                    style:
                        TextStyle(fontSize: 20.0, fontWeight: FontWeight.bold),
                  ),
                  if (Platform.isIOS)
                    IconButton(
                      icon: Icon(Icons.folder_open),
                      onPressed: () async {
                        Directory recordDir = await getIOSDirectory();
                        _openFolder(recordDir.path);
                      },
                    ),
                ],
              ),
            ),
            Divider(thickness: 2),
            Expanded(
              child: _recordings.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.warning, size: 48, color: Colors.grey),
                          SizedBox(height: 16),
                          Text(
                            "No recordings found",
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: EdgeInsets.zero,
                      itemCount: _recordings.length,
                      itemBuilder: (context, index) {
                        Directory folder = _recordings[index] as Directory;
                        String folderName = folder.path.split("/").last;
                        bool isCurrentRecording = isRecording && index == 0;
                        bool isExpanded =
                            _expandedFolders.contains(folder.path);
                        List<FileSystemEntity> files =
                            isExpanded ? _getFilesInFolder(folder) : [];

                        return Column(
                          children: [
                            ListTile(
                              leading: Icon(
                                isExpanded ? Icons.folder_open : Icons.folder,
                                color: Colors.grey,
                              ),
                              title: Text(
                                folderName,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 14),
                              ),
                              trailing: isCurrentRecording
                                  ? Padding(
                                      padding: EdgeInsets.all(
                                        16.0,
                                      ),
                                      child: SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      ),
                                    )
                                  : Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: Icon(
                                            Icons.share,
                                            color: isCurrentRecording
                                                ? Colors.grey
                                                    .withValues(alpha: 30)
                                                : Colors.blue,
                                          ),
                                          onPressed: isCurrentRecording
                                              ? null
                                              : () => _shareFolder(folder),
                                        ),
                                        IconButton(
                                          icon: Icon(
                                            Icons.delete,
                                            color: isCurrentRecording
                                                ? Colors.grey
                                                    .withValues(alpha: 30)
                                                : Colors.red,
                                          ),
                                          onPressed: isCurrentRecording
                                              ? null
                                              : () => _deleteRecording(folder),
                                        ),
                                      ],
                                    ),
                              onTap: () {
                                setState(() {
                                  if (isExpanded) {
                                    _expandedFolders.remove(folder.path);
                                  } else if (!isCurrentRecording) {
                                    _expandedFolders.add(folder.path);
                                  }
                                });
                              },
                            ),
                            // Show files when expanded
                            if (isExpanded)
                              ...files.map((file) {
                                String fileName = file.path.split("/").last;
                                String fileSize = _formatFileSize(file as File);

                                return ListTile(
                                  contentPadding:
                                      EdgeInsets.only(left: 72, right: 16),
                                  leading: Icon(
                                    fileName.endsWith('.csv')
                                        ? Icons.table_chart
                                        : Icons.insert_drive_file,
                                    size: 20,
                                  ),
                                  title: Text(
                                    fileName,
                                    style: TextStyle(fontSize: 14),
                                  ),
                                  subtitle: Text(
                                    fileSize,
                                    style: TextStyle(
                                        fontSize: 12, color: Colors.grey),
                                  ),
                                  trailing: IconButton(
                                    icon: Icon(Icons.share,
                                        color: Colors.blue, size: 20),
                                    onPressed: () => _shareFile(file as File),
                                  ),
                                  onTap: () async {
                                    final result = await OpenFile.open(
                                      file.path,
                                      type: 'text/comma-separated-values',
                                    );
                                    if (result.type != ResultType.done) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                          content: Text(
                                              'Could not open file: ${result.message}'),
                                        ),
                                      );
                                    }
                                  },
                                );
                              }),
                          ],
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}

/* ──────────────────────────────────────────────────────────── */
/*  Helpers                                                    */
/* ──────────────────────────────────────────────────────────── */

Future<String?> _pickDirectory() async {
  if (!Platform.isIOS && !kIsWeb) {
    final recordingName =
        'OpenWearable_Recording_${DateTime.now().toIso8601String()}';
    Directory? appDir = await getExternalStorageDirectory();
    if (appDir == null) return null;

    String dirPath = '${appDir.path}/$recordingName';
    Directory dir = Directory(dirPath);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dirPath;
  }

  if (Platform.isIOS) {
    final recordingName =
        'OpenWearable_Recording_${DateTime.now().toIso8601String()}';
    String dirPath = '${(await getIOSDirectory()).path}/$recordingName';
    Directory dir = Directory(dirPath);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dirPath;
  }

  return null;
}

Future<Directory> getIOSDirectory() async {
  Directory appDocDir = await getApplicationDocumentsDirectory();
  final dirPath = '${appDocDir.path}/Recordings';
  final dir = Directory(dirPath);

  if (!await dir.exists()) {
    await dir.create(recursive: true);
  }

  return dir;
}

Future<bool> _isDirectoryEmpty(String path) async {
  final dir = Directory(path);
  if (!await dir.exists()) return true;
  return await dir.list(followLinks: false).isEmpty;
}

Future<bool> _askOverwriteConfirmation(
  BuildContext context,
  String dirPath,
) async {
  return await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: PlatformText('Directory not empty'),
          content: PlatformText(
              '"$dirPath" already contains files or folders.\n\n'
              'New sensor files will be added; existing files with the same '
              'names will be overwritten. Continue anyway?'),
          actions: [
            PlatformTextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: PlatformText('Cancel'),
            ),
            PlatformTextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: PlatformText('Continue'),
            ),
          ],
        ),
      ) ??
      false;
}
