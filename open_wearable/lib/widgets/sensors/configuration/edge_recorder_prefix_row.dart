import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart';

/// Row that shows the current file prefix of an [EdgeRecorderManager]
/// and lets the user change it.
class EdgeRecorderPrefixRow extends StatefulWidget {
  const EdgeRecorderPrefixRow({super.key, required this.manager});

  final EdgeRecorderManager manager;

  @override
  State<EdgeRecorderPrefixRow> createState() => _RecorderPrefixRowState();
}

class _RecorderPrefixRowState extends State<EdgeRecorderPrefixRow> {
  late Future<String> _prefixFuture;

  @override
  void initState() {
    super.initState();
    _loadPrefix();
  }

  void _loadPrefix() {
    _prefixFuture = widget.manager.filePrefix;
  }

  Future<void> _showEditDialog(String current) async {
    final controller = TextEditingController(text: current);
    final result = await showPlatformDialog<bool>(
      context: context,
      builder: (context) => PlatformAlertDialog(
        title: PlatformText('Set Recording Prefix'),
        content: PlatformTextField(
          controller: controller,
          autofocus: true,
          material: (_, __) => MaterialTextFieldData(
            decoration: const InputDecoration(hintText: 'Prefix'),
          ),
        ),
        actions: <Widget>[
          PlatformDialogAction(
            child: PlatformText('Cancel'),
            onPressed: () => Navigator.pop(context, false),
          ),
          PlatformDialogAction(
            child: PlatformText('Save'),
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );

    if (result == true) {
      await widget.manager.setFilePrefix(controller.text.trim());
      setState(_loadPrefix);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _prefixFuture,
      builder: (context, snapshot) {
        final isDone = snapshot.connectionState == ConnectionState.done;
        final prefix = snapshot.data ?? '';

        return PlatformListTile(
          title: PlatformText('On-Device Filename Prefix'),
          trailing: isDone
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    PlatformText(prefix),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => _showEditDialog(prefix),
                      child: Icon(
                        isCupertino(context)
                            ? CupertinoIcons.pencil
                            : Icons.edit,
                        size: 18,
                      ),
                    ),
                  ],
                )
              : const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
          onTap: isDone ? () => _showEditDialog(prefix) : null,
        );
      },
    );
  }
}
