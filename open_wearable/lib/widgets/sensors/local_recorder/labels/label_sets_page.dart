import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import 'package:provider/provider.dart';

import 'package:open_wearable/view_models/label_set_provider.dart';

import '../../../../models/labels/label.dart';
import '../../../../models/labels/label_set.dart';
import 'labelset_editor_page.dart';

/// A page that lists all label sets and allows managing them.
class LabelSetsPage extends StatelessWidget {
  const LabelSetsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<LabelSetProvider>();
    final sets = provider.labelSets;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Label Sets'),
        actions: [
          IconButton(
            tooltip: 'Create',
            icon: const Icon(Icons.add),
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const LabelSetEditorPage(),
                ),
              );
            },
          ),
        ],
      ),
      body: sets.isEmpty
          ? const Center(
              child: Text('No label sets yet. Tap + to create one.'),
            )
          : ListView.separated(
              itemCount: sets.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final set = sets[index];
                return ListTile(
                  title: Text(set.name),
                  subtitle: Text('${set.labels.length} labels'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Edit',
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  LabelSetEditorPage(initialSet: set),
                            ),
                          );
                        },
                      ),
                      IconButton(
                        tooltip: 'Delete',
                        icon: Icon(
                          Icons.delete_outline,
                          color: colorScheme.error,
                        ),
                        onPressed: () async {
                          final ok = await showDialog<bool>(
                                context: context,
                                builder: (_) => AlertDialog(
                                  title: const Text('Delete label set?'),
                                  content: Text(
                                    'Delete "${set.name}"? This cannot be undone.',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, false),
                                      child: const Text('Cancel'),
                                    ),
                                    TextButton(
                                      style: TextButton.styleFrom(
                                        foregroundColor: colorScheme.error,
                                      ),
                                      onPressed: () =>
                                          Navigator.pop(context, true),
                                      child: const Text('Delete'),
                                    ),
                                  ],
                                ),
                              ) ??
                              false;

                          if (!ok) return;
                          if (!context.mounted) return;
                          await context.read<LabelSetProvider>().deleteSet(set);
                        },
                      ),
                    ],
                  ),
                  onTap: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => LabelSetEditorPage(initialSet: set),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}

@Preview(name: 'LabelSetsPage')
Widget labelSetsPagePreview() {
  final provider = LabelSetProvider();
  provider.addOrUpdateSet(
    LabelSet(
      name: 'Activities',
      labels: [
        Label(name: 'Walking', color: Colors.green),
        Label(name: 'Running', color: Colors.red),
      ],
    ),
  );
  provider.addOrUpdateSet(
    LabelSet(
      name: 'Postures',
      labels: [
        Label(name: 'Sitting', color: Colors.blue),
        Label(name: 'Standing', color: Colors.orange),
      ],
    ),
  );
  return ChangeNotifierProvider<LabelSetProvider>.value(
    value: provider,
    child: const Scaffold(
      body: LabelSetsPage(),
    ),
  );
}
