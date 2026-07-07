import 'package:flutter/material.dart';

/// Shows the actual phone-side RespiBAN CSV size while a study phase records.
class RecordingFileSizeCard extends StatelessWidget {
  final int? sizeBytes;
  final int? deltaBytes;
  final bool isRecording;

  const RecordingFileSizeCard({
    super.key,
    required this.sizeBytes,
    required this.deltaBytes,
    required this.isRecording,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final delta = deltaBytes;
    final isStalled = isRecording && delta != null && delta <= 0;
    final color = isStalled
        ? theme.colorScheme.errorContainer
        : theme.colorScheme.surfaceContainerHighest;
    final onColor = isStalled
        ? theme.colorScheme.onErrorContainer
        : theme.colorScheme.onSurfaceVariant;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            isStalled ? Icons.warning_amber_rounded : Icons.sd_storage,
            color: onColor,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'RespiBAN CSV',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: onColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  _label(),
                  style: theme.textTheme.bodySmall?.copyWith(color: onColor),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _label() {
    final size = sizeBytes;
    if (size == null) {
      return isRecording ? 'Waiting for file…' : 'No file size available';
    }
    final delta = deltaBytes;
    final deltaLabel = delta == null ? '' : ' · ${_formatDelta(delta)}/s';
    return '${_formatBytes(size)}$deltaLabel';
  }

  static String _formatDelta(int bytes) {
    if (bytes <= 0) {
      return '+0 B';
    }
    return '+${_formatBytes(bytes)}';
  }

  static String _formatBytes(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    }
    final kib = bytes / 1024;
    if (kib < 1024) {
      return '${kib.toStringAsFixed(1)} KB';
    }
    final mib = kib / 1024;
    return '${mib.toStringAsFixed(2)} MB';
  }
}
