import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:logger/logger.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:open_wearable/view_models/sensor_recorder_provider.dart';

Logger _logger = Logger();

class LocalRecorderView extends StatelessWidget {
  const LocalRecorderView({super.key});

  static const MethodChannel platform = MethodChannel('edu.teco.open_folder');

  Future<void> _openFolder(String path) async {
    try {
      await platform.invokeMethod('openFolder', {'path': "shareddocuments://$path"});
    } on PlatformException catch (e) {
      print("Failed to open folder: '${e.message}'.");
    }
  }

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
            ? Platform.isIOS
                ? 'Tap to start recording'
                : 'Tap to choose where to save your data'
            : 'Connect a device to enable recording';

        return ListView(
          padding: const EdgeInsets.all(10),
          children: [
            Card(
              color: tileColor,
              child: ListTile(
                enabled: canRecord,
                title: PlatformText('Local Recorder'),
                subtitle: PlatformText(subtitle),
                trailing: Icon(icon, color: iconColor),
                onTap: !canRecord
                  ? () {
                    _logger.w('Recording not available');
                  }
                  : () async {
                    if (isRecording) {
                      _logger.i('Stopping local recording');
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
            if (Platform.isIOS)
              // show a card that opens the iOS Files app in the recording directory
              Card(
                child: ListTile(
                  title: PlatformText('Show Recordings'),
                  trailing: const Icon(Icons.folder_open),
                  onTap: () async {
                    Directory recordDir = await getIOSDirectory();
                    // Open recordDir in the iOS Files app
                    _openFolder(recordDir.path);
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
    final recordingName = 'OpenWearable_Recording_${DateTime.now().toIso8601String()}';

    // create a directory in the appDocDir
    String dirPath = '${(await getIOSDirectory()).path}/$recordingName';
    Directory dir = Directory(dirPath);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    // return the path of the created directory
    return dirPath;
  }

  return null;
}

Future<Directory> getIOSDirectory() async {
  Directory appDocDir = await getApplicationDocumentsDirectory();
  final dirPath = '${appDocDir.path}/Recordings';
  final dir = Directory(dirPath);
    
  if (!await dir.exists()) {
    await dir.create(recursive: true);
  }
  
  return dir;
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
      title: PlatformText('Directory not empty'),
      content: PlatformText(
          '“$dirPath” already contains files or folders.\n\n'
          'New sensor files will be added; existing files with the same '
          'names will be overwritten. Continue anyway?'),
      actions: [
        PlatformTextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: PlatformText('Cancel'),
        ),
        PlatformTextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: PlatformText('Continue'),
        ),
      ],
    ),
  ) ??
  false;
}
