import 'dart:io';

import 'package:flutter/material.dart';

import 'empty_recordings_state.dart';
import 'recording_folder_tile.dart';

class RecordingsSection extends StatelessWidget {
  const RecordingsSection({
    super.key,
    required this.recordings,
    required this.isRecording,
    required this.expandedFolders,
    required this.onToggleFolder,
    required this.onShareFolder,
    required this.onDeleteFolder,
    required this.onShareFile,
    required this.onOpenFile,
    required this.onOpenRecordingsFolderIOS,
    required this.getFilesInFolder,
    required this.formatFileSize,
  });

  final List<FileSystemEntity> recordings;
  final bool isRecording;
  final Set<String> expandedFolders;
  final void Function(String folderPath, bool isExpanded, bool isCurrentRecording) onToggleFolder;
  final Future<void> Function(Directory folder) onShareFolder;
  final Future<void> Function(Directory folder) onDeleteFolder;
  final Future<void> Function(File file) onShareFile;
  final Future<void> Function(File file) onOpenFile;
  final Future<void> Function()? onOpenRecordingsFolderIOS;
  final List<File> Function(Directory folder) getFilesInFolder;
  final String Function(File file) formatFileSize;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Recordings',
                style: TextStyle(fontSize: 20.0, fontWeight: FontWeight.bold),
              ),
              if (onOpenRecordingsFolderIOS != null)
                IconButton(
                  icon: const Icon(Icons.folder_open),
                  onPressed: onOpenRecordingsFolderIOS,
                ),
            ],
          ),
        ),
        const Divider(thickness: 2),
        Expanded(
          child: recordings.isEmpty
              ? const EmptyRecordingsState()
              : ListView.builder(
                  padding: EdgeInsets.zero,
                  itemCount: recordings.length,
                  itemBuilder: (context, index) {
                    final folder = recordings[index] as Directory;
                    final folderName = folder.path.split('/').last;
                    final isCurrentRecording = isRecording && index == 0;
                    final isExpanded = expandedFolders.contains(folder.path);
                    final files = isExpanded ? getFilesInFolder(folder) : <File>[];

                    return RecordingFolderTile(
                      folder: folder,
                      folderName: folderName,
                      isExpanded: isExpanded,
                      isCurrentRecording: isCurrentRecording,
                      files: files,
                      onToggle: () => onToggleFolder(folder.path, isExpanded, isCurrentRecording),
                      onShareFolder: isCurrentRecording ? null : () => onShareFolder(folder),
                      onDeleteFolder: isCurrentRecording ? null : () => onDeleteFolder(folder),
                      formatFileSize: formatFileSize,
                      onShareFile: onShareFile,
                      onOpenFile: onOpenFile,
                    );
                  },
                ),
        ),
      ],
    );
  }
}
