import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';

class RecorderHeaderCard extends StatelessWidget {
  const RecorderHeaderCard({
    super.key, 
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
