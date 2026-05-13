import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:open_wearable/widgets/sensors/local_recorder/local_recorder_file_actions.dart';
import 'package:open_wearable/widgets/sensors/local_recorder/local_recorder_models.dart';
import 'package:open_wearable/widgets/sensors/local_recorder/local_recorder_recording_folder_card.dart';
import 'package:open_wearable/widgets/sensors/local_recorder/local_recorder_storage.dart';
import 'package:open_wearable/widgets/sensors/sensor_page_spacing.dart';

class LocalRecorderAllRecordingsPage extends StatefulWidget {
  final bool isRecording;

  const LocalRecorderAllRecordingsPage({
    super.key,
    required this.isRecording,
  });

  @override
  State<LocalRecorderAllRecordingsPage> createState() =>
      _LocalRecorderAllRecordingsPageState();
}

class _LocalRecorderAllRecordingsPageState
    extends State<LocalRecorderAllRecordingsPage> {
  final Set<String> _expandedFolders = {};
  final Set<String> _selectedFolderPaths = {};
  List<LocalRecorderRecordingFolder> _recordings =
      <LocalRecorderRecordingFolder>[];
  bool _isLoading = true;
  bool _isBusy = false;
  bool _isSelectionMode = false;

  bool get _selectionMode => _isSelectionMode;

  @override
  void initState() {
    super.initState();
    _loadRecordings();
  }

  Future<void> _loadRecordings() async {
    final recordings = await listRecordingFolders();
    if (!mounted) return;
    setState(() {
      _recordings = recordings;
      _expandedFolders.removeWhere(
        (path) => !_recordings.any((entry) => entry.path == path),
      );
      _selectedFolderPaths.removeWhere(
        (path) => !_recordings.any((entry) => entry.path == path),
      );
      _isLoading = false;
    });
  }

  Future<void> _shareFolder(LocalRecorderRecordingFolder folder) async {
    try {
      await localRecorderShareFolder(folder);
    } catch (e) {
      await _showErrorDialog('Failed to share folder: $e');
    }
  }

  Future<void> _shareFile(LocalRecorderRecordingFile file) async {
    try {
      await localRecorderShareFile(file);
    } catch (e) {
      await _showErrorDialog('Failed to share file: $e');
    }
  }

  Future<void> _openFile(LocalRecorderRecordingFile file) async {
    await localRecorderOpenRecordingFile(file);
  }

  Future<void> _shareSelectedFolders() async {
    if (_isBusy || _selectedFolderPaths.isEmpty) return;
    setState(() => _isBusy = true);
    try {
      for (final path in _selectedFolderPaths) {
        final folder = _recordings.firstWhere((entry) => entry.path == path);
        await localRecorderShareFolder(folder);
      }
    } catch (e) {
      await _showErrorDialog('Failed to share selected recordings: $e');
    } finally {
      if (mounted) {
        setState(() => _isBusy = false);
      }
    }
  }

  Future<void> _deleteSelectedFolders() async {
    if (_isBusy || _selectedFolderPaths.isEmpty) return;

    final count = _selectedFolderPaths.length;
    final shouldDelete = await showPlatformDialog<bool>(
          context: context,
          builder: (_) => PlatformAlertDialog(
            title: PlatformText('Delete recordings?'),
            content: PlatformText(
              'This will permanently delete $count recording folder${count == 1 ? '' : 's'}.',
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

    setState(() => _isBusy = true);
    try {
      for (final path in _selectedFolderPaths.toList()) {
        await deleteRecordingFolder(path);
      }
      _selectedFolderPaths.clear();
      _isSelectionMode = false;
      await _loadRecordings();
    } catch (e) {
      await _showErrorDialog('Failed to delete selected recordings: $e');
    } finally {
      if (mounted) {
        setState(() => _isBusy = false);
      }
    }
  }

  Future<void> _deleteSingleFolder(LocalRecorderRecordingFolder folder) async {
    final name = folder.name;
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
      await deleteRecordingFolder(folder.path);
      if (!mounted) return;
      setState(() {
        _expandedFolders.remove(folder.path);
        _selectedFolderPaths.remove(folder.path);
        _recordings.removeWhere((entry) => entry.path == folder.path);
      });
    } catch (e) {
      await _showErrorDialog('Failed to delete recording: $e');
    }
  }

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

  @override
  Widget build(BuildContext context) {
    return PlatformScaffold(
      appBar: PlatformAppBar(
        title: Text(
          _selectionMode && _selectedFolderPaths.isNotEmpty
              ? '${_selectedFolderPaths.length} selected'
              : 'All recordings',
        ),
        trailingActions: [
          if (_selectionMode && _selectedFolderPaths.isNotEmpty)
            PlatformIconButton(
              icon: const Icon(Icons.ios_share),
              onPressed: _isBusy ? null : _shareSelectedFolders,
            ),
          if (_selectionMode && _selectedFolderPaths.isNotEmpty)
            PlatformIconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: _isBusy ? null : _deleteSelectedFolders,
            ),
          if (_selectionMode)
            PlatformIconButton(
              icon: const Icon(Icons.close),
              onPressed: _isBusy
                  ? null
                  : () => setState(() {
                        _selectedFolderPaths.clear();
                        _isSelectionMode = false;
                      }),
            ),
          if (!_selectionMode)
            PlatformIconButton(
              icon: const Icon(Icons.checklist),
              onPressed: _isBusy
                  ? null
                  : () => setState(() {
                        _isSelectionMode = true;
                      }),
            ),
          PlatformIconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isBusy ? null : _loadRecordings,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadRecordings,
              child: ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: SensorPageSpacing.pageListPadding,
                itemCount: _recordings.length,
                itemBuilder: (context, index) {
                  final folder = _recordings[index];
                  final isCurrent = widget.isRecording && index == 0;
                  final isExpanded = _expandedFolders.contains(folder.path);
                  final files = isExpanded
                      ? folder.files
                      : <LocalRecorderRecordingFile>[];
                  final isSelected = _selectedFolderPaths.contains(folder.path);

                  return LocalRecorderRecordingFolderCard(
                    folder: folder,
                    isCurrentRecording: isCurrent,
                    isExpanded: isExpanded,
                    files: files,
                    updatedLabel:
                        'Updated ${localRecorderFormatDateTime(folder.updatedAt)}',
                    selectionMode: _selectionMode,
                    isSelected: isSelected,
                    onSelectionToggle: isCurrent
                        ? null
                        : () {
                            setState(() {
                              if (isSelected) {
                                _selectedFolderPaths.remove(folder.path);
                              } else {
                                _selectedFolderPaths.add(folder.path);
                              }
                              if (_selectedFolderPaths.isEmpty) {
                                _isSelectionMode = false;
                              }
                            });
                          },
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
                    onDeleteFolder: () => _deleteSingleFolder(folder),
                    onShareFile: _shareFile,
                    onOpenFile: _openFile,
                    formatFileSize: localRecorderFormatFileSize,
                  );
                },
              ),
            ),
    );
  }
}
