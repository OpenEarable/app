import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../view_models/label_provider.dart';
import '../view_models/sensor_recorder_provider_facade.dart';

/// Shared pulse ticker so every recording indicator stays in sync.
class _RecordingPulseTicker {
  _RecordingPulseTicker._();

  static const int _periodMs = 900;
  static const Duration tick = Duration(milliseconds: 40);
  static Timer? _timer;
  static final StreamController<DateTime> _controller =
      StreamController<DateTime>.broadcast(
    onListen: _start,
    onCancel: _stop,
  );

  static Stream<DateTime> get stream => _controller.stream;

  static void _start() {
    _timer ??= Timer.periodic(tick, (_) {
      if (!_controller.isClosed) {
        _controller.add(DateTime.now());
      }
    });
  }

  static void _stop() {
    _timer?.cancel();
    _timer = null;
  }

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
    final activeLabelColor = context.select<LabelProvider, Color?>(
      (provider) => provider.activeLabel?.color,
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
          return _RecordingDotWithLabelBorder(
            size: size,
            borderColor: activeLabelColor,
            child: Opacity(
              opacity: opacity,
              child: icon,
            ),
          );
        },
      ),
    );
  }
}

class _RecordingDotWithLabelBorder extends StatelessWidget {
  const _RecordingDotWithLabelBorder({
    required this.size,
    required this.borderColor,
    required this.child,
  });

  final double size;
  final Color? borderColor;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final outerSize = size + 8;
    final borderWidth = (size * 0.12).clamp(1.5, 2.5).toDouble();
    final color = borderColor;

    return SizedBox.square(
      key: const ValueKey('recording-label-border'),
      dimension: outerSize,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: color == null
              ? null
              : Border.all(
                  color: color,
                  width: borderWidth,
                ),
        ),
        child: Center(child: child),
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
