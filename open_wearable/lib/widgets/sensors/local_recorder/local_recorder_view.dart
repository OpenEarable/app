import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:logger/logger.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:open_file/open_file.dart';
import 'package:open_wearable/view_models/sensor_recorder_provider.dart';
import 'package:open_wearable/view_models/wearables_provider.dart';

import '../../../models/local_recorder_controller.dart';
import 'record_header_card.dart';
import 'recordings_section.dart';

final Logger _uiLogger = Logger();

class LocalRecorderView extends StatefulWidget {
  const LocalRecorderView({super.key});

  @override
  State<LocalRecorderView> createState() => _LocalRecorderViewState();
}

class _LocalRecorderViewState extends State<LocalRecorderView> {
  static const MethodChannel platform = MethodChannel('edu.teco.open_folder');
  List<FileSystemEntity> _recordings = [];
  final Set<String> _expandedFolders = {};
  Timer? _recordingTimer;
  Duration _elapsedRecording = Duration.zero;
  bool _lastRecordingState = false;
  bool _isHandlingStopAction = false;
  DateTime? _activeRecordingStart;
  SensorRecorderProvider? _recorder;
  late final LocalRecorderController _controller;

  @override
  void initState() {
    super.initState();
    _controller = LocalRecorderController(
      platformChannel: platform,
      logger: _uiLogger,
    );
    _refreshRecordings();
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

  Future<void> _refreshRecordings() async {
    try {
      final recordings = await _controller.listRecordings();
      if (!mounted) return;
      setState(() {
        _recordings = recordings;
      });
    } catch (e) {
      _uiLogger.e('Error listing recordings: $e');
      await _showErrorDialog('Failed to list recordings: $e');
    }
  }

  Future<void> _confirmAndDelete(FileSystemEntity entity) async {
    if (!mounted) return;
    final name = entity.path.split('/').last;
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
      await _controller.deleteEntity(entity);
      await _refreshRecordings();
    } catch (e) {
      _uiLogger.e('Error deleting recording: $e');
      await _showErrorDialog('Failed to delete recording: $e');
    }
  }

  Future<void> _handleStopRecording(
    SensorRecorderProvider recorder, {
    required bool turnOffSensors,
  }) async {
    if (_isHandlingStopAction) return;
    setState(() {
      _isHandlingStopAction = true;
    });

    try {
      recorder.stopRecording();
      if (turnOffSensors) {
        final wearablesProvider = context.read<WearablesProvider>();
        final futures = wearablesProvider.sensorConfigurationProviders.values
            .map((provider) => provider.turnOffAllSensors());
        await Future.wait(futures);
      }
      await _refreshRecordings();
    } catch (e) {
      _uiLogger.e('Error stopping recording: $e');
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

  @override
  Widget build(BuildContext context) {
    return Consumer<SensorRecorderProvider>(
      builder: (context, recorder, _) {
        final isRecording = recorder.isRecording;
        final canStartRecording = recorder.hasSensorsConnected && !isRecording;

        return SafeArea(
          top: false,
          child: Column(
            children: [
              RecorderHeaderCard(
                isRecording: isRecording,
                elapsed: _elapsedRecording,
                canStartRecording: canStartRecording,
                isHandlingStopAction: _isHandlingStopAction,
                onStart: () async {
                  final dir = await _pickDirectory();
                  if (dir == null) return;

                  if (!await _isDirectoryEmpty(dir)) {
                    if (!context.mounted) return;
                    final proceed = await _askOverwriteConfirmation(context, dir);
                    if (!proceed) return;
                  }

                  recorder.startRecording(dir);
                  await _refreshRecordings();
                },
                onStop: () => _handleStopRecording(recorder, turnOffSensors: false),
                onStopAndTurnOff: () => _handleStopRecording(recorder, turnOffSensors: true),
                formatDuration: _formatDuration,
              ),
              Expanded(
                child: RecordingsSection(
                  recordings: _recordings,
                  isRecording: isRecording,
                  expandedFolders: _expandedFolders,
                  onToggleFolder: (folderPath, isExpanded, isCurrentRecording) {
                    setState(() {
                      if (isExpanded) {
                        _expandedFolders.remove(folderPath);
                      } else if (!isCurrentRecording) {
                        _expandedFolders.add(folderPath);
                      }
                    });
                  },
                  onShareFolder: (folder) => _controller.shareFolder(folder, onError: _showErrorDialog),
                  onDeleteFolder: _confirmAndDelete,
                  onShareFile: (file) => _controller.shareFile(file, onError: _showErrorDialog),
                  onOpenFile: (file) async {
                    final result = await OpenFile.open(
                      file.path,
                      type: 'text/comma-separated-values',
                    );
                    if (result.type != ResultType.done) {
                      await _showErrorDialog('Could not open file: ${result.message}');
                    }
                  },
                  onOpenRecordingsFolderIOS: Platform.isIOS
                      ? () async {
                          final recordDir = await getIOSDirectory();
                          await _controller.openFolder(recordDir.path);
                        }
                      : null,
                  getFilesInFolder: _controller.getFilesInFolder,
                  formatFileSize: _formatFileSize,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/* ──────────────────────────────────────────────────────────── */
/*  Helpers                                                    */
/* ──────────────────────────────────────────────────────────── */

Future<String?> _pickDirectory() async {
  if (!Platform.isIOS && !kIsWeb) {
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
