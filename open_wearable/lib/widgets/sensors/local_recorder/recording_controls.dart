import 'dart:async';

import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:open_wearable/view_models/sensor_recorder_provider.dart';
import 'package:open_wearable/view_models/wearables_provider.dart';
import 'package:open_wearable/widgets/sensors/local_recorder/local_recorder_dialogs.dart';
import 'package:open_wearable/widgets/sensors/local_recorder/local_recorder_files.dart';
import 'package:provider/provider.dart';

Logger _logger = Logger();

class RecordingControls extends StatefulWidget {
  const RecordingControls({
    super.key,
    required this.canStartRecording,
    required this.isRecording,
    required this.recorder,
    required this.updateRecordingsList,
  });

  final bool canStartRecording;
  final bool isRecording;
  final SensorRecorderProvider recorder;

  final Future<void> Function() updateRecordingsList;

  @override
  State<RecordingControls> createState() => _RecordingControls();
}

class _RecordingControls extends State<RecordingControls> {
  Duration _elapsedRecording = Duration.zero;
  Timer? _recordingTimer;
  bool _isHandlingStopAction = false;
  bool _lastRecordingState = false;
  SensorRecorderProvider? _recorder;
  DateTime? _activeRecordingStart;

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(d.inHours);
    final minutes = twoDigits(d.inMinutes.remainder(60));
    final seconds = twoDigits(d.inSeconds.remainder(60));
    return '$hours:$minutes:$seconds';
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
      recorder.stopRecording(turnOffSensors);
      if (turnOffSensors) {
        final wearablesProvider = context.read<WearablesProvider>();
        final futures = wearablesProvider.sensorConfigurationProviders.values
            .map((provider) => provider.turnOffAllSensors());
        await Future.wait(futures);
        await recorder.stopBLEMicrophoneStream();
      }
      await widget.updateRecordingsList();
    } catch (e) {
      _logger.e('Error stopping recording: $e');
      if (!mounted) return;
      await LocalRecorderDialogs.showErrorDialog(
        context,
        'Failed to stop recording: $e',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isHandlingStopAction = false;
        });
      }
    }
  }

  @override
  void didUpdateWidget(covariant RecordingControls oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Start timer if parent says recording started
    if (widget.isRecording && !oldWidget.isRecording) {
      _startRecordingTimer(widget.recorder.recordingStart);
    }

    // Stop timer if parent says recording stopped
    if (!widget.isRecording && oldWidget.isRecording) {
      _stopRecordingTimer();
    }
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

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: !widget.isRecording
          ? ElevatedButton.icon(
              icon: const Icon(Icons.play_arrow),
              style: ElevatedButton.styleFrom(
                backgroundColor: widget.canStartRecording
                    ? Colors.green.shade600
                    : Colors.grey.shade400,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(48),
              ),
              label: const Text(
                'Start Recording',
                style: TextStyle(fontSize: 18),
              ),
              onPressed: !widget.canStartRecording
                  ? null
                  : () async {
                      final dir = await Files.pickDirectory();
                      if (dir == null) return;

                      // Check if directory is empty
                      if (!await Files.isDirectoryEmpty(dir)) {
                        if (!context.mounted) return;
                        final proceed =
                            await LocalRecorderDialogs.askOverwriteConfirmation(
                          context,
                          dir,
                        );
                        if (!proceed) return;
                      }

                      widget.recorder.startRecording(dir);
                      await widget.updateRecordingsList(); // Refresh list
                    },
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
                            : () => _handleStopRecording(
                                  widget.recorder,
                                  turnOffSensors: false,
                                ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ConstrainedBox(
                      constraints: const BoxConstraints(
                        minWidth: 90,
                      ),
                      child: Text(
                        _formatDuration(_elapsedRecording),
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  icon: const Icon(Icons.power_settings_new),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red[800],
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(48),
                  ),
                  label: const Text(
                    'Stop & Turn Off Sensors',
                    style: TextStyle(fontSize: 18),
                  ),
                  onPressed: _isHandlingStopAction
                      ? null
                      : () => _handleStopRecording(
                            widget.recorder,
                            turnOffSensors: true,
                          ),
                ),
              ],
            ),
    );
  }
}
