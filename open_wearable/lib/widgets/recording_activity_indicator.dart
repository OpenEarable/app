import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../view_models/sensor_recorder_provider.dart';

/// Shared pulse ticker so every recording indicator stays in sync.
class _RecordingPulseTicker {
  _RecordingPulseTicker._();

  static const int _periodMs = 900;
  static const Duration tick = Duration(milliseconds: 40);
  static final Stream<DateTime> stream =
      Stream<DateTime>.periodic(tick, (_) => DateTime.now())
          .asBroadcastStream();

  static double opacityAt(DateTime now, DateTime origin) {
    final elapsedMs = now.difference(origin).inMilliseconds;
    final normalized = (elapsedMs % _periodMs) / _periodMs;
    final wave = 0.5 - 0.5 * math.cos(2 * math.pi * normalized);
    return 0.35 + (0.65 * wave);
  }
}

/// Animated status dot that pulses while sensor recording is active.
class RecordingActivityIndicator extends StatelessWidget {
  const RecordingActivityIndicator({
    super.key,
    this.size = 16,
    this.showIdleOutline = true,
    this.padding = const EdgeInsets.symmetric(horizontal: 2),
  });

  final double size;
  final bool showIdleOutline;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final isRecording = context.select<SensorRecorderProvider, bool>(
      (provider) => provider.isRecording,
    );
    final recordingStart = context.select<SensorRecorderProvider, DateTime?>(
      (provider) => provider.recordingStart,
    );

    final colorScheme = Theme.of(context).colorScheme;
    final color = isRecording
        ? colorScheme.error
        : colorScheme.onSurfaceVariant.withValues(alpha: 0.85);
    final iconData = isRecording || !showIdleOutline
        ? Icons.fiber_manual_record
        : Icons.fiber_manual_record_outlined;
    final icon = Icon(
      iconData,
      size: size,
      color: color,
    );

    if (!isRecording) {
      return Padding(
        padding: padding,
        child: icon,
      );
    }

    final anchor = recordingStart ?? DateTime.now();
    return Padding(
      padding: padding,
      child: StreamBuilder<DateTime>(
        stream: _RecordingPulseTicker.stream,
        initialData: DateTime.now(),
        builder: (context, snapshot) {
          final now = snapshot.data ?? DateTime.now();
          final opacity = _RecordingPulseTicker.opacityAt(now, anchor);
          return Opacity(
            opacity: opacity,
            child: icon,
          );
        },
      ),
    );
  }
}

class AppBarRecordingIndicator extends StatelessWidget {
  const AppBarRecordingIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    final isRecording = context.select<SensorRecorderProvider, bool>(
      (provider) => provider.isRecording,
    );
    if (!isRecording) {
      return const SizedBox.shrink();
    }

    return const RecordingActivityIndicator(
      size: 16,
      showIdleOutline: false,
      padding: EdgeInsets.only(right: 6),
    );
  }
}
