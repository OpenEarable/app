import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../models/log_file_manager.dart';
import '../../models/logger.dart';
import 'log_file_detail_screen.dart';

class LogFilesScreen extends StatelessWidget {
  const LogFilesScreen({super.key});

  Future<void> _shareFile(File file) async {
    logger.d("Sharing log file: ${file.path}");
    final xFile = XFile(file.path);
    await SharePlus.instance.share(
      ShareParams(
        files: [xFile],
      ),
    );
  }

  String _formatBytes(int bytes) {
    const kb = 1024;
    const mb = kb * 1024;
    if (bytes >= mb) {
      return '${(bytes / mb).toStringAsFixed(1)} MB';
    } else if (bytes >= kb) {
      return '${(bytes / kb).toStringAsFixed(1)} KB';
    } else {
      return '$bytes B';
    }
  }

  @override
  Widget build(BuildContext context) {
    return PlatformScaffold(
      appBar: PlatformAppBar(
        title: const Text('Log files'),
        trailingActions: <Widget>[
          PlatformIconButton(
            padding: EdgeInsets.zero,
            icon: Icon(context.platformIcons.delete),
            onPressed: () async {
              final manager = context.read<LogFileManager>();

              final files = await manager.logFiles;
              if (files.isEmpty) return;

              if (!context.mounted) return;

              final confirmed = await showPlatformDialog<bool>(
                context: context,
                builder: (ctx) => PlatformAlertDialog(
                  title: const Text('Clear all logs?'),
                  content: const Text(
                    'This will permanently delete all log files.',
                  ),
                  actions: [
                    PlatformDialogAction(
                      child: const Text('Cancel'),
                      onPressed: () => Navigator.of(ctx).pop(false),
                    ),
                    PlatformDialogAction(
                      cupertino: (_, __) =>
                          CupertinoDialogActionData(isDefaultAction: true),
                      material: (_, __) => MaterialDialogActionData(),
                      child: const Text('Delete'),
                      onPressed: () => Navigator.of(ctx).pop(true),
                    ),
                  ],
                ),
              );

              if (confirmed == true) {
                await manager.clearAllLogs();
              }
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Consumer<LogFileManager>(
          builder: (context, manager, _) {
            // Re-fetch files whenever LogFileManager notifies listeners.
            return FutureBuilder<List<File>>(
              future: manager.logFiles,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: PlatformCircularProgressIndicator(),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Failed to load logs: ${snapshot.error}',
                      textAlign: TextAlign.center,
                    ),
                  );
                }

                final files = snapshot.data ?? [];

                if (files.isEmpty) {
                  return const Center(
                    child: Text('No log files available.'),
                  );
                }

                return ListView.separated(
                  itemCount: files.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final file = files[index];
                    final stat = file.statSync();
                    final size = _formatBytes(stat.size);
                    final modified = stat.modified;

                    final subtitle =
                        '${modified.toLocal().toIso8601String()} • $size';

                    return PlatformListTile(
                      title: Text(file.path.split(Platform.pathSeparator).last),
                      subtitle: Text(subtitle),
                      leading: Icon(Icons.insert_drive_file),
                      trailing: PlatformIconButton(
                        padding: EdgeInsets.zero,
                        icon: Icon(Icons.more_vert),
                        onPressed: () => _showFileActionsSheet(
                          context,
                          file,
                          manager,
                          subtitle,
                        ),
                      ),
                      onTap: () => Navigator.of(context).push(
                        platformPageRoute(
                          context: context,
                          builder: (_) => LogFileDetailScreen(file: file),
                        ),
                      ),
                    );
                    // PlatformWidget(
                    //   material: (_, __) => ListTile(
                    //     leading: const Icon(Icons.insert_drive_file),
                    //     title: Text(file.path.split('/').last),
                    //     subtitle: Text(subtitle),
                    //     onTap: () => _shareFile(file),
                    //     trailing: IconButton(
                    //       icon: const Icon(Icons.more_vert),
                    //       onPressed: () => _showFileActionsSheet(
                    //         context,
                    //         file,
                    //         manager,
                    //         subtitle,
                    //       ),
                    //     ),
                    //   ),
                    //   cupertino: (_, __) => GestureDetector(
                    //     onTap: () => _shareFile(file),
                    //     child: Container(
                    //       padding: const EdgeInsets.symmetric(
                    //         horizontal: 16,
                    //         vertical: 12,
                    //       ),
                    //       child: Row(
                    //         children: [
                    //           const Icon(CupertinoIcons.doc_plaintext),
                    //           const SizedBox(width: 12),
                    //           Expanded(
                    //             child: Column(
                    //               crossAxisAlignment: CrossAxisAlignment.start,
                    //               children: [
                    //                 Text(
                    //                   file.path.split('/').last,
                    //                   style: const TextStyle(
                    //                     fontSize: 16,
                    //                     fontWeight: FontWeight.w500,
                    //                   ),
                    //                   overflow: TextOverflow.ellipsis,
                    //                 ),
                    //                 const SizedBox(height: 4),
                    //                 Text(
                    //                   subtitle,
                    //                   style: const TextStyle(
                    //                     fontSize: 12,
                    //                     color: CupertinoColors.systemGrey,
                    //                   ),
                    //                 ),
                    //               ],
                    //             ),
                    //           ),
                    //           PlatformIconButton(
                    //             padding: EdgeInsets.zero,
                    //             icon: Icon(context.platformIcons.ellipsis),
                    //             onPressed: () => _showFileActionsSheet(
                    //               context,
                    //               file,
                    //               manager,
                    //               subtitle,
                    //             ),
                    //           ),
                    //         ],
                    //       ),
                    //     ),
                    //   ),
                    // );
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }

  void _showFileActionsSheet(
    BuildContext context,
    File file,
    LogFileManager manager,
    String subtitle,
  ) {
    showPlatformModalSheet(
      context: context,
      builder: (ctx) => PlatformWidget(
        material: (_, __) => SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.ios_share),
                title: const Text('Share'),
                subtitle: Text(subtitle),
                onTap: () async {
                  Navigator.of(ctx).pop();
                  await _shareFile(file);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete),
                title: const Text('Delete'),
                onTap: () async {
                  Navigator.of(ctx).pop();
                  await manager.deleteLogFile(file);
                },
              ),
            ],
          ),
        ),
        cupertino: (_, __) => CupertinoActionSheet(
          title: Text(file.path.split('/').last),
          message: Text(subtitle),
          actions: [
            CupertinoActionSheetAction(
              onPressed: () async {
                Navigator.of(ctx).pop();
                await _shareFile(file);
              },
              child: const Text('Share'),
            ),
            CupertinoActionSheetAction(
              isDestructiveAction: true,
              onPressed: () async {
                Navigator.of(ctx).pop();
                await manager.deleteLogFile(file);
              },
              child: const Text('Delete'),
            ),
          ],
          cancelButton: CupertinoActionSheetAction(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
        ),
      ),
    );
  }
}
