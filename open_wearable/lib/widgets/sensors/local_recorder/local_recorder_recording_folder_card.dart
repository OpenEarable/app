import 'dart:io';

import 'package:flutter/material.dart';
import 'package:open_wearable/widgets/sensors/sensor_page_spacing.dart';

class LocalRecorderRecordingFolderCard extends StatelessWidget {
  final Directory folder;
  final bool isCurrentRecording;
  final bool isExpanded;
  final List<File> files;
  final String updatedLabel;
  final VoidCallback onToggleExpanded;
  final VoidCallback onShareFolder;
  final VoidCallback onDeleteFolder;
  final void Function(File file) onShareFile;
  final void Function(File file) onOpenFile;
  final String Function(File file) formatFileSize;
  final bool selectionMode;
  final bool isSelected;
  final VoidCallback? onSelectionToggle;

  const LocalRecorderRecordingFolderCard({
    super.key,
    required this.folder,
    required this.isCurrentRecording,
    required this.isExpanded,
    required this.files,
    required this.updatedLabel,
    required this.onToggleExpanded,
    required this.onShareFolder,
    required this.onDeleteFolder,
    required this.onShareFile,
    required this.onOpenFile,
    required this.formatFileSize,
    this.selectionMode = false,
    this.isSelected = false,
    this.onSelectionToggle,
  });

  String _basename(String path) => path.split(RegExp(r'[\\/]+')).last;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final folderName = _basename(folder.path);

    return Card(
      margin: const EdgeInsets.only(bottom: SensorPageSpacing.sectionGap),
      child: Column(
        children: [
          ListTile(
            leading: Icon(
              isExpanded ? Icons.folder_open : Icons.folder_outlined,
              color: isCurrentRecording
                  ? colorScheme.error
                  : colorScheme.onSurfaceVariant,
            ),
            title: Text(
              folderName,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              isCurrentRecording ? 'Active recording' : updatedLabel,
            ),
            trailing: isCurrentRecording
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: colorScheme.error,
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Share folder',
                        onPressed: onShareFolder,
                        icon: Icon(Icons.ios_share, color: colorScheme.primary),
                      ),
                      IconButton(
                        tooltip: 'Delete folder',
                        onPressed: onDeleteFolder,
                        icon: Icon(
                          Icons.delete_outline,
                          color: colorScheme.error,
                        ),
                      ),
                      Icon(
                        isExpanded ? Icons.expand_less : Icons.expand_more,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      if (selectionMode && onSelectionToggle != null)
                        IconButton(
                          tooltip: isSelected ? 'Deselect' : 'Select',
                          onPressed: onSelectionToggle,
                          icon: Icon(
                            isSelected
                                ? Icons.check_circle
                                : Icons.radio_button_unchecked,
                            color: isSelected
                                ? colorScheme.primary
                                : colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
            onTap: isCurrentRecording
                ? null
                : (selectionMode && onSelectionToggle != null
                    ? onSelectionToggle
                    : onToggleExpanded),
          ),
          if (isExpanded) const Divider(height: 1),
          if (isExpanded && files.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(58, 10, 10, 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'No files in this folder',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          if (isExpanded)
            ...files.map(
              (file) => _LocalRecorderRecordingFileTile(
                file: file,
                fileSize: formatFileSize(file),
                onShare: () => onShareFile(file),
                onOpen: () => onOpenFile(file),
              ),
            ),
        ],
      ),
    );
  }
}

class _LocalRecorderRecordingFileTile extends StatelessWidget {
  final File file;
  final String fileSize;
  final VoidCallback onShare;
  final VoidCallback onOpen;

  const _LocalRecorderRecordingFileTile({
    required this.file,
    required this.fileSize,
    required this.onShare,
    required this.onOpen,
  });

  String _basename(String path) => path.split(RegExp(r'[\\/]+')).last;

  @override
  Widget build(BuildContext context) {
    final fileName = _basename(file.path);
    final isCsv = fileName.toLowerCase().endsWith('.csv');

    return ListTile(
      contentPadding: const EdgeInsets.fromLTRB(58, 2, 10, 2),
      dense: true,
      leading: Icon(
        isCsv ? Icons.table_chart_outlined : Icons.insert_drive_file_outlined,
        size: 20,
      ),
      title: Text(
        fileName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.bodyMedium,
      ),
      subtitle: Text(fileSize),
      trailing: IconButton(
        tooltip: 'Share file',
        icon: const Icon(Icons.ios_share, size: 20),
        onPressed: onShare,
      ),
      onTap: onOpen,
    );
  }
}
