import 'package:flutter/material.dart';
import 'package:open_wearable/widgets/recording_activity_indicator.dart';

class LocalRecorderRecordingCard extends StatelessWidget {
  final bool isRecording;
  final bool hasSensorsConnected;
  final bool canStartRecording;
  final bool isHandlingStopAction;
  final String elapsedRecordingLabel;
  final VoidCallback? onStartRecording;
  final VoidCallback? onStopAndTurnOff;
  final VoidCallback? onStopRecordingOnly;

  const LocalRecorderRecordingCard({
    super.key,
    required this.isRecording,
    required this.hasSensorsConnected,
    required this.canStartRecording,
    required this.isHandlingStopAction,
    required this.elapsedRecordingLabel,
    required this.onStartRecording,
    required this.onStopAndTurnOff,
    required this.onStopRecordingOnly,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
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
                      elapsedRecordingLabel,
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
                  onPressed: canStartRecording ? onStartRecording : null,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Start Recording'),
                ),
              ),
            if (!isRecording && !hasSensorsConnected)
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
                      onPressed:
                          isHandlingStopAction ? null : onStopAndTurnOff,
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
                      onPressed:
                          isHandlingStopAction ? null : onStopRecordingOnly,
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
}
