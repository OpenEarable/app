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
import 'package:open_wearable/widgets/recording_activity_indicator.dart';
import 'package:open_wearable/widgets/sensors/sensor_page_spacing.dart';

Logger _logger = Logger();

enum _StopRecordingMode {
  stopOnly,
  stopAndTurnOffSensors,
}

class LocalRecorderView extends StatefulWidget {
  const LocalRecorderView({super.key});

  @override
  State<LocalRecorderView> createState() => _LocalRecorderViewState();
}

class _LocalRecorderViewState extends State<LocalRecorderView> {
  static const MethodChannel platform = MethodChannel('edu.teco.open_folder');
  final ScrollController _recordingsScrollController = ScrollController();
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

  void _scrollRecordingsFromHeaderDrag(DragUpdateDetails details) {
    if (!_recordingsScrollController.hasClients) return;
    final position = _recordingsScrollController.position;
    final nextOffset = (position.pixels - details.delta.dy).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    if (nextOffset != position.pixels) {
      _recordingsScrollController.jumpTo(nextOffset);
    }
  }

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

  Future<void> _openFolder(String path) async {
    if (kIsWeb) {
      return;
    }

    try {
      if (_isIOS) {
        await platform
            .invokeMethod('openFolder', {'path': "shareddocuments://$path"});
      } else if (_isAndroid) {
        await platform.invokeMethod('openFolder', {'path': path});
      }
    } on PlatformException catch (e) {
      _logger.w("Failed to open folder: '${e.message}'.");
      await _showErrorDialog('Failed to open recording folder.');
    }
  }

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

