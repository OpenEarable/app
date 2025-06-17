import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:open_wearable/view_models/sensor_recorder_provider.dart';

class LocalRecorderView extends StatelessWidget {
  const LocalRecorderView({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<SensorRecorderProvider>(
      builder: (context, recorder, _) {
        final isRecording   = recorder.isRecording;
        final canRecord     = recorder.hasSensorsConnected || isRecording;
        final recordPath    = recorder.currentDirectory;

        // Dynamic UI bits
        final tileColor     = isRecording ? Colors.green.shade300 : null;
        final icon          = isRecording ? Icons.stop : Icons.fiber_manual_record;
        final iconColor     = isRecording
            ? Colors.white
            : (recorder.hasSensorsConnected ? Colors.red : Colors.grey);

        final subtitle = isRecording
            ? 'Recording to:\n$recordPath'
            : recorder.hasSensorsConnected
                ? 'Tap to choose where to save your data'
                : 'Connect a device to enable recording';

        return ListView(
          padding: const EdgeInsets.all(10),
          children: [
            Card(
              color: tileColor,
              child: ListTile(
                enabled: canRecord,
                title: const Text('Local Recorder'),
                subtitle: Text(subtitle),
                trailing: Icon(icon, color: iconColor),
                onTap: !canRecord
                    ? null
                    : () async {
                        if (isRecording) {
                          recorder.stopRecording();
                          return;
                        }

                        // --- Pick a target directory ---
                        final dir = await _pickDirectory();
                        if (dir == null) {
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('No directory selected'),
                            ),
                          );
                          return;
                        }

                        recorder.startRecording(dir);
                      },
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Lets the user pick a folder cross-platform.  Returns `null` if cancelled.
///
/// Android / macOS / Windows / Linux → native directory dialog via file_selector  
/// iOS → use a “Save as…” trick and strip the filename (file_selector's current
///       limitation)  
/// Web is not supported because browsers can’t grant write access to a folder.
Future<String?> _pickDirectory() async {
  // 1. Platforms where file_selector already supports folder selection
  if (!Platform.isIOS && !kIsWeb) {
    return await getDirectoryPath();
  }

  // 2. iOS workaround: ask the user to “save” a throw-away file,
  //    then use its parent directory.
  if (Platform.isIOS) {
    final result = await getSaveLocation(
      suggestedName: 'choose-this-folder.txt',
      confirmButtonText: 'Use this folder',
    );
    return result == null ? null : Directory(result.path).parent.path;
  }

  // 3. Anything else (e.g., web): gracefully bail
  return null;
}
