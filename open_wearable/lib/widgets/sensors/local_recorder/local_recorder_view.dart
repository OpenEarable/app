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
        final isRecording = recorder.isRecording;
        final canRecord   = recorder.hasSensorsConnected || isRecording;
        final recordPath  = recorder.currentDirectory;

        final tileColor = isRecording ? Colors.green.shade300 : null;
        final icon      = isRecording ? Icons.stop : Icons.fiber_manual_record;
        final iconColor = isRecording
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

                    final dir = await _pickDirectory();
                    if (dir == null) return;

                    // --------  Check if directory is empty  --------
                    if (!await _isDirectoryEmpty(dir)) {
                      if (!context.mounted) return;
                      final proceed = await _askOverwriteConfirmation(
                        context,
                        dir,
                      );
                      if (!proceed) return;
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

/* ──────────────────────────────────────────────────────────── */
/*  Helpers                                                    */
/* ──────────────────────────────────────────────────────────── */

/// Native directory picker (with iOS workaround); `null` if cancelled.
Future<String?> _pickDirectory() async {
  if (!Platform.isIOS && !kIsWeb) {
    return await getDirectoryPath();
  }

  if (Platform.isIOS) {
    final result = await getSaveLocation(
      suggestedName: 'choose-this-folder.txt',
      confirmButtonText: 'Use this folder',
    );
    return result == null ? null : Directory(result.path).parent.path;
  }

  return null;
}

/// Returns `true` if `path` doesn’t exist *or* contains no files/folders.
Future<bool> _isDirectoryEmpty(String path) async {
  final dir = Directory(path);
  if (!await dir.exists()) return true;
  return await dir.list(followLinks: false).isEmpty;
}

/// Modal confirmation dialog shown when the folder isn’t empty.
Future<bool> _askOverwriteConfirmation(BuildContext context, String dirPath) async {
  return await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Directory not empty'),
      content: Text(
          '“$dirPath” already contains files or folders.\n\n'
          'New sensor files will be added; existing files with the same '
          'names will be overwritten. Continue anyway?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Continue'),
        ),
      ],
    ),
  ) ??
  false;
}
