import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:logger/logger.dart';
import 'package:open_file/open_file.dart';
import 'package:provider/provider.dart';
import 'package:open_wearable/view_models/sensor_recorder_provider.dart';
import 'package:open_wearable/view_models/wearables_provider.dart';
import 'package:open_wearable/widgets/sensors/local_recorder/local_recorder_empty_state_card.dart';
import 'package:open_wearable/widgets/sensors/local_recorder/local_recorder_file_actions.dart';
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
  List<FileSystemEntity> _recordings = [];
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
    final recordings = await listRecordingDirectories();
    if (!mounted) return;
    setState(() {
      _recordings = recordings.cast<FileSystemEntity>();
    });
  }

  List<File> _getFilesInFolder(Directory folder) {
    return listFilesInRecordingFolder(folder);
  }

  /// Show a confirmation dialog before deleting a recording folder or file, and handle the deletion if confirmed.
  Future<bool> _confirmAndDeleteRecording(FileSystemEntity entity) async {
    if (!mounted) return false;
    final name = localRecorderBasename(entity.path);
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

    if (entity.existsSync()) {
      try {
        if (entity is Directory) {
          entity.deleteSync(recursive: true);
        } else {
          entity.deleteSync();
        }
        _listRecordings();
      } catch (e) {
        _logger.e('Error deleting recording: $e');
        _showErrorDialog('Failed to delete recording: $e');
        return false;
      }
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
      recorder.stopRecording();
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

  Future<void> _shareFile(File file) async {
    try {
      await localRecorderShareFile(file);
    } catch (e) {
      _logger.e('Error sharing file: $e');
      await _showErrorDialog('Failed to share file: $e');
    }
  }

  Future<void> _shareFolder(Directory folder) async {
    try {
      await localRecorderShareFolder(folder);
    } catch (e) {
      _logger.e('Error sharing folder: $e');
      await _showErrorDialog('Failed to share folder: $e');
    }
  }

  Future<void> _startRecording(SensorRecorderProvider recorder) async {
    final dir = await pickRecordingDirectory();
    if (dir == null) {
      await _showErrorDialog('Could not create a recording directory.');
      return;
    }

    if (!await isDirectoryEmpty(dir)) {
      if (!mounted) return;
      final proceed = await _askOverwriteConfirmation(context, dir);
      if (!proceed) return;
    }

    recorder.startRecording(dir);
    await _listRecordings();
  }

  Future<void> _openRecordingFile(File file) async {
    final result = await localRecorderOpenRecordingFile(file);
    if (result.type != ResultType.done) {
      await _showErrorDialog('Could not open file: ${result.message}');
    }
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
        final latestRecording =
            hasRecordings ? _recordings.first as Directory : null;

        return SafeArea(
          top: false,
          child: RefreshIndicator(
            onRefresh: _listRecordings,
            child: Padding(
              padding: SensorPageSpacing.pageHeaderPadding,
              child: ListView(
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
                  Text("Recordings", style: Theme.of(context).textTheme.titleMedium),
                  if (!hasRecordings) const LocalRecorderEmptyStateCard(),
                  if (latestRecording != null)
                    LocalRecorderRecordingFolderCard(
                      folder: latestRecording,
                      isCurrentRecording: isRecording,
                      isExpanded: _expandedFolders.contains(
                        latestRecording.path,
                      ),
                      files: _expandedFolders.contains(latestRecording.path)
                          ? _getFilesInFolder(latestRecording)
                          : const <File>[],
                      updatedLabel:
                          'Updated ${localRecorderFormatDateTime(latestRecording.statSync().changed)}',
                      onToggleExpanded: () {
                        setState(() {
                          if (_expandedFolders.contains(latestRecording.path)) {
                            _expandedFolders.remove(latestRecording.path);
                          } else {
                            _expandedFolders.add(latestRecording.path);
                          }
                        });
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
