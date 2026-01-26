import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:provider/provider.dart';
import '../../../view_models/sensor_recorder_provider.dart';

/// Widget to control BLE microphone streaming
class BLEMicrophoneStreamingRow extends StatelessWidget {
  const BLEMicrophoneStreamingRow({super.key});

  @override
  Widget build(BuildContext context) {
    if (!Platform.isAndroid) {
      return const SizedBox.shrink();
    }

    return Consumer<SensorRecorderProvider>(
      builder: (context, recorderProvider, child) {
        final isStreamingEnabled = recorderProvider.isBLEMicrophoneStreamingEnabled;

        return PlatformListTile(
          title: PlatformText('BLE Microphone Streaming'),
          subtitle: PlatformText(
            isStreamingEnabled
                ? 'Microphone stream is active'
                : 'Enable to start microphone streaming',
          ),
          trailing: PlatformSwitch(
            value: isStreamingEnabled,
            onChanged: (value) async {
              if (value) {
                final success = await recorderProvider.startBLEMicrophoneStream();
                if (!success && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: PlatformText(
                        'Failed to start BLE microphone streaming. '
                        'Make sure a BLE headset is connected and microphone permission is granted.',
                      ),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              } else {
                await recorderProvider.stopBLEMicrophoneStream();
              }
            },
          ),
        );
      },
    );
  }
}
