import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart';
import 'package:provider/provider.dart';

import '../models/connector_settings.dart';
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

class UdpActivityIndicator extends StatelessWidget {
  const UdpActivityIndicator({
    super.key,
    this.padding = const EdgeInsets.symmetric(horizontal: 2),
  });

  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<UdpBridgeConnectorSettings>(
      valueListenable: ConnectorSettings.udpBridgeSettingsListenable,
      builder: (context, settings, _) {
        final isActive = settings.enabled && settings.isConfigured;
        if (!isActive) {
          return const SizedBox.shrink();
        }
        return ValueListenableBuilder<SensorForwarderConnectionState>(
          valueListenable: ConnectorSettings.udpBridgeConnectionStateListenable,
          builder: (context, connectionState, _) {
            const udpGreen = Color(0xFF2E7D32);
            final isUnreachable =
                connectionState == SensorForwarderConnectionState.unreachable;
            final colorScheme = Theme.of(context).colorScheme;
            final foreground = isUnreachable ? colorScheme.error : udpGreen;
            final background = foreground.withValues(
              alpha: isUnreachable ? 0.13 : 0.16,
            );
            final border = foreground.withValues(
              alpha: isUnreachable ? 0.4 : 0.32,
            );

            return Padding(
              padding: padding,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(999),
                  onTap: () => context.push('/connectors'),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      color: background,
                      border: Border.all(color: border),
                    ),
                    child: Icon(
                      isUnreachable
                          ? Icons.warning_amber_rounded
                          : Icons.share_rounded,
                      size: 12,
                      color: foreground,
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
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
    return ValueListenableBuilder<UdpBridgeConnectorSettings>(
      valueListenable: ConnectorSettings.udpBridgeSettingsListenable,
      builder: (context, settings, _) {
        final isUdpActive = settings.enabled && settings.isConfigured;
        if (!isRecording && !isUdpActive) {
          return const SizedBox.shrink();
        }

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isRecording)
              const RecordingActivityIndicator(
                size: 16,
                showIdleOutline: false,
                padding: EdgeInsets.only(right: 2),
              ),
            if (isUdpActive)
              const UdpActivityIndicator(
                padding: EdgeInsets.only(left: 2, right: 6),
              ),
          ],
        );
      },
    );
  }
}
