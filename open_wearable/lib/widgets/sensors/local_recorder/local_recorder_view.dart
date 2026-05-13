import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:logger/logger.dart';
import 'package:open_wearable/widgets/sensors/local_recorder/local_recorder_dialogs.dart';
import 'package:provider/provider.dart';
import 'package:open_wearable/view_models/sensor_recorder_provider_facade.dart';
import 'package:open_wearable/view_models/wearables_provider.dart';
import 'package:open_wearable/widgets/sensors/local_recorder/local_recorder_empty_state_card.dart';
import 'package:open_wearable/widgets/sensors/local_recorder/local_recorder_file_actions.dart';
import 'package:open_wearable/widgets/sensors/local_recorder/local_recorder_files.dart';
import 'package:open_wearable/widgets/sensors/local_recorder/local_recorder_models.dart';
import 'package:open_wearable/widgets/sensors/local_recorder/local_recorder_recording_card.dart';
import 'package:open_wearable/widgets/sensors/local_recorder/local_recorder_recording_folder_card.dart';
import 'package:open_wearable/widgets/sensors/local_recorder/local_recorder_see_all_recordings_card.dart';
import 'package:open_wearable/widgets/sensors/local_recorder/local_recorder_storage.dart';
import 'package:open_wearable/widgets/sensors/sensor_page_spacing.dart';

Logger _logger = Logger();

enum _StopRecordingMode {
  stopOnly,
  stopAndTurnOffSensors,
}

// MARK: - LocalRecorderView

class LocalRecorderView extends StatefulWidget {
  const LocalRecorderView({super.key});

  @override
  State<LocalRecorderView> createState() => _LocalRecorderViewState();
}

class _LocalRecorderViewState extends State<LocalRecorderView> {
  List<LocalRecorderRecordingFolder> _recordings = [];
  final Set<String> _expandedFolders = {}; // Track which folders are expanded
  Timer? _recordingTimer;
  Duration _elapsedRecording = Duration.zero;
  bool _lastRecordingState = false;
  bool _isHandlingStopAction = false;
  DateTime? _activeRecordingStart;
  SensorRecorderProvider? _recorder;

