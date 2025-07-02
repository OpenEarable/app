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
                  onTap: isDirectory
                      ? () => _onDirectoryTapped(item.name)
                      : null,
                );
              },
            ),
    );
  }
}