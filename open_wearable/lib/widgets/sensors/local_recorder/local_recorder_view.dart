import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widget_previews.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:logger/logger.dart';
import 'package:provider/provider.dart';
import 'package:open_file/open_file.dart';
import 'package:open_wearable/view_models/sensor_recorder_provider.dart';

import '../../../models/local_recorder_controller.dart';
import 'record_header_card.dart';
import 'recordings_section.dart';

final Logger _uiLogger = Logger();

class LocalRecorderView extends StatefulWidget {
  const LocalRecorderView({super.key});

  @override
  State<LocalRecorderView> createState() => _LocalRecorderViewState();
}

class _LocalRecorderViewState extends State<LocalRecorderView> {
  static const platform = MethodChannel('edu.teco.open_folder');
  List<FileSystemEntity> _recordings = [];
  final Set<String> _expandedFolders = {};
  late final LocalRecorderController _controller;

  @override
  void initState() {
    super.initState();
    _controller = LocalRecorderController(
      platformChannel: platform,
      logger: _uiLogger,
    );
    _refreshRecordings();
  }

  /// Helper to show cross-platform error dialogs instead of SnackBars
  Future<void> _showErrorDialog(String message) async {
    if (!mounted) return;
    await showPlatformDialog(
      context: context,
      builder: (_) => PlatformAlertDialog(
        title: PlatformText('Error'),
        content: PlatformText(message),
        actions: [
          PlatformDialogAction(
            child: PlatformText('OK'),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Future<void> _refreshRecordings() async {
    try {
      final recordings = await _controller.listRecordings();
      if (!mounted) return;
      setState(() {
        _recordings = recordings;
      });
    } catch (e) {
      _uiLogger.e('Error listing recordings: $e');
      await _showErrorDialog('Failed to list recordings: $e');
    }
  }

  Future<void> _confirmAndDelete(FileSystemEntity entity) async {
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

    try {
      await _controller.deleteEntity(entity);
      await _refreshRecordings();
    } catch (e) {
      _uiLogger.e('Error deleting recording: $e');
      await _showErrorDialog('Failed to delete recording: $e');
    }
  }

  String _formatFileSize(File file) {
    int bytes = file.lengthSync();
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SensorRecorderProvider>(
      builder: (context, recorder, _) {
        final isRecording = recorder.isRecording;

        return SafeArea(
          top: false,
          child: Column(
            children: [
              RecorderHeaderCard(
                onRecordingStarted: _refreshRecordings,
                onRecordingStopped: _refreshRecordings,
              ),
              Expanded(
                child: RecordingsSection(
                  recordings: _recordings,
                  isRecording: isRecording,
                  expandedFolders: _expandedFolders,
                  onToggleFolder: (folderPath, isExpanded, isCurrentRecording) {
                    setState(() {
                      if (isExpanded) {
                        _expandedFolders.remove(folderPath);
                      } else if (!isCurrentRecording) {
                        _expandedFolders.add(folderPath);
                      }
                    });
                  },
                  onShareFolder: (folder) => _controller.shareFolder(folder, onError: _showErrorDialog),
                  onDeleteFolder: _confirmAndDelete,
                  onShareFile: (file) => _controller.shareFile(file, onError: _showErrorDialog),
                  onOpenFile: (file) async {
                    final result = await OpenFile.open(
                      file.path,
                      type: 'text/comma-separated-values',
                    );
                    if (result.type != ResultType.done) {
                      await _showErrorDialog('Could not open file: ${result.message}');
                    }
                  },
                  onOpenRecordingsFolderIOS: Platform.isIOS
                      ? () async {
                          final recordDir = await getIOSDirectory();
                          await _controller.openFolder(recordDir.path);
                        }
                      : null,
                  getFilesInFolder: _controller.getFilesInFolder,
                  formatFileSize: _formatFileSize,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

@Preview(name: 'LocalRecorderView')
Widget previewLocalRecorderView() {
  return ChangeNotifierProvider(
    create: (_) => SensorRecorderProvider(),
    child: const MaterialApp(
      home: Scaffold(
        body: LocalRecorderView(),
      ),
    ),
  );
}