  @override
  void initState() {
    super.initState();
    _listRecordings();
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

  /// Load the list of recording folders from the device's storage, filtering and sorting them appropriately.
  Future<void> _listRecordings() async {
    final recordings = await listRecordingFolders();
    if (!mounted) return;
    setState(() {
      _recordings = recordings;
    });
  }

  List<LocalRecorderRecordingFile> _getFilesInFolder(
    LocalRecorderRecordingFolder folder,
  ) {
    return folder.files;
  }

  /// Show a confirmation dialog before deleting a recording folder or file, and handle the deletion if confirmed.
  Future<bool> _confirmAndDeleteRecording(
    LocalRecorderRecordingFolder entity,
  ) async {
    if (!mounted) return false;
    final name = entity.name;
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

    if (!shouldDelete) return false;

    try {
      await deleteRecordingFolder(entity.path);
      _listRecordings();
    } catch (e) {
      _logger.e('Error deleting recording: $e');
      await _showErrorDialog('Failed to delete recording: $e');
      return false;
    }
    return true;
  }

  Future<void> _handleStopRecording(
    SensorRecorderProvider recorder, {
    required _StopRecordingMode mode,
  }) async {
    if (_isHandlingStopAction) return;
    setState(() {
      _isHandlingStopAction = true;
    });

    try {
      recorder.stopRecording(mode == _StopRecordingMode.stopAndTurnOffSensors);
      if (mode == _StopRecordingMode.stopAndTurnOffSensors) {
        final wearablesProvider = context.read<WearablesProvider>();
        final futures = wearablesProvider.sensorConfigurationProviders.values
            .map((provider) => provider.turnOffAllSensors());
        await Future.wait(futures);
      }
      await _listRecordings();
    } catch (e) {
      _logger.e('Error stopping recording: $e');
      await _showErrorDialog('Failed to stop recording: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isHandlingStopAction = false;
        });
      }
    }
  }

  void _startRecordingTimer(DateTime? start) {
    final reference = start ?? DateTime.now();
    _activeRecordingStart = reference;
    _recordingTimer?.cancel();
    setState(() {
      _elapsedRecording = DateTime.now().difference(reference);
    });
    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        final base = _activeRecordingStart ?? reference;
        _elapsedRecording = DateTime.now().difference(base);
      });
    });
  }

  void _stopRecordingTimer() {
    _recordingTimer?.cancel();
    _recordingTimer = null;
    _activeRecordingStart = null;
    if (!mounted) return;
    setState(() {
      _elapsedRecording = Duration.zero;
    });
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(duration.inHours);
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$hours:$minutes:$seconds';
  }

  @override
  void dispose() {
    _recordingTimer?.cancel();
    _recorder?.removeListener(_handleRecorderUpdate);
    super.dispose();
  }

  void _handleRecorderUpdate() {
    final recorder = _recorder;
    if (recorder == null) return;
    final isRecording = recorder.isRecording;
    final start = recorder.recordingStart;
    if (isRecording && !_lastRecordingState) {
      _startRecordingTimer(start);
    } else if (!isRecording && _lastRecordingState) {
      _stopRecordingTimer();
    } else if (isRecording &&
        _lastRecordingState &&
        start != null &&
        _activeRecordingStart != null &&
        start != _activeRecordingStart) {
      _startRecordingTimer(start);
    }
    _lastRecordingState = isRecording;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final nextRecorder = context.watch<SensorRecorderProvider>();
    if (!identical(_recorder, nextRecorder)) {
      _recorder?.removeListener(_handleRecorderUpdate);
      _recorder = nextRecorder;
      _recorder?.addListener(_handleRecorderUpdate);
      _handleRecorderUpdate();
    }
  }

  Future<void> _shareFile(LocalRecorderRecordingFile file) async {
    try {
      await localRecorderShareFile(file);
    } catch (e) {
      _logger.e('Error sharing file: $e');
      if (!mounted) return;
      await LocalRecorderDialogs.showErrorDialog(
        context,
        'Failed to share file: $e',
      );
    }
  }

  Future<void> _shareFolder(LocalRecorderRecordingFolder folder) async {
    try {
      await localRecorderShareFolder(folder);
    } catch (e) {
      _logger.e('Error sharing folder: $e');
      if (!mounted) return;
      await LocalRecorderDialogs.showErrorDialog(
        context,
        'Failed to share folder: $e',
      );
    }
  }

  Future<void> _startRecording(SensorRecorderProvider recorder) async {
    final dir = await pickRecordingDirectory();
    if (dir == null) {
      await _showErrorDialog('Could not create a recording directory.');
      return;
    }

    if (!await Files.isDirectoryEmpty(dir)) {
      if (!mounted) return;
      final proceed = await _askOverwriteConfirmation(context, dir);
      if (!proceed) return;
    }

    try {
      await recorder.startRecording(dir);
      await _listRecordings();
    } catch (e) {
      _logger.e('Error starting recording: $e');
      await _showErrorDialog('Failed to start recording: $e');
    }
  }

  Future<void> _openRecordingFile(LocalRecorderRecordingFile file) async {
    await localRecorderOpenRecordingFile(file);
  }

  Future<void> _openAllRecordingsPage({required bool isRecording}) async {
    await context.push('/recordings', extra: isRecording);
    await _listRecordings();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SensorRecorderProvider>(
      builder: (context, recorder, _) {
        final isRecording = recorder.isRecording;
        final canStartRecording = recorder.hasSensorsConnected && !isRecording;
        final hasRecordings = _recordings.isNotEmpty;
        final latestRecording = hasRecordings ? _recordings.first : null;

        return SafeArea(
          top: false,
          child: RefreshIndicator(
            onRefresh: _listRecordings,
            child: ListView(
              padding: SensorPageSpacing.pagePaddingWithBottomInset(context),
              children: [
                LocalRecorderRecordingCard(
                  isRecording: isRecording,
                  hasSensorsConnected: recorder.hasSensorsConnected,
                  canStartRecording: canStartRecording,
                  isHandlingStopAction: _isHandlingStopAction,
                  elapsedRecordingLabel: _formatDuration(_elapsedRecording),
                  onStartRecording: () => _startRecording(recorder),
                  onStopAndTurnOff: () => _handleStopRecording(
                    recorder,
                    mode: _StopRecordingMode.stopAndTurnOffSensors,
                  ),
                  onStopRecordingOnly: () => _handleStopRecording(
                    recorder,
                    mode: _StopRecordingMode.stopOnly,
                  ),
                ),
                const SizedBox(height: SensorPageSpacing.sectionGap),
                Text(
                  "Recordings",
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (!hasRecordings) const LocalRecorderEmptyStateCard(),
                if (latestRecording != null)
                  LocalRecorderRecordingFolderCard(
                    folder: latestRecording,
                    isCurrentRecording: isRecording,
                    isExpanded: _expandedFolders.contains(latestRecording.path),
                    files: _expandedFolders.contains(latestRecording.path)
                        ? _getFilesInFolder(latestRecording)
                        : const <LocalRecorderRecordingFile>[],
                    updatedLabel:
                        'Updated ${localRecorderFormatDateTime(latestRecording.updatedAt)}',
                    onToggleExpanded: () async {
                      final path = latestRecording.path;
                      final isExpanding = !_expandedFolders.contains(path);

                      if (isExpanding) {
                        // 1. Fetch the absolute latest data from SharedPreferences
                        final allFolders = await listRecordingFolders();

                        // 2. Find the version of this folder that actually has the files populated
                        final freshFolder = allFolders.firstWhere(
                          (f) => f.path == path,
                          orElse: () => latestRecording,
                        );

                        if (mounted) {
                          setState(() {
                            // 3. Update the files list in our current reference so the UI sees them
                            latestRecording.files.clear();
                            latestRecording.files.addAll(freshFolder.files);

                            // 4. Mark as expanded
                            _expandedFolders.add(path);
                          });
                        }
                      } else {
                        setState(() {
                          _expandedFolders.remove(path);
                        });
                      }
                    },
                    onShareFolder: () => _shareFolder(latestRecording),
                    onDeleteFolder: () async {
                      final deleted =
                          await _confirmAndDeleteRecording(latestRecording);
                      if (!deleted) return;
                      setState(() {
                        _expandedFolders.remove(latestRecording.path);
                      });
                    },
                    onShareFile: _shareFile,
                    onOpenFile: _openRecordingFile,
                    formatFileSize: localRecorderFormatFileSize,
                  ),
                LocalRecorderSeeAllRecordingsTile(
                  recordingCount: _recordings.length,
                  onTap: () => _openAllRecordingsPage(
                    isRecording: isRecording,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

Future<bool> _askOverwriteConfirmation(
  BuildContext context,
  String dirPath,
) async {
  return await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: PlatformText('Directory not empty'),
          content: PlatformText(
              '"$dirPath" already contains files or folders.\n\n'
              'New sensor files will be added; existing files with the same '
              'names will be overwritten. Continue anyway?'),
          actions: [
            PlatformTextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: PlatformText('Cancel'),
            ),
            PlatformTextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: PlatformText('Continue'),
            ),
          ],
        ),
      ) ??
      false;
}
