import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:open_wearable/view_models/label_set_provider.dart';
import 'package:open_wearable/widgets/sensors/local_recorder/labels/label_set_selector.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import 'package:open_wearable/view_models/sensor_recorder_provider.dart';
import 'package:open_wearable/view_models/wearables_provider.dart';

import '../../../models/logger.dart';

/// Header card for the local recorder.
///
/// This widget is provider-connected and manages:
/// - Start / stop recording actions (via [SensorRecorderProvider])
/// - Recording timer display
/// - Optional "Stop & Turn Off Sensors" behavior (via [WearablesProvider], if present)
///
/// The parent can optionally pass callbacks to refresh external UI (e.g. recordings list)
/// after start/stop operations.
class RecorderHeaderCard extends StatefulWidget {
  const RecorderHeaderCard({
    super.key,
    this.onRecordingStarted,
    this.onRecordingStopped,
  });

  /// Called after a recording is started successfully.
  final Future<void> Function()? onRecordingStarted;

  /// Called after a recording is stopped successfully.
  final Future<void> Function()? onRecordingStopped;

  @override
  State<RecorderHeaderCard> createState() => _RecorderHeaderCardState();
}

class _RecorderHeaderCardState extends State<RecorderHeaderCard> {
  Timer? _timer;
  Duration _elapsed = Duration.zero;
  DateTime? _activeRecordingStart;
  bool _isHandlingStopAction = false;
  bool _lastRecordingState = false;
  bool _timerSyncScheduled = false;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer(DateTime? start) {
    final reference = start ?? DateTime.now();
    _activeRecordingStart = reference;

    _timer?.cancel();

    // Initialize elapsed without calling setState here. The caller will schedule
    // a post-frame update.
    _elapsed = DateTime.now().difference(reference);

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        final base = _activeRecordingStart ?? reference;
        _elapsed = DateTime.now().difference(base);
      });
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
    _activeRecordingStart = null;

    // Reset elapsed without calling setState here. The caller will schedule
    // a post-frame update.
    _elapsed = Duration.zero;
  }

  void _syncTimerFromProvider(SensorRecorderProvider recorder) {
    final isRecording = recorder.isRecording;
    final start = recorder.recordingStart;

    if (isRecording && !_lastRecordingState) {
      _startTimer(start);
    } else if (!isRecording && _lastRecordingState) {
      _stopTimer();
    } else if (isRecording &&
        _lastRecordingState &&
        start != null &&
        _activeRecordingStart != null &&
        start != _activeRecordingStart) {
      _startTimer(start);
    }

    _lastRecordingState = isRecording;
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(duration.inHours);
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$hours:$minutes:$seconds';
  }

  Future<String?> _createRecordingDirectory() async {
    final recordingName =
        'OpenWearable_Recording_${DateTime.now().toIso8601String()}';

    // Android (non-web): use external storage.
    if (!Platform.isIOS && !Platform.isMacOS && !kIsWeb) {
      final appDir = await getExternalStorageDirectory();
      if (appDir == null) return null;

      final dirPath = '${appDir.path}/$recordingName';
      final dir = Directory(dirPath);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      return dirPath;
    }

    // iOS: use documents directory (via path_provider).
    if (Platform.isIOS) {
      final appDir = await getApplicationDocumentsDirectory();
      final dirPath = '${appDir.path}/$recordingName';
      final dir = Directory(dirPath);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      return dirPath;
    }

    // Other platforms currently not supported in this flow.
    return null;
  }

  Future<bool> _isDirectoryEmpty(String path) async {
    final dir = Directory(path);
    if (!await dir.exists()) return true;
    return await dir.list(followLinks: false).isEmpty;
  }

  Future<bool> _askOverwriteConfirmation(
      BuildContext context, String dirPath,) async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: PlatformText('Directory not empty'),
            content: PlatformText(
              '"$dirPath" already contains files or folders.\n\n'
              'New sensor files will be added; existing files with the same '
              'names will be overwritten. Continue anyway?',
            ),
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

  Future<void> _handleStart(SensorRecorderProvider recorder) async {
    final dir = await _createRecordingDirectory();
    logger.d("Created recording directory at $dir");
    if (dir == null) return;

    if (!await _isDirectoryEmpty(dir)) {
      logger.w("Recording directory $dir is not empty");
      if (!mounted) return;
      final proceed = await _askOverwriteConfirmation(context, dir);
      if (!proceed) return;
    }

    recorder.startRecording(dir);

    // Let parent refresh recordings list, etc.
    await widget.onRecordingStarted?.call();
  }

  Future<void> _handleStop(
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
        // Optional dependency: only works if WearablesProvider is in the tree.
        try {
          final wearablesProvider = context.read<WearablesProvider>();
          final futures = wearablesProvider.sensorConfigurationProviders.values
              .map((provider) => provider.turnOffAllSensors());
          await Future.wait(futures);
        } catch (_) {
          // ignore if not available
        }
      }

      await widget.onRecordingStopped?.call();
    } finally {
      if (mounted) {
        setState(() {
          _isHandlingStopAction = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SensorRecorderProvider>(
      builder: (context, recorder, _) {
        _syncTimerFromProvider(recorder);

        // Ensure any timer/start-stop changes are reflected in the UI *after*
        // this build completes to avoid setState-during-build.
        if (!_timerSyncScheduled) {
          _timerSyncScheduled = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            setState(() {
              _timerSyncScheduled = false;
            });
          });
        }

        final isRecording = recorder.isRecording;
        final canStartRecording = recorder.hasSensorsConnected && !isRecording;

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
                PlatformText(
                    'Only records sensor data streamed over Bluetooth.',),
                const SizedBox(height: 12),
                LabelSetSelector(
                  selected: null,
                  onChanged: (_) {},
                ),
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
                          onPressed: !canStartRecording
                              ? null
                              : () => _handleStart(recorder),
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
                                    onPressed: _isHandlingStopAction
                                        ? null
                                        : () => _handleStop(
                                              recorder,
                                              turnOffSensors: false,
                                            ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                ConstrainedBox(
                                  constraints:
                                      const BoxConstraints(minWidth: 90),
                                  child: Text(
                                    _formatDuration(_elapsed),
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
                              onPressed: _isHandlingStopAction
                                  ? null
                                  : () => _handleStop(
                                        recorder,
                                        turnOffSensors: true,
                                      ),
                            ),
                          ],
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

@Preview(name: "RecorderHeaderCard")
Widget recorderHeaderCardPreview() {
  return MultiProvider(providers: [
    ChangeNotifierProvider<SensorRecorderProvider>(
      create: (_) => SensorRecorderProvider(),
    ),
    ChangeNotifierProvider<LabelSetProvider>(
      create: (_) => LabelSetProvider(),
    ),
  ], child: Scaffold(
    body: Center(
      child: RecorderHeaderCard(),
    ),
  ),);
}
