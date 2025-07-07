import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart';

class FileExplorerPage extends StatefulWidget {
  final FileSystemManager fileSystemManager;
  final String rootDirectory;

  const FileExplorerPage({
    super.key,
    required this.fileSystemManager,
    this.rootDirectory = '/',
  });

  @override
  State<FileExplorerPage> createState() => _FileExplorerPageState();
}

class _FileExplorerPageState extends State<FileExplorerPage> {
  late String currentPath;
  late List<String> pathHistory;
  List<FileSystemItem> currentItems = [];
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    currentPath = widget.rootDirectory;
    pathHistory = [currentPath];
    _loadDirectory(currentPath);
  }

  Future<void> _loadDirectory(String path) async {
    setState(() {
      isLoading = true;
    });

    final items = await widget.fileSystemManager.listFiles(path);

    setState(() {
      currentItems = items;
      currentPath = path;
      isLoading = false;
    });
  }

  void _onDirectoryTapped(String name) {
    final newPath = '$currentPath/$name'.replaceAll('//', '/');
    pathHistory.add(newPath);
    _loadDirectory(newPath);
  }

  void _onBackPressed() {
    if (pathHistory.length > 1) {
      pathHistory.removeLast();
      _loadDirectory(pathHistory.last);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PlatformScaffold(
      appBar: PlatformAppBar(
        title: Text('File Explorer'),
        leading: pathHistory.length > 1
            ? PlatformIconButton(
                icon: Icon(context.platformIcons.back),
                onPressed: _onBackPressed,
              )
            : null,
        trailingActions: [
          PlatformIconButton(
            icon: Icon(context.platformIcons.add),
            onPressed: () async {
              try {
                final result = await FilePicker.platform.pickFiles();

                if (result == null || result.files.isEmpty) {
                  return; // user canceled
                }

                final PlatformFile platformFile = result.files.single;
                final filePath = platformFile.path;
                final fileName = platformFile.name;

                if (filePath == null) {
                  throw Exception("No path for selected file.");
                }

                final file = File(filePath);

                // Optional: show loading indicator or toast
                final stream = file.openRead(); // Stream<List<int>>
                await widget.fileSystemManager.writeFile(
                  path: '$currentPath/$fileName', // You can choose a different path if needed
                  data: stream,
                );

                //refresh the current directory
                _loadDirectory(currentPath);

                // Optional: show success dialog/snackbar
                showPlatformDialog(
                  context: context,
                  builder: (_) => PlatformAlertDialog(
                    title: Text('Upload Complete'),
                    content: Text('Successfully uploaded $fileName'),
                    actions: [
                      PlatformDialogAction(
                        child: PlatformText('OK'),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                );
              } catch (e, st) {
                debugPrint('Error picking/writing file: $e\n$st');
                showPlatformDialog(
                  context: context,
                  builder: (_) => PlatformAlertDialog(
                    title: Text('Error'),
                    content: Text('Failed to upload file: $e'),
                    actions: [
                      PlatformDialogAction(
                        child: PlatformText('OK'),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                );
              }
            },
          ),
        ],
      ),
      body: isLoading
          ? Center(child: PlatformCircularProgressIndicator())
          : ListView.builder(
              itemCount: currentItems.length,
              itemBuilder: (context, index) {
                final item = currentItems[index];

                final isDirectory = item is OWDirectory;
                return PlatformListTile(
                  title: Text(item.name),
                  leading: Icon(
                    isDirectory ? Icons.folder : Icons.insert_drive_file,
                    color: isDirectory ? Colors.amber : null,
                  ),
                  trailing: PlatformIconButton(
                    icon: Icon(context.platformIcons.delete),
                    onPressed: () async {
                      final confirmed = await showPlatformDialog(
                        context: context,
                        builder: (_) => PlatformAlertDialog(
                          title: Text('Delete ${item.name}?'),
                          content: Text('This action cannot be undone.'),
                          actions: [
                            PlatformDialogAction(
                              child: Text('Cancel'),
                              onPressed: () => Navigator.pop(context, false),
                            ),
                            PlatformDialogAction(
                              child: Text('Delete'),
                              onPressed: () => Navigator.pop(context, true),
                            ),
                          ],
                        ),
                      );
                      if (confirmed == true) {
                        await widget.fileSystemManager.remove('$currentPath/${item.name}');
                        _loadDirectory(currentPath);
                      }
                    },
                  ),
                  onTap: isDirectory
                    ? () => _onDirectoryTapped(item.name)
                    : null,
                );
              },
            ),
    );
  }
}