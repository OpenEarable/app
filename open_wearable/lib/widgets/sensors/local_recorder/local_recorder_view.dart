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
import 'package:share_plus/share_plus.dart';
import 'package:flutter_archive/flutter_archive.dart';
import 'package:open_wearable/view_models/sensor_recorder_provider.dart';
import 'package:open_wearable/view_models/wearables_provider.dart';

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
  late final _LocalRecorderController _controller;

  @override
  void initState() {
    super.initState();
    _controller = _LocalRecorderController(
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
              _RecorderHeaderCard(
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
                child: _RecordingsSection(
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
                  onDeleteFolder: (folder) => _confirmAndDelete(folder),
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

class _RecorderHeaderCard extends StatelessWidget {
  const _RecorderHeaderCard({
    required this.isRecording,
    required this.elapsed,
    required this.canStartRecording,
    required this.isHandlingStopAction,
    required this.onStart,
    required this.onStop,
    required this.onStopAndTurnOff,
    required this.formatDuration,
  });

  final bool isRecording;
  final Duration elapsed;
  final bool canStartRecording;
  final bool isHandlingStopAction;
  final Future<void> Function() onStart;
  final VoidCallback onStop;
  final VoidCallback onStopAndTurnOff;
  final String Function(Duration) formatDuration;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(10),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PlatformText(
              'Local Recorder',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            PlatformText('Only records sensor data streamed over Bluetooth.'),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: !isRecording
                  ? ElevatedButton.icon(
                      icon: const Icon(Icons.play_arrow),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: canStartRecording
                            ? Colors.green.shade600
                            : Colors.grey.shade400,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(48),
                      ),
                      label: const Text(
                        'Start Recording',
                        style: TextStyle(fontSize: 18),
                      ),
                      onPressed: !canStartRecording ? null : onStart,
                    )
                  : Column(
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                icon: const Icon(Icons.stop),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                  foregroundColor: Colors.white,
                                  minimumSize: const Size.fromHeight(48),
                                ),
                                label: const Text(
                                  'Stop Recording',
                                  style: TextStyle(fontSize: 18),
                                ),
                                onPressed: isHandlingStopAction ? null : onStop,
                              ),
                            ),
                            const SizedBox(width: 8),
                            ConstrainedBox(
                              constraints: const BoxConstraints(minWidth: 90),
                              child: Text(
                                formatDuration(elapsed),
                                style: Theme.of(context)
                                    .textTheme
                                    .titleLarge
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.power_settings_new),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.redAccent,
                            foregroundColor: Colors.white,
                            minimumSize: const Size.fromHeight(48),
                          ),
                          label: const Text(
                            'Stop & Turn Off Sensors',
                            style: TextStyle(fontSize: 18),
                          ),
                          onPressed: isHandlingStopAction ? null : onStopAndTurnOff,
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecordingsSection extends StatelessWidget {
  const _RecordingsSection({
    required this.recordings,
    required this.isRecording,
    required this.expandedFolders,
    required this.onToggleFolder,
    required this.onShareFolder,
    required this.onDeleteFolder,
    required this.onShareFile,
    required this.onOpenFile,
    required this.onOpenRecordingsFolderIOS,
    required this.getFilesInFolder,
    required this.formatFileSize,
  });

  final List<FileSystemEntity> recordings;
  final bool isRecording;
  final Set<String> expandedFolders;
  final void Function(String folderPath, bool isExpanded, bool isCurrentRecording) onToggleFolder;
  final Future<void> Function(Directory folder) onShareFolder;
  final Future<void> Function(Directory folder) onDeleteFolder;
  final Future<void> Function(File file) onShareFile;
  final Future<void> Function(File file) onOpenFile;
  final Future<void> Function()? onOpenRecordingsFolderIOS;
  final List<File> Function(Directory folder) getFilesInFolder;
  final String Function(File file) formatFileSize;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Recordings',
                style: TextStyle(fontSize: 20.0, fontWeight: FontWeight.bold),
              ),
              if (onOpenRecordingsFolderIOS != null)
                IconButton(
                  icon: const Icon(Icons.folder_open),
                  onPressed: onOpenRecordingsFolderIOS,
                ),
            ],
          ),
        ),
        const Divider(thickness: 2),
        Expanded(
          child: recordings.isEmpty
              ? const _EmptyRecordingsState()
              : ListView.builder(
                  padding: EdgeInsets.zero,
                  itemCount: recordings.length,
                  itemBuilder: (context, index) {
                    final folder = recordings[index] as Directory;
                    final folderName = folder.path.split('/').last;
                    final isCurrentRecording = isRecording && index == 0;
                    final isExpanded = expandedFolders.contains(folder.path);
                    final files = isExpanded ? getFilesInFolder(folder) : <File>[];

                    return _RecordingFolderTile(
                      folder: folder,
                      folderName: folderName,
                      isExpanded: isExpanded,
                      isCurrentRecording: isCurrentRecording,
                      files: files,
                      onToggle: () => onToggleFolder(folder.path, isExpanded, isCurrentRecording),
                      onShareFolder: isCurrentRecording ? null : () => onShareFolder(folder),
                      onDeleteFolder: isCurrentRecording ? null : () => onDeleteFolder(folder),
                      formatFileSize: formatFileSize,
                      onShareFile: onShareFile,
                      onOpenFile: onOpenFile,
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _EmptyRecordingsState extends StatelessWidget {
  const _EmptyRecordingsState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(Icons.warning, size: 48, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'No recordings found',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

class _RecordingFolderTile extends StatelessWidget {
  const _RecordingFolderTile({
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

class _LocalRecorderController {
  _LocalRecorderController({
    required this.platformChannel,
    required this.logger,
  });

  final MethodChannel platformChannel;
  final Logger logger;

  Future<List<FileSystemEntity>> listRecordings() async {
    final recordingsDir = await _getRecordingsRootDirectory();
    if (recordingsDir == null) return [];

    if (!await recordingsDir.exists()) return [];

    final entities = recordingsDir.listSync();

    final recordings = entities
        .where((entity) => entity is Directory && entity.path.contains('OpenWearable_Recording'))
        .toList();

    recordings.sort((a, b) => b.statSync().changed.compareTo(a.statSync().changed));
    return recordings;
  }

  List<File> getFilesInFolder(Directory folder) {
    try {
      return folder.listSync(recursive: false).whereType<File>().toList()
        ..sort((a, b) => a.path.split('/').last.compareTo(b.path.split('/').last));
    } catch (e) {
      logger.e('Error listing files in folder: $e');
      return [];
    }
  }

  Future<void> deleteEntity(FileSystemEntity entity) async {
    if (!entity.existsSync()) return;
    if (entity is Directory) {
      await entity.delete(recursive: true);
    } else {
      await entity.delete();
    }
  }

  Future<void> shareFile(File file, {required Future<void> Function(String) onError}) async {
    try {
      final result = await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          subject: 'OpenWearable Recording File',
        ),
      );

      if (result.status == ShareResultStatus.success) {
        logger.i('File shared successfully');
      }
    } catch (e) {
      logger.e('Error sharing file: $e');
      await onError('Failed to share file: $e');
    }
  }

  Future<void> shareFolder(Directory folder, {required Future<void> Function(String) onError}) async {
    try {
      logger.i('Creating zip file for ${folder.path}...');

      final tempDir = await getTemporaryDirectory();
      final zipPath = '${tempDir.path}/${folder.path.split('/').last}.zip';
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
        logger.i('Folder shared successfully');
      }

      if (await zipFile.exists()) {
        await zipFile.delete();
      }
    } catch (e) {
      logger.e('Error sharing folder: $e');
      await onError('Failed to share folder: $e');
    }
  }

  Future<void> openFolder(String path) async {
    try {
      if (Platform.isIOS) {
        await platformChannel.invokeMethod('openFolder', {'path': 'shareddocuments://$path'});
      } else if (Platform.isAndroid) {
        await platformChannel.invokeMethod('openFolder', {'path': path});
      }
    } on PlatformException catch (e) {
      logger.e("Failed to open folder: '${e.message}'.");
    }
  }

  Future<Directory?> _getRecordingsRootDirectory() async {
    if (Platform.isAndroid) {
      return await getExternalStorageDirectory();
    }
    if (Platform.isIOS) {
      return await getIOSDirectory();
    }
    return null;
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
