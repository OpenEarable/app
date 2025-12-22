import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import 'package:provider/provider.dart';

import 'package:open_wearable/models/labels/label.dart';
import 'package:open_wearable/models/labels/label_set.dart';
import 'package:open_wearable/view_models/label_set_provider.dart';

/// A page for creating or editing a label set.
class LabelSetEditorPage extends StatefulWidget {
  const LabelSetEditorPage({
    super.key,
    this.initialSet,
  }): isCreate = initialSet == null;

  final LabelSet? initialSet;
  final bool isCreate;

  @override
  State<LabelSetEditorPage> createState() => _LabelSetEditorPageState();
}

class _LabelSetEditorPageState extends State<LabelSetEditorPage> {
  late final TextEditingController _nameController;
  final List<Label> _labels = [];

  @override
  void initState() {
    super.initState();
    _nameController =
        TextEditingController(text: widget.initialSet?.name ?? '');
    _labels.addAll(widget.initialSet?.labels ?? const []);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      _showError('Please enter a name for the label set.');
      return;
    }
    if (_labels.isEmpty) {
      _showError('Please add at least one label.');
      return;
    }

    final set = LabelSet(name: name, labels: _labels);
    await context.read<LabelSetProvider>().addOrUpdateSet(set);

    if (mounted) Navigator.of(context).pop();
  }

  void _showError(String msg) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Invalid'),
        content: Text(msg),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _addOrEditLabel({Label? existing, int? index}) async {
    final nameController = TextEditingController(text: existing?.name ?? '');
    Color selectedColor = existing?.color ?? Colors.blue;

    final result = await showDialog<_LabelDialogResult>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(existing == null ? 'Add label' : 'Edit label'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Label name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            _ColorPickerRow(
              selected: selectedColor,
              onChanged: (c) => selectedColor = c,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final n = nameController.text.trim();
              if (n.isEmpty) return;
              Navigator.pop(
                context,
                _LabelDialogResult(name: n, color: selectedColor),
              );
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result == null) return;

    setState(() {
      final updated = Label(name: result.name, color: result.color);
      if (existing == null) {
        _labels.add(updated);
      } else if (index != null) {
        _labels[index] = updated;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.isCreate ? 'Create label set' : 'Edit label set';

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            tooltip: 'Save',
            icon: const Icon(Icons.check),
            onPressed: _save,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Set name',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Labels',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('Add'),
                onPressed: _addOrEditLabel,
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_labels.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: Text('No labels yet. Tap “Add”.'),
            )
          else
            ..._labels.asMap().entries.map((entry) {
              final idx = entry.key;
              final label = entry.value;
              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: label.color,
                    child: const SizedBox.shrink(),
                  ),
                  title: Text(label.name),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Edit',
                        icon: const Icon(Icons.edit),
                        onPressed: () =>
                            _addOrEditLabel(existing: label, index: idx),
                      ),
                      IconButton(
                        tooltip: 'Delete',
                        icon: const Icon(Icons.delete),
                        onPressed: () {
                          setState(() => _labels.removeAt(idx));
                        },
                      ),
                    ],
                  ),
                ),
              );
            }),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            icon: const Icon(Icons.check),
            label: const Text('Save label set'),
            onPressed: _save,
          ),
        ],
      ),
    );
  }
}

class _LabelDialogResult {
  _LabelDialogResult({required this.name, required this.color});
  final String name;
  final Color color;
}

class _ColorPickerRow extends StatefulWidget {
  const _ColorPickerRow({
    required this.selected,
    required this.onChanged,
  });

  final Color selected;
  final ValueChanged<Color> onChanged;

  @override
  State<_ColorPickerRow> createState() => _ColorPickerRowState();
}

class _ColorPickerRowState extends State<_ColorPickerRow> {
  static const _colors = <Color>[
    Colors.red,
    Colors.pink,
    Colors.purple,
    Colors.deepPurple,
    Colors.indigo,
    Colors.blue,
    Colors.lightBlue,
    Colors.cyan,
    Colors.teal,
    Colors.green,
    Colors.lightGreen,
    Colors.lime,
    Colors.yellow,
    Colors.amber,
    Colors.orange,
    Colors.deepOrange,
    Colors.brown,
    Colors.grey,
    Colors.blueGrey,
    Colors.black,
  ];

  late Color _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.selected;
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _colors.map((c) {
        final isSelected = c.toARGB32() == _selected.toARGB32();
        return InkWell(
          onTap: () {
            setState(() => _selected = c);
            widget.onChanged(c);
          },
          child: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: c,
              shape: BoxShape.circle,
              border: Border.all(
                width: isSelected ? 3 : 1,
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Colors.black26,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

@Preview(name: 'LabelSetEditorPage')
Widget labelSetEditorPagePreview() {
  return const MaterialApp(
    home: LabelSetEditorPage(
      initialSet: LabelSet(
        name: 'Sample Set',
        labels: [
          Label(name: 'Walking', color: Colors.green),
          Label(name: 'Running', color: Colors.red),
        ],
      ),
    ),
  );
}
