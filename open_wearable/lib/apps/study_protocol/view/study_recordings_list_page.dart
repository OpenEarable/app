import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';

import 'package:open_wearable/apps/study_protocol/model/study_devices.dart';
import 'package:open_wearable/apps/study_protocol/model/study_protocol_storage.dart';
import 'package:open_wearable/apps/study_protocol/view/study_baseline_page.dart';
import 'package:open_wearable/widgets/sensors/local_recorder/local_recorder_file_actions.dart';
import 'package:open_wearable/widgets/sensors/local_recorder/local_recorder_models.dart';
import 'package:open_wearable/widgets/sensors/local_recorder/local_recorder_recording_folder_card.dart';
import 'package:open_wearable/widgets/sensors/sensor_page_spacing.dart';

/// Recordings list for the study protocol app.
///
/// Shows existing study recordings with share/delete actions (mirroring the
/// Local Recorder) and a prominent action to start a new guided recording.
class StudyRecordingsList extends StatefulWidget {
  /// The resolved device set used to start a new recording.
  final StudyDeviceSet deviceSet;

  const StudyRecordingsList({
    super.key,
    required this.deviceSet,
  });

  @override
  State<StudyRecordingsList> createState() => _StudyRecordingsListState();
}

class _StudyRecordingsListState extends State<StudyRecordingsList> {
  final Set<String> _expandedFolders = {};
  List<LocalRecorderRecordingFolder> _recordings =
      <LocalRecorderRecordingFolder>[];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRecordings();
  }

  Future<void> _loadRecordings() async {
    final recordings = await listStudyRecordingFolders();
    if (!mounted) {
      return;
    }
    setState(() {
      _recordings = recordings;
      _expandedFolders.removeWhere(
        (path) => !_recordings.any((entry) => entry.path == path),
      );
      _isLoading = false;
    });
  }

  Future<void> _startNewRecording() async {
    final probandId = await _promptProbandId();
    if (probandId == null || !mounted) {
      return;
    }

    await Navigator.of(context).push(
      platformPageRoute(
        context: context,
        builder: (_) => StudyBaselinePage(
          probandId: probandId,
          deviceSet: widget.deviceSet,
        ),
      ),
    );

    if (mounted) {
      await _loadRecordings();
    }
  }

  Future<String?> _promptProbandId() async {
    final controller = TextEditingController();
    final result = await showPlatformDialog<String>(
      context: context,
      builder: (dialogContext) {
        return PlatformAlertDialog(
          title: PlatformText('New recording'),
          content: Padding(
            padding: const EdgeInsets.only(top: 12),
            child: PlatformTextField(
              controller: controller,
              autofocus: true,
              hintText: 'Proband ID',
              textCapitalization: TextCapitalization.characters,
            ),
          ),
          actions: [
            PlatformDialogAction(
              child: PlatformText('Cancel'),
              onPressed: () => Navigator.pop(dialogContext),
            ),
            PlatformDialogAction(
              child: PlatformText('Continue'),
              onPressed: () {
                final value = controller.text.trim();
                if (value.isEmpty) {
                  return;
                }
                Navigator.pop(dialogContext, value);
              },
            ),
          ],
        );
      },
    );
    controller.dispose();
    return result;
  }

  Future<void> _shareFolder(LocalRecorderRecordingFolder folder) async {
    try {
      await localRecorderShareFolder(folder);
    } catch (e) {
      await _showError('Failed to share recording: $e');
    }
  }

  Future<void> _shareFile(LocalRecorderRecordingFile file) async {
    try {
      await localRecorderShareFile(file);
    } catch (e) {
      await _showError('Failed to share file: $e');
    }
  }

  Future<void> _openFile(LocalRecorderRecordingFile file) async {
    try {
      await localRecorderOpenRecordingFile(file);
    } catch (e) {
      await _showError('Failed to open file: $e');
    }
  }

  Future<void> _deleteFolder(LocalRecorderRecordingFolder folder) async {
    final shouldDelete = await showPlatformDialog<bool>(
          context: context,
          builder: (dialogContext) => PlatformAlertDialog(
            title: PlatformText('Delete recording?'),
            content: PlatformText(
              'This will permanently delete "${folder.name}" and all '
              'contained files.',
            ),
            actions: [
              PlatformDialogAction(
                child: PlatformText('Cancel'),
                onPressed: () => Navigator.pop(dialogContext, false),
              ),
              PlatformDialogAction(
                cupertino: (_, __) => CupertinoDialogActionData(
                  isDestructiveAction: true,
                ),
                child: PlatformText('Delete'),
                onPressed: () => Navigator.pop(dialogContext, true),
              ),
            ],
          ),
        ) ??
        false;

    if (!shouldDelete) {
      return;
    }
    try {
      await deleteStudyRecordingFolder(folder.path);
      if (!mounted) {
        return;
      }
      setState(() {
        _expandedFolders.remove(folder.path);
        _recordings.removeWhere((entry) => entry.path == folder.path);
      });
    } catch (e) {
      await _showError('Failed to delete recording: $e');
    }
  }

  Future<void> _showError(String message) async {
    if (!mounted) {
      return;
    }
    await showPlatformDialog(
      context: context,
      builder: (dialogContext) => PlatformAlertDialog(
        title: PlatformText('Error'),
        content: PlatformText(message),
        actions: [
          PlatformDialogAction(
            child: PlatformText('OK'),
            onPressed: () => Navigator.pop(dialogContext),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: _loadRecordings,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: SensorPageSpacing.pagePaddingWithBottomInset(context),
        children: [
          _StartRecordingCard(onStart: _startNewRecording),
          const SizedBox(height: SensorPageSpacing.sectionGap),
          Padding(
            padding: const EdgeInsets.only(left: 2, bottom: 8),
            child: Text(
              'Recordings',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
          if (_recordings.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text('No recordings yet'),
              ),
            )
          else
            ..._recordings.map((folder) {
              final isExpanded = _expandedFolders.contains(folder.path);
              final files =
                  isExpanded ? folder.files : <LocalRecorderRecordingFile>[];
              return LocalRecorderRecordingFolderCard(
                folder: folder,
                isCurrentRecording: false,
                isExpanded: isExpanded,
                files: files,
                updatedLabel:
                    'Updated ${localRecorderFormatDateTime(folder.updatedAt)}',
                onToggleExpanded: () {
                  setState(() {
                    if (isExpanded) {
                      _expandedFolders.remove(folder.path);
                    } else {
                      _expandedFolders.add(folder.path);
                    }
                  });
                },
                onShareFolder: () => _shareFolder(folder),
                onDeleteFolder: () => _deleteFolder(folder),
                onShareFile: _shareFile,
                onOpenFile: _openFile,
                formatFileSize: localRecorderFormatFileSize,
              );
            }),
        ],
      ),
    );
  }
}

class _StartRecordingCard extends StatelessWidget {
  final VoidCallback onStart;

  const _StartRecordingCard({required this.onStart});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onStart,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                height: 46,
                width: 46,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.fiber_manual_record,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Start new recording',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Guided 5-minute baseline',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}
