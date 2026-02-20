import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:open_wearable/widgets/sensors/local_recorder/local_recorder_recording_folder_card.dart';
import 'package:open_wearable/widgets/sensors/sensor_page_spacing.dart';

class LocalRecorderAllRecordingsPage extends StatefulWidget {
  final List<Directory> recordings;
  final bool isRecording;
  final String Function(DateTime) formatDateTime;
  final List<File> Function(Directory folder) getFilesInFolder;
  final String Function(File file) formatFileSize;
  final Future<void> Function(File file) onShareFile;
  final Future<void> Function(File file) onOpenFile;
  final Future<void> Function(Directory folder) onShareFolder;
  final Future<bool> Function(Directory folder) onDeleteFolder;

  const LocalRecorderAllRecordingsPage({
    super.key,
    required this.recordings,
    required this.isRecording,
    required this.formatDateTime,
    required this.getFilesInFolder,
    required this.formatFileSize,
    required this.onShareFile,
    required this.onOpenFile,
    required this.onShareFolder,
    required this.onDeleteFolder,
  });

  @override
  State<LocalRecorderAllRecordingsPage> createState() =>
      _LocalRecorderAllRecordingsPageState();
}

class _LocalRecorderAllRecordingsPageState
    extends State<LocalRecorderAllRecordingsPage> {
  late List<Directory> _recordings;
  final Set<String> _expandedFolders = {};

  @override
  void initState() {
    super.initState();
    _recordings = List<Directory>.from(widget.recordings);
  }

  @override
  Widget build(BuildContext context) {
    return PlatformScaffold(
      appBar: PlatformAppBar(
        title: const Text('All recordings'),
      ),
      body: ListView.builder(
        padding: SensorPageSpacing.pageListPadding,
        itemCount: _recordings.length,
        itemBuilder: (context, index) {
          final folder = _recordings[index];
          final modified = folder.statSync().changed;
          final isCurrent = widget.isRecording && index == 0;
          final isExpanded = _expandedFolders.contains(folder.path);
          final files = isExpanded ? widget.getFilesInFolder(folder) : <File>[];
          return LocalRecorderRecordingFolderCard(
            folder: folder,
            isCurrentRecording: isCurrent,
            isExpanded: isExpanded,
            files: files,
            updatedLabel: 'Updated ${widget.formatDateTime(modified)}',
            onToggleExpanded: () {
              setState(() {
                if (isExpanded) {
                  _expandedFolders.remove(folder.path);
                } else {
                  _expandedFolders.add(folder.path);
                }
              });
            },
            onShareFolder: () => widget.onShareFolder(folder),
            onDeleteFolder: () async {
              final deleted = await widget.onDeleteFolder(folder);
              if (!deleted || !mounted) return;
              setState(() {
                _expandedFolders.remove(folder.path);
                _recordings.removeWhere((entry) => entry.path == folder.path);
              });
            },
            onShareFile: (file) => widget.onShareFile(file),
            onOpenFile: (file) => widget.onOpenFile(file),
            formatFileSize: widget.formatFileSize,
          );
        },
      ),
    );
  }
}