  Future<void> _confirmAndDeleteRecording(FileSystemEntity entity) async {
    if (!mounted) return;
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

    if (!shouldDelete) return;

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
      }
    }
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
    _recordingsScrollController.dispose();
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

  Widget _buildRecorderCard(
    BuildContext context, {
    required SensorRecorderProvider recorder,
    required bool isRecording,
    required bool canStartRecording,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final hasSensorsConnected = recorder.hasSensorsConnected;
    final statusIcon = isRecording
        ? Icons.fiber_manual_record
        : hasSensorsConnected
            ? Icons.sensors
            : Icons.sensors_off;
    final statusColor = isRecording
        ? colorScheme.error
        : hasSensorsConnected
            ? colorScheme.primary
            : colorScheme.onSurfaceVariant;
    final statusTitle = isRecording
        ? 'Recording in progress'
        : hasSensorsConnected
            ? 'Ready to record'
            : 'No active sensors';
    final statusSubtitle = isRecording
        ? 'Capturing live Bluetooth sensor data.'
        : hasSensorsConnected
            ? 'Start a session to capture live Bluetooth sensor data.'
            : 'Connect a wearable and enable sensors to start recording.';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: isRecording
                      ? const Center(
                          child: RecordingActivityIndicator(
                            size: 20,
                            showIdleOutline: false,
                            padding: EdgeInsets.zero,
                          ),
                        )
                      : Icon(statusIcon, color: statusColor, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Local Recorder',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        statusTitle,
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: statusColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        statusSubtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isRecording)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.errorContainer.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      _formatDuration(_elapsedRecording),
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: colorScheme.onErrorContainer,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            if (!isRecording)
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: canStartRecording
                      ? () => _startRecording(recorder)
                      : null,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Start Recording'),
                ),
              ),
            if (!isRecording && !recorder.hasSensorsConnected)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'No connected sensors detected yet.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            if (isRecording) ...[
              Row(
                children: [
                  Expanded(
                    child: FilledButton.tonalIcon(
                      style: FilledButton.styleFrom(
                        foregroundColor: colorScheme.error,
                        backgroundColor:
                            colorScheme.errorContainer.withValues(alpha: 0.45),
                      ),
                      onPressed: _isHandlingStopAction
                          ? null
                          : () => _handleStopRecording(
                                recorder,
                                mode: _StopRecordingMode.stopAndTurnOffSensors,
                              ),
                      icon: const Icon(Icons.power_settings_new),
                      label: const Text('Stop + Off'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: colorScheme.error,
                        foregroundColor: colorScheme.onError,
                      ),
                      onPressed: _isHandlingStopAction
                          ? null
                          : () => _handleStopRecording(
                                recorder,
                                mode: _StopRecordingMode.stopOnly,
                              ),
                      icon: const Icon(Icons.stop),
                      label: const Text('Stop Recording'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRecordingsHeaderCard(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final recordingCount = _recordings.length;
    final subtitle = recordingCount == 1
        ? '1 recording folder'
        : '$recordingCount recording folders';

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        child: Row(
          children: [
            Expanded(
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                minLeadingWidth: 26,
                leading: const Icon(Icons.folder_copy_outlined),
                title: const Text('Recordings'),
                subtitle: Text(subtitle),
              ),
            ),
            IconButton(
              tooltip: 'Refresh recordings',
              onPressed: _listRecordings,
              icon: const Icon(Icons.refresh),
            ),
            if (_isIOS)
              IconButton(
                tooltip: 'Open recording folder',
                onPressed: () async {
                  final recordDir = await getIOSDirectory();
                  _openFolder(recordDir.path);
                },
                icon: Icon(
                  Icons.folder_open,
                  color: colorScheme.primary,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyRecordingsState(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            Icon(
              Icons.folder_open_outlined,
              size: 36,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 10),
            Text(
              'No recordings yet',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Start a recording session to create your first export.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecordingFileTile(BuildContext context, File file) {
    final fileName = _basename(file.path);
    final fileSize = _formatFileSize(file);
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
        onPressed: () => _shareFile(file),
      ),
      onTap: () => _openRecordingFile(file),
    );
  }

  Widget _buildRecordingCard(
    BuildContext context,
    Directory folder, {
    required bool isRecording,
    required int index,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final folderName = _basename(folder.path);
    final isCurrentRecording = isRecording && index == 0;
    final isExpanded = _expandedFolders.contains(folder.path);
    final files = isExpanded ? _getFilesInFolder(folder) : <File>[];
    final modified = folder.statSync().changed;

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
              isCurrentRecording
                  ? 'Active recording'
                  : 'Updated ${_formatDateTime(modified)}',
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
                        onPressed: () => _shareFolder(folder),
                        icon: Icon(Icons.ios_share, color: colorScheme.primary),
                      ),
                      IconButton(
                        tooltip: 'Delete folder',
                        onPressed: () => _confirmAndDeleteRecording(folder),
                        icon: Icon(
                          Icons.delete_outline,
                          color: colorScheme.error,
                        ),
                      ),
                      Icon(
                        isExpanded ? Icons.expand_less : Icons.expand_more,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ],
                  ),
            onTap: () {
              if (isCurrentRecording) return;
              setState(() {
                if (isExpanded) {
                  _expandedFolders.remove(folder.path);
                } else {
                  _expandedFolders.add(folder.path);
                }
              });
            },
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
              (file) => _buildRecordingFileTile(
                context,
                file,
              ),
            ),
        ],
      ),
    );
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
              Padding(
                padding: SensorPageSpacing.pageHeaderPadding,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onVerticalDragUpdate: _scrollRecordingsFromHeaderDrag,
                  child: Column(
                    children: [
                      _buildRecorderCard(
                        context,
                        recorder: recorder,
                        isRecording: isRecording,
                        canStartRecording: canStartRecording,
                      ),
                      const SizedBox(height: SensorPageSpacing.sectionGap),
                      _buildRecordingsHeaderCard(context),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _listRecordings,
                  child: ListView(
                    controller: _recordingsScrollController,
                    primary: false,
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: SensorPageSpacing.pageListPadding,
                    children: [
                      if (_recordings.isEmpty)
                        _buildEmptyRecordingsState(context),
                      if (_recordings.isNotEmpty)
                        ..._recordings.asMap().entries.map((entry) {
                          final folder = entry.value as Directory;
                          return _buildRecordingCard(
                            context,
                            folder,
                            isRecording: isRecording,
                            index: entry.key,
                          );
                        }),
                    ],
                  ),
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
