import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:open_wearable/apps/study_protocol/model/study_devices.dart';
import 'package:open_wearable/apps/study_protocol/model/study_file_actions.dart';
import 'package:open_wearable/apps/study_protocol/model/study_protocol_storage.dart';
import 'package:open_wearable/apps/study_protocol/model/study_session.dart';
import 'package:open_wearable/apps/study_protocol/view/study_flow.dart';
import 'package:open_wearable/view_models/wearables_provider.dart';
import 'package:open_wearable/widgets/sensors/local_recorder/local_recorder_models.dart';
import 'package:open_wearable/widgets/sensors/local_recorder/local_recorder_recording_folder_card.dart';
import 'package:open_wearable/widgets/sensors/sensor_page_spacing.dart';

/// Recordings list for the study protocol app.
///
/// Shows existing study recordings with share/delete actions (mirroring the
/// Local Recorder) and a prominent action to start a new guided recording.
///
/// The list is always available; starting a new recording resolves the required
/// device set (OpenEarable pair + RespiBAN) on demand and only proceeds when
/// both are connected.
class StudyRecordingsList extends StatefulWidget {
  const StudyRecordingsList({super.key});

  @override
  State<StudyRecordingsList> createState() => _StudyRecordingsListState();
}

class _StudyRecordingsListState extends State<StudyRecordingsList> {
  static const Duration _postProtocolRefreshDelay = Duration(
    milliseconds: 750,
  );

  final Set<String> _expandedFolders = {};
  final TextEditingController _probandIdController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  List<LocalRecorderRecordingFolder> _recordings =
      <LocalRecorderRecordingFolder>[];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRecordings();
  }

  @override
  void dispose() {
    _probandIdController.dispose();
    _ageController.dispose();
    super.dispose();
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
    // Resolve the required device set on demand: the app is browsable without
    // devices, but a new recording needs the OpenEarable pair and RespiBAN.
    final wearables = context.read<WearablesProvider>().wearables;
    final deviceSet = await resolveStudyDeviceSet(wearables);
    if (!mounted) {
      return;
    }
    if (deviceSet == null) {
      await _showDevicesRequired();
      return;
    }

    final session = await _promptSession();
    if (session == null || !mounted) {
      return;
    }

    // Dismiss the dialog keyboard before navigating so the next page does not
    // build against a shrinking viewport inset.
    FocusManager.instance.primaryFocus?.unfocus();

    // Create the session directory once; every phase records into it.
    String directory;
    try {
      directory = await createStudySessionDirectory(session.probandId);
    } catch (e) {
      if (mounted) {
        await _showError('Failed to prepare the session: $e');
      }
      return;
    }
    if (!mounted) {
      return;
    }

    await Navigator.of(context).push(
      platformPageRoute(
        context: context,
        builder: (_) => buildStudyPhaseEntryPage(
          phase: studyPhaseOrder.first,
          session: session,
          deviceSet: deviceSet,
          directory: directory,
        ),
      ),
    );

    if (mounted) {
      await _refreshAfterRecordingFlow();
    }
  }

  Future<void> _refreshAfterRecordingFlow() async {
    // Reload immediately when the protocol route returns, then once more after
    // the navigation frame and final filesystem metadata updates have settled.
    // Without the second read, Android can briefly show the session directory
    // with only the first phase file until the user manually pull-refreshes.
    await _loadRecordings();
    await Future<void>.delayed(_postProtocolRefreshDelay);
    if (mounted) {
      await _loadRecordings();
    }
  }

  Future<void> _showDevicesRequired() async {
    final shouldConnect = await showPlatformDialog<bool>(
          context: context,
          builder: (dialogContext) => PlatformAlertDialog(
            title: PlatformText('Devices required'),
            content: PlatformText(
              'Connect a pair of seal-check capable OpenEarables and a Plux '
              'RespiBAN to start a new recording.',
            ),
            actions: [
              PlatformDialogAction(
                child: PlatformText('Cancel'),
                onPressed: () => Navigator.pop(dialogContext, false),
              ),
              PlatformDialogAction(
                child: PlatformText('Connect devices'),
                onPressed: () => Navigator.pop(dialogContext, true),
              ),
            ],
          ),
        ) ??
        false;

    if (shouldConnect && mounted) {
      context.push('/connect-devices');
    }
  }

  Future<StudySession?> _promptSession() async {
    _probandIdController.clear();
    _ageController.clear();
    return showPlatformDialog<StudySession>(
      context: context,
      builder: (dialogContext) {
        String? error;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return PlatformAlertDialog(
              title: PlatformText('New recording'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  PlatformTextField(
                    controller: _probandIdController,
                    autofocus: true,
                    hintText: 'Proband ID',
                    textCapitalization: TextCapitalization.characters,
                    material: (_, __) => MaterialTextFieldData(
                      decoration:
                          const InputDecoration(labelText: 'Proband ID'),
                    ),
                  ),
                  const SizedBox(height: 10),
                  PlatformTextField(
                    controller: _ageController,
                    hintText: 'Age (years)',
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    material: (_, __) => MaterialTextFieldData(
                      decoration:
                          const InputDecoration(labelText: 'Age (years)'),
                    ),
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
              actions: [
                PlatformDialogAction(
                  child: PlatformText('Cancel'),
                  onPressed: () => Navigator.pop(dialogContext),
                ),
                PlatformDialogAction(
                  child: PlatformText('Continue'),
                  onPressed: () {
                    final probandId = _probandIdController.text.trim();
                    final age = int.tryParse(_ageController.text.trim());
                    if (probandId.isEmpty) {
                      setDialogState(() => error = 'Enter a proband ID.');
                      return;
                    }
                    if (age == null || age <= 0 || age > 120) {
                      setDialogState(() => error = 'Enter a valid age.');
                      return;
                    }
                    Navigator.pop(
                      dialogContext,
                      StudySession(probandId: probandId, age: age),
                    );
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _shareFolder(LocalRecorderRecordingFolder folder) async {
    try {
      await shareStudyFolder(folder);
    } catch (e) {
      await _showError('Failed to share recording: $e');
    }
  }

  Future<void> _shareFile(LocalRecorderRecordingFile file) async {
    try {
      await shareStudyFile(file);
    } catch (e) {
      await _showError('Failed to share file: $e');
    }
  }

  Future<void> _openFile(LocalRecorderRecordingFile file) async {
    try {
      await openStudyFile(file);
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
                      'DecoupEar protocol',
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
