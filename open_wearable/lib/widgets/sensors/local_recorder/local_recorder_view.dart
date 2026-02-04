import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:logger/logger.dart';
import 'package:open_wearable/widgets/sensors/local_recorder/local_recorder_dialogs.dart';
import 'package:open_wearable/widgets/sensors/local_recorder/recording_controls.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:open_file/open_file.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_archive/flutter_archive.dart';
import 'package:open_wearable/view_models/sensor_recorder_provider.dart';
import 'local_recorder_files.dart';

Logger _logger = Logger();

class LocalRecorderView extends StatefulWidget {
  const LocalRecorderView({super.key});

  @override
  State<LocalRecorderView> createState() => _LocalRecorderViewState();
}

class _LocalRecorderViewState extends State<LocalRecorderView> {
  static const MethodChannel platform = MethodChannel('edu.teco.open_folder');
  List<FileSystemEntity> _recordings = [];
  final Set<String> _expandedFolders = {}; // Track which folders are expanded

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
      // Optional: Show error dialog here too if needed
    }
  }

  Future<void> _listRecordings() async {
    Directory recordingsDir;

    if (Platform.isAndroid) {
      Directory? dir = await getExternalStorageDirectory();
      if (dir == null) return;
      recordingsDir = dir;
    } else if (Platform.isIOS) {
      recordingsDir = await Files.getIOSDirectory();
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
        .where(
          (entity) =>
              entity is Directory &&
              entity.path.contains('OpenWearable_Recording'),
        )
        .toList();

    // Sort by modification time (newest first)
    _recordings.sort((a, b) {
      return b.statSync().changed.compareTo(a.statSync().changed);
    });

    setState(() {});
  }

  List<File> _getFilesInFolder(Directory folder) {
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

  Future<void> _confirmAndDeleteRecording(FileSystemEntity entity) async {
    if (!mounted) return;
    final name = entity.path.split('/').last;
    final shouldDelete = await showPlatformDialog<bool>(
          context: context,
          builder: (_) => PlatformAlertDialog(
            title: PlatformText('Delete recording?'),
            content: PlatformText(
              'This will permanently delete "$name" and all contained files.',
            ),
            actions: [
              PlatformDialogAction(
                child: PlatformText('Cancel'),
                onPressed: () => Navigator.pop(context, false),
              ),
              PlatformDialogAction(
                cupertino: (_, __) => CupertinoDialogActionData(
                  isDestructiveAction: true,
                ),
                child: PlatformText('Delete'),
                onPressed: () => Navigator.pop(context, true),
              ),
            ],
          ),
        ) ??
        false;

    if (!shouldDelete) return;

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
        if (!mounted) return;
        LocalRecorderDialogs.showErrorDialog(
          context,
          'Failed to delete recording: $e',
        );
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
      if (!mounted) return;
      await LocalRecorderDialogs.showErrorDialog(
        context,
        'Failed to share file: $e',
      );
    }
  }

  Future<void> _shareFolder(Directory folder) async {
    try {
      // Replaced SnackBar with Logger to avoid UI issues during async work
      _logger.i('Creating zip file for ${folder.path}...');

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
      if (!mounted) return;
      await LocalRecorderDialogs.showErrorDialog(
        context,
        'Failed to share folder: $e',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SensorRecorderProvider>(
      builder: (context, recorder, _) {
        final isRecording = recorder.isRecording;
        final canStartRecording = recorder.hasSensorsConnected && !isRecording;

        return SafeArea(
          top: false,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(10),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      PlatformText(
                        'Local Recorder',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 6),
                      PlatformText(
                        "Only records sensor data streamed over Bluetooth.",
                      ),
                      const SizedBox(height: 12),
                      RecordingControls(
                        canStartRecording: canStartRecording,
                        isRecording: isRecording,
                        recorder: recorder,
                        updateRecordingsList: _listRecordings,
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "Recordings",
                            style: TextStyle(
                              fontSize: 20.0,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (Platform.isIOS)
                            IconButton(
                              icon: Icon(Icons.folder_open),
                              onPressed: () async {
                                Directory recordDir =
                                    await Files.getIOSDirectory();
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
                                  Icon(
                                    Icons.warning,
                                    size: 48,
                                    color: Colors.grey,
                                  ),
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
                                Directory folder =
                                    _recordings[index] as Directory;
                                String folderName = folder.path.split("/").last;
                                bool isCurrentRecording =
                                    isRecording && index == 0;
                                bool isExpanded =
                                    _expandedFolders.contains(folder.path);
                                List<File> files =
                                    isExpanded ? _getFilesInFolder(folder) : [];

                                return Column(
                                  children: [
                                    ListTile(
                                      leading: Icon(
                                        isExpanded
                                            ? Icons.folder_open
                                            : Icons.folder,
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
                                                child:
                                                    CircularProgressIndicator(
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
                                                            .withValues(
                                                            alpha: 30,
                                                          )
                                                        : Colors.blue,
                                                  ),
                                                  onPressed: isCurrentRecording
                                                      ? null
                                                      : () => _shareFolder(
                                                            folder,
                                                          ),
                                                ),
                                                IconButton(
                                                  icon: Icon(
                                                    Icons.delete,
                                                    color: isCurrentRecording
                                                        ? Colors.grey
                                                            .withValues(
                                                            alpha: 30,
                                                          )
                                                        : Colors.red,
                                                  ),
                                                  onPressed: isCurrentRecording
                                                      ? null
                                                      : () =>
                                                          _confirmAndDeleteRecording(
                                                            folder,
                                                          ),
                                                ),
                                              ],
                                            ),
                                      onTap: () {
                                        setState(() {
                                          if (isExpanded) {
                                            _expandedFolders
                                                .remove(folder.path);
                                          } else if (!isCurrentRecording) {
                                            _expandedFolders.add(folder.path);
                                          }
                                        });
                                      },
                                    ),
                                    // Show files when expanded
                                    if (isExpanded)
                                      ...files.map((file) {
                                        String fileName =
                                            file.path.split("/").last;
                                        String fileSize = _formatFileSize(file);

                                        return ListTile(
                                          contentPadding: EdgeInsets.only(
                                            left: 72,
                                            right: 16,
                                          ),
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
                                              fontSize: 12,
                                              color: Colors.grey,
                                            ),
                                          ),
                                          trailing: IconButton(
                                            icon: Icon(
                                              Icons.share,
                                              color: Colors.blue,
                                              size: 20,
                                            ),
                                            onPressed: () => _shareFile(file),
                                          ),
                                          onTap: () async {
                                            String? mimeType;

                                            if (fileName.endsWith('.csv')) {
                                              mimeType =
                                                  'text/comma-separated-values';
                                            } else if (fileName
                                                .endsWith('.m4a')) {
                                              mimeType = 'audio/mp4';
                                            } else if (fileName
                                                .endsWith('.mp3')) {
                                              mimeType = 'audio/mpeg';
                                            } else if (fileName
                                                .endsWith('.wav')) {
                                              mimeType = 'audio/wav';
                                            }

                                            final result = await OpenFile.open(
                                              file.path,
                                              type: mimeType,
                                            );

                                            if (!mounted) return;
                                            if (result.type !=
                                                ResultType.done) {
                                              await LocalRecorderDialogs
                                                  .showErrorDialog(
                                                this.context,
                                                'Could not open file: ${result.message}',
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
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
