import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:logger/logger.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:open_file/open_file.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_archive/flutter_archive.dart';
import 'package:open_wearable/view_models/sensor_recorder_provider.dart';
import 'package:open_wearable/view_models/wearables_provider.dart';
import 'package:open_wearable/widgets/sensors/local_recorder/local_recorder_all_recordings_page.dart';
import 'package:open_wearable/widgets/sensors/local_recorder/local_recorder_empty_state_card.dart';
import 'package:open_wearable/widgets/sensors/local_recorder/local_recorder_recording_card.dart';
import 'package:open_wearable/widgets/sensors/local_recorder/local_recorder_recording_folder_card.dart';
import 'package:open_wearable/widgets/sensors/local_recorder/local_recorder_see_all_recordings_card.dart';
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

  bool get _isIOS => !kIsWeb && Platform.isIOS;
  bool get _isAndroid => !kIsWeb && Platform.isAndroid;

  String _basename(String path) => path.split(RegExp(r'[\\/]+')).last;

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
    if (kIsWeb) {
      if (!mounted) return;
      setState(() {
        _recordings = [];
      });
      return;
    }

    Directory recordingsDir;

    if (_isAndroid) {
      Directory? dir = await getExternalStorageDirectory();
      if (dir == null) {
        if (!mounted) return;
        setState(() {
          _recordings = [];
        });
        return;
      }
      recordingsDir = dir;
    } else if (_isIOS) {
      recordingsDir = await getIOSDirectory();
    } else {
      if (!mounted) return;
      setState(() {
        _recordings = [];
      });
      return;
    }

    if (!await recordingsDir.exists()) {
      if (!mounted) return;
      setState(() {
        _recordings = [];
      });
      return;
    }

    List<FileSystemEntity> entities = recordingsDir.listSync();

    // Filter only directories that start with "OpenWearable_Recording"
    final recordings = entities
        .where(
          (entity) =>
              entity is Directory &&
              entity.path.contains('OpenWearable_Recording'),
        )
        .toList();

    // Sort by modification time (newest first)
    recordings.sort((a, b) {
      return b.statSync().changed.compareTo(a.statSync().changed);
    });

    if (!mounted) return;
    setState(() {
      _recordings = recordings;
    });
  }

  List<File> _getFilesInFolder(Directory folder) {
    try {
      return folder.listSync(recursive: false).whereType<File>().toList()
        ..sort((a, b) => _basename(a.path).compareTo(_basename(b.path)));
    } catch (e) {
      _logger.e('Error listing files in folder: $e');
      return [];
    }
  }

  /// Show a confirmation dialog before deleting a recording folder or file, and handle the deletion if confirmed.
  Future<bool> _confirmAndDeleteRecording(FileSystemEntity entity) async {
    if (!mounted) return false;
    final name = _basename(entity.path);
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

  String _formatFileSize(File file) {
    int bytes = file.lengthSync();
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Future<void> _shareFile(File file) async {
    try {
      final result = await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          subject: 'OpenWearable Recording File',
        ),
      );

      if (result.status == ShareResultStatus.success) {
        _logger.i('File shared successfully');
      }
    } catch (e) {
      _logger.e('Error sharing file: $e');
      await _showErrorDialog('Failed to share file: $e');
    }
  }

  Future<void> _shareFolder(Directory folder) async {
    try {
      // Replaced SnackBar with Logger to avoid UI issues during async work
      _logger.i('Creating zip file for ${folder.path}...');

      final tempDir = await getTemporaryDirectory();
      final zipPath = '${tempDir.path}/${_basename(folder.path)}.zip';
      final zipFile = File(zipPath);

      await ZipFile.createFromDirectory(
        sourceDir: folder,
        zipFile: zipFile,
        recurseSubDirs: true,
      );

      final result = await SharePlus.instance.share(
        ShareParams(
          files: [XFile(zipFile.path)],
          subject: 'OpenWearable Recording',
        ),
      );

      if (result.status == ShareResultStatus.success) {
        _logger.i('Folder shared successfully');
      }

      if (await zipFile.exists()) {
        await zipFile.delete();
      }
    } catch (e) {
      _logger.e('Error sharing folder: $e');
      await _showErrorDialog('Failed to share folder: $e');
    }
  }

  String _formatDateTime(DateTime value) {
    final local = value.toLocal();
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    return '${local.year}-${twoDigits(local.month)}-${twoDigits(local.day)} '
        '${twoDigits(local.hour)}:${twoDigits(local.minute)}';
  }

  Future<void> _startRecording(SensorRecorderProvider recorder) async {
    final dir = await _pickDirectory();
    if (dir == null) {
      await _showErrorDialog('Could not create a recording directory.');
      return;
    }

    if (!await _isDirectoryEmpty(dir)) {
      if (!mounted) return;
      final proceed = await _askOverwriteConfirmation(context, dir);
      if (!proceed) return;
    }

    recorder.startRecording(dir);
    await _listRecordings();
  }

  Future<void> _openRecordingFile(File file) async {
    final result = await OpenFile.open(
      file.path,
      type: 'text/comma-separated-values',
    );
    if (result.type != ResultType.done) {
      await _showErrorDialog('Could not open file: ${result.message}');
    }
  }

  Future<void> _openAllRecordingsPage({required bool isRecording}) async {
    //TODO: use go navigator instead of pushing a new page to avoid reloading recordings list on return
    final recordings = _recordings.whereType<Directory>().toList();
    await Navigator.of(context).push(
      platformPageRoute(
        context: context,
        builder: (_) => LocalRecorderAllRecordingsPage(
          recordings: recordings,
          isRecording: isRecording,
          formatDateTime: _formatDateTime,
          getFilesInFolder: _getFilesInFolder,
          formatFileSize: _formatFileSize,
          onShareFile: _shareFile,
          onOpenFile: _openRecordingFile,
          onShareFolder: _shareFolder,
          onDeleteFolder: _confirmAndDeleteRecording,
        ),
      ),
    );
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
                          'Updated ${_formatDateTime(latestRecording.statSync().changed)}',
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
                      formatFileSize: _formatFileSize,
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

/* ──────────────────────────────────────────────────────────── */
/*  MARK: Helpers                                               */
/* ──────────────────────────────────────────────────────────── */

Future<String?> _pickDirectory() async {
  if (kIsWeb) {
    return null;
  }

  if (Platform.isAndroid) {
    final recordingName =
        'OpenWearable_Recording_${DateTime.now().toIso8601String()}';
    Directory? appDir = await getExternalStorageDirectory();
    if (appDir == null) return null;

    String dirPath = '${appDir.path}/$recordingName';
    Directory dir = Directory(dirPath);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dirPath;
  }

  if (Platform.isIOS) {
    final recordingName =
        'OpenWearable_Recording_${DateTime.now().toIso8601String()}';
    String dirPath = '${(await getIOSDirectory()).path}/$recordingName';
    Directory dir = Directory(dirPath);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dirPath;
  }

  return null;
}

Future<Directory> getIOSDirectory() async {
  Directory appDocDir = await getApplicationDocumentsDirectory();
  final dirPath = '${appDocDir.path}/Recordings';
  final dir = Directory(dirPath);

  if (!await dir.exists()) {
    await dir.create(recursive: true);
  }

  return dir;
}

Future<bool> _isDirectoryEmpty(String path) async {
  final dir = Directory(path);
  if (!await dir.exists()) return true;
  return await dir.list(followLinks: false).isEmpty;
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
