import 'package:flutter/material.dart';
import 'package:open_wearable/widgets/recording_activity_indicator.dart';

class LocalRecorderRecordingCard extends StatelessWidget {
  final bool isRecording;
  final bool hasSensorsConnected;
  final bool canStartRecording;
  final bool isHandlingStopAction;
  final bool turnOffSensorsWhenStopping;
  final String elapsedRecordingLabel;
  final VoidCallback? onStartRecording;
  final ValueChanged<bool>? onTurnOffSensorsWhenStoppingChanged;
  final VoidCallback? onStopRecording;
  final Widget? labelControls;

  const LocalRecorderRecordingCard({
    super.key,
    required this.isRecording,
    required this.hasSensorsConnected,
    required this.canStartRecording,
    required this.isHandlingStopAction,
    this.turnOffSensorsWhenStopping = false,
    required this.elapsedRecordingLabel,
    required this.onStartRecording,
    this.onTurnOffSensorsWhenStoppingChanged,
    required this.onStopRecording,
    this.labelControls,
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
            : 'No sensors connected';
    final statusSubtitle = isRecording
        ? 'Capturing live Bluetooth sensor data.'
        : hasSensorsConnected
            ? 'Start a session to capture live Bluetooth sensor data.'
            : 'Connect a wearable with sensors to start recording.';

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _RecorderHeader(
              isRecording: isRecording,
              icon: statusIcon,
              color: statusColor,
              title: statusTitle,
              subtitle: statusSubtitle,
            ),
            const SizedBox(height: 16),
            _RecorderActionArea(
              isRecording: isRecording,
              hasSensorsConnected: hasSensorsConnected,
              canStartRecording: canStartRecording,
              isHandlingStopAction: isHandlingStopAction,
              turnOffSensorsWhenStopping: turnOffSensorsWhenStopping,
              elapsedRecordingLabel: elapsedRecordingLabel,
              onStartRecording: onStartRecording,
              onTurnOffSensorsWhenStoppingChanged:
                  onTurnOffSensorsWhenStoppingChanged,
              onStopRecording: onStopRecording,
            ),
            if (labelControls != null) ...[
              const SizedBox(height: 16),
              Divider(
                height: 1,
                color: colorScheme.outlineVariant,
              ),
              const SizedBox(height: 14),
              labelControls!,
            ],
          ],
        ),
      ),
    );
  }
}

class _RecorderHeader extends StatelessWidget {
  const _RecorderHeader({
    required this.isRecording,
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
  });

  final bool isRecording;
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(10),
          ),
          child: isRecording
              ? const Center(
                  child: RecordingActivityIndicator(
                    size: 20,
                    showIdleOutline: false,
                    padding: EdgeInsets.zero,
                  ),
                )
              : Icon(icon, color: color, size: 20),
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
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RecorderActionArea extends StatelessWidget {
  const _RecorderActionArea({
    required this.isRecording,
    required this.hasSensorsConnected,
    required this.canStartRecording,
    required this.isHandlingStopAction,
    required this.turnOffSensorsWhenStopping,
    required this.elapsedRecordingLabel,
    required this.onStartRecording,
    required this.onTurnOffSensorsWhenStoppingChanged,
    required this.onStopRecording,
  });

  final bool isRecording;
  final bool hasSensorsConnected;
  final bool canStartRecording;
  final bool isHandlingStopAction;
  final bool turnOffSensorsWhenStopping;
  final String elapsedRecordingLabel;
  final VoidCallback? onStartRecording;
  final ValueChanged<bool>? onTurnOffSensorsWhenStoppingChanged;
  final VoidCallback? onStopRecording;

  @override
  Widget build(BuildContext context) {
    if (!isRecording) {
      return _IdleRecorderActions(
        hasSensorsConnected: hasSensorsConnected,
        canStartRecording: canStartRecording,
        onStartRecording: onStartRecording,
      );
    }

    return _RecordingRecorderActions(
      elapsedRecordingLabel: elapsedRecordingLabel,
      isHandlingStopAction: isHandlingStopAction,
      turnOffSensorsWhenStopping: turnOffSensorsWhenStopping,
      onTurnOffSensorsWhenStoppingChanged: onTurnOffSensorsWhenStoppingChanged,
      onStopRecording: onStopRecording,
    );
  }
}

class _IdleRecorderActions extends StatelessWidget {
  const _IdleRecorderActions({
    required this.hasSensorsConnected,
    required this.canStartRecording,
    required this.onStartRecording,
  });

  final bool hasSensorsConnected;
  final bool canStartRecording;
  final VoidCallback? onStartRecording;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: canStartRecording ? onStartRecording : null,
            icon: const Icon(Icons.play_arrow),
            label: const Text('Start Recording'),
          ),
        ),
        if (!hasSensorsConnected)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'No connected sensors detected yet.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
      ],
    );
  }
}

class _RecordingRecorderActions extends StatelessWidget {
  const _RecordingRecorderActions({
    required this.elapsedRecordingLabel,
    required this.isHandlingStopAction,
    required this.turnOffSensorsWhenStopping,
    required this.onTurnOffSensorsWhenStoppingChanged,
    required this.onStopRecording,
  });

  final String elapsedRecordingLabel;
  final bool isHandlingStopAction;
  final bool turnOffSensorsWhenStopping;
  final ValueChanged<bool>? onTurnOffSensorsWhenStoppingChanged;
  final VoidCallback? onStopRecording;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Elapsed Time',
          style: theme.textTheme.labelMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          elapsedRecordingLabel,
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 14),
        _StopSensorsOption(
          value: turnOffSensorsWhenStopping,
          onChanged:
              isHandlingStopAction ? null : onTurnOffSensorsWhenStoppingChanged,
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: colorScheme.error,
              foregroundColor: colorScheme.onError,
            ),
            onPressed: isHandlingStopAction ? null : onStopRecording,
            icon: const Icon(Icons.stop),
            label: const Text('Stop Recording'),
          ),
        ),
      ],
    );
  }
}

class _StopSensorsOption extends StatelessWidget {
  const _StopSensorsOption({
    required this.value,
    required this.onChanged,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onChanged == null ? null : () => onChanged!(!value),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
        child: Row(
          children: [
            Checkbox(
              value: value,
              onChanged: onChanged == null
                  ? null
                  : (checked) => onChanged!(checked ?? false),
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Turn off sensors after stopping',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
