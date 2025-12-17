import 'dart:io';

import 'package:flutter/material.dart';

class RecordingFolderTile extends StatelessWidget {
  const RecordingFolderTile({
    super.key,
    required this.folder,
    required this.folderName,
    required this.isExpanded,
    required this.isCurrentRecording,
    required this.files,
    required this.onToggle,
    required this.onShareFolder,
    required this.onDeleteFolder,
    required this.formatFileSize,
    required this.onShareFile,
    required this.onOpenFile,
  });

  final Directory folder;
  final String folderName;
  final bool isExpanded;
  final bool isCurrentRecording;
  final List<File> files;
  final VoidCallback onToggle;
  final VoidCallback? onShareFolder;
  final VoidCallback? onDeleteFolder;
  final String Function(File) formatFileSize;
  final Future<void> Function(File) onShareFile;
  final Future<void> Function(File) onOpenFile;

  @override
  Widget build(BuildContext context) {
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
            style: const TextStyle(fontSize: 14),
          ),
          trailing: isCurrentRecording
              ? const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(
                        Icons.share,
                        color: onShareFolder == null
                            ? Colors.grey.withValues(alpha: 30)
                            : Colors.blue,
                      ),
                      onPressed: onShareFolder,
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.delete,
                        color: onDeleteFolder == null
                            ? Colors.grey.withValues(alpha: 30)
                            : Colors.red,
                      ),
                      onPressed: onDeleteFolder,
                    ),
                  ],
                ),
          onTap: onToggle,
        ),
        if (isExpanded)
          ...files.map((file) {
            final fileName = file.path.split('/').last;
            final fileSize = formatFileSize(file);
            return ListTile(
              contentPadding: const EdgeInsets.only(left: 72, right: 16),
              leading: Icon(
                fileName.endsWith('.csv')
                    ? Icons.table_chart
                    : Icons.insert_drive_file,
                size: 20,
              ),
              title: Text(fileName, style: const TextStyle(fontSize: 14)),
              subtitle: Text(
                fileSize,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              trailing: IconButton(
                icon: const Icon(Icons.share, color: Colors.blue, size: 20),
                onPressed: () => onShareFile(file),
              ),
              onTap: () => onOpenFile(file),
            );
          }),
      ],
    );
  }
}
