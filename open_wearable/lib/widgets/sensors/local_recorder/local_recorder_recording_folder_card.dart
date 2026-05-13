import 'package:flutter/material.dart';
import 'package:open_wearable/widgets/sensors/local_recorder/local_recorder_models.dart';
import 'package:open_wearable/widgets/sensors/sensor_page_spacing.dart';

class LocalRecorderRecordingFolderCard extends StatelessWidget {
  final LocalRecorderRecordingFolder folder;
  final bool isCurrentRecording;
  final bool isExpanded;
  final List<LocalRecorderRecordingFile> files;
  final String updatedLabel;
  final VoidCallback onToggleExpanded;
  final VoidCallback onShareFolder;
  final VoidCallback onDeleteFolder;
  final void Function(LocalRecorderRecordingFile file) onShareFile;
  final void Function(LocalRecorderRecordingFile file) onOpenFile;
  final String Function(int bytes) formatFileSize;
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

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
              folder.name,
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
                      if (!selectionMode)
                        SizedBox(
                          width: 24,
                          height: 24,
                          child: Center(
                            child: Icon(
                              isExpanded
                                  ? Icons.expand_less
                                  : Icons.expand_more,
                              size: 24,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      if (selectionMode && onSelectionToggle != null)
                        SizedBox(
                          width: 24,
                          height: 24,
                          child: IconButton(
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints.tightFor(
                              width: 24,
                              height: 24,
                            ),
                            iconSize: 24,
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
                fileSize: formatFileSize(file.sizeBytes),
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
  final LocalRecorderRecordingFile file;
  final String fileSize;
  final VoidCallback onShare;
  final VoidCallback onOpen;

  const _LocalRecorderRecordingFileTile({
    required this.file,
    required this.fileSize,
    required this.onShare,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final isCsv = file.name.toLowerCase().endsWith('.csv');

    return ListTile(
      contentPadding: const EdgeInsets.fromLTRB(58, 2, 10, 2),
      dense: true,
      leading: Icon(
        isCsv ? Icons.table_chart_outlined : Icons.insert_drive_file_outlined,
        size: 20,
      ),
      title: Text(
        file.name,
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
