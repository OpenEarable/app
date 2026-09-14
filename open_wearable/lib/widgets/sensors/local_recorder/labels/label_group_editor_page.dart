import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import 'package:provider/provider.dart';

import 'package:open_wearable/models/labels/label.dart';
import 'package:open_wearable/models/labels/label_group.dart';
import 'package:open_wearable/view_models/label_group_provider.dart';

const _labelColors = <Color>[
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

/// A page for creating or editing a label group.
class LabelGroupEditorPage extends StatefulWidget {
  const LabelGroupEditorPage({
    super.key,
    this.initialGroup,
  }) : isCreate = initialGroup == null;

  final LabelGroup? initialGroup;
  final bool isCreate;

  @override
  State<LabelGroupEditorPage> createState() => _LabelGroupEditorPageState();
}

class _LabelGroupEditorPageState extends State<LabelGroupEditorPage> {
  late final TextEditingController _nameController;
  final List<Label> _labels = [];
  LabelGroup? _persistedGroup;
  Future<void> _persistQueue = Future<void>.value();
  late LabelGroupProvider _labelGroupProvider;
  late bool _isCreateMode;

  @override
  void initState() {
    super.initState();
    _isCreateMode = widget.isCreate;
    _persistedGroup = widget.initialGroup;
    _nameController =
        TextEditingController(text: widget.initialGroup?.name ?? '');
    _nameController.addListener(_handleNameChanged);
    _labels.addAll(widget.initialGroup?.labels ?? const []);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _labelGroupProvider = context.read<LabelGroupProvider>();
  }

  @override
  void dispose() {
    _nameController.removeListener(_handleNameChanged);
    _nameController.dispose();
    super.dispose();
  }

  void _handleNameChanged() {
    _persistCurrentGroup();
    setState(() {});
  }

  bool get _hasNewGroupWithoutLabels =>
      _isCreateMode &&
      _nameController.text.trim().isNotEmpty &&
      _labels.isEmpty;

  bool get _hasLabelsWithoutGroupName =>
      _nameController.text.trim().isEmpty && _labels.isNotEmpty;

  bool get _requiresLeaveConfirmation =>
      _hasNewGroupWithoutLabels || _hasLabelsWithoutGroupName;

  LabelGroup? _currentGroup() {
    final name = _nameController.text.trim();
    if (name.isEmpty || (_isCreateMode && _labels.isEmpty)) {
      return null;
    }

    return LabelGroup(
      name: name,
      labels: List<Label>.unmodifiable(_labels),
    );
  }

  Future<void> _persistCurrentGroup() {
    final group = _currentGroup();
    if (group == null) {
      if (_isCreateMode && _persistedGroup != null) {
        return _deletePersistedDraft();
      }
      return _persistQueue;
    }

    _persistQueue = _persistQueue.then((_) async {
      final previousGroup = _persistedGroup;
      if (previousGroup == null) {
        await _labelGroupProvider.addOrUpdateGroup(group);
      } else {
        await _labelGroupProvider.replaceGroup(previousGroup, group);
      }
      _persistedGroup = group;
    }).catchError((Object error, StackTrace stackTrace) {
      _reportAutosaveError(error, stackTrace);
      return null;
    });

    return _persistQueue;
  }

  Future<void> _deletePersistedDraft() {
    _persistQueue = _persistQueue.then((_) async {
      final previousGroup = _persistedGroup;
      if (previousGroup == null) return;

      await _labelGroupProvider.deleteGroup(previousGroup);
      _persistedGroup = null;
    }).catchError((Object error, StackTrace stackTrace) {
      _reportAutosaveError(error, stackTrace);
      return null;
    });

    return _persistQueue;
  }

  void _reportAutosaveError(Object error, StackTrace stackTrace) {
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stackTrace,
        library: 'label group editor',
        context: ErrorDescription('while autosaving a label group'),
      ),
    );
  }

  Future<void> _confirmCreateGroup() async {
    if (_currentGroup() == null) return;

    await _persistCurrentGroup();
    if (!mounted || _persistedGroup == null) return;

    setState(() {
      _isCreateMode = false;
    });
  }

  Future<void> _handlePopInvoked(bool didPop) async {
    if (didPop) return;

    final shouldLeave = await _confirmLeaveUnsavableGroup();
    if (!mounted || !shouldLeave) return;

    Navigator.of(context).pop();
  }

  Future<bool> _confirmLeaveUnsavableGroup() async {
    if (!_requiresLeaveConfirmation) {
      return true;
    }

    final title = _hasLabelsWithoutGroupName
        ? 'Leave without group name?'
        : 'Leave without labels?';
    final message = _hasLabelsWithoutGroupName
        ? 'This label group cannot be saved because no group name was given. Leave anyway?'
        : 'No labels have been added to this label group, so no group will be created. Leave anyway?';

    return await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Stay'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Leave'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _addOrEditLabel({Label? existing, int? index}) async {
    final unavailableColorValues = _labels
        .asMap()
        .entries
        .where((entry) => entry.key != index)
        .map((entry) => entry.value.color.toARGB32())
        .toSet();
    final result = await showDialog<_LabelDialogResult>(
      context: context,
      builder: (_) => _LabelDialog(
        existing: existing,
        unavailableColorValues: unavailableColorValues,
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
    _persistCurrentGroup();
  }

  Future<void> _confirmAndDeleteLabel({
    required Label label,
    required int index,
  }) async {
    final colorScheme = Theme.of(context).colorScheme;
    final shouldDelete = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Delete label?'),
            content: Text(
              'Delete "${label.name}" from this label group?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: colorScheme.error,
                ),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ??
        false;

    if (!mounted || !shouldDelete) return;
    if (index >= _labels.length || _labels[index] != label) return;

    setState(() => _labels.removeAt(index));
    _persistCurrentGroup();
  }

  @override
  Widget build(BuildContext context) {
    final title = _isCreateMode ? 'Create label group' : 'Edit label group';
    final canConfirmCreate = _isCreateMode && _currentGroup() != null;

    return PopScope(
      canPop: !_requiresLeaveConfirmation,
      onPopInvokedWithResult: (didPop, _) => _handlePopInvoked(didPop),
      child: Scaffold(
        appBar: AppBar(
          title: Text(title),
          actions: [
            if (_isCreateMode)
              IconButton(
                tooltip: 'Save',
                icon: const Icon(Icons.check),
                onPressed: canConfirmCreate ? _confirmCreateGroup : null,
              ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Group name',
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
                          icon: const Icon(Icons.edit_outlined),
                          onPressed: () =>
                              _addOrEditLabel(existing: label, index: idx),
                        ),
                        IconButton(
                          tooltip: 'Delete',
                          icon: Icon(
                            Icons.delete_outline,
                            color: Theme.of(context).colorScheme.error,
                          ),
                          onPressed: () => _confirmAndDeleteLabel(
                            label: label,
                            index: idx,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}

class _LabelDialogResult {
  _LabelDialogResult({required this.name, required this.color});
  final String name;
  final Color color;
}

class _LabelDialog extends StatefulWidget {
  const _LabelDialog({
    this.existing,
    this.unavailableColorValues = const <int>{},
  });

  final Label? existing;
  final Set<int> unavailableColorValues;

  @override
  State<_LabelDialog> createState() => _LabelDialogState();
}

class _LabelDialogState extends State<_LabelDialog> {
  late final TextEditingController _nameController;
  late Color? _selectedColor;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.existing?.name ?? '');
    _selectedColor = widget.existing?.color ?? _firstAvailableColor();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Color? _firstAvailableColor() {
    for (final color in _labelColors) {
      if (_isColorAvailable(color)) {
        return color;
      }
    }
    return null;
  }

  bool _isColorAvailable(Color? color) {
    if (color == null) return false;
    return !widget.unavailableColorValues.contains(color.toARGB32());
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? 'Add label' : 'Edit label'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Label name',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          _ColorPickerRow(
            selected: _selectedColor,
            unavailableColorValues: widget.unavailableColorValues,
            onChanged: (color) => setState(() => _selectedColor = color),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, null),
          child: const Text('Cancel'),
        ),
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: _nameController,
          builder: (context, value, _) {
            final selectedColor = _selectedColor;
            final canSave = value.text.trim().isNotEmpty &&
                _isColorAvailable(selectedColor);
            return TextButton(
              onPressed: canSave
                  ? () {
                      final color = selectedColor;
                      if (color == null) return;
                      Navigator.pop(
                        context,
                        _LabelDialogResult(
                          name: value.text.trim(),
                          color: color,
                        ),
                      );
                    }
                  : null,
              child: const Text('Save'),
            );
          },
        ),
      ],
    );
  }
}

class _ColorPickerRow extends StatefulWidget {
  const _ColorPickerRow({
    required this.selected,
    required this.unavailableColorValues,
    required this.onChanged,
  });

  final Color? selected;
  final Set<int> unavailableColorValues;
  final ValueChanged<Color> onChanged;

  @override
  State<_ColorPickerRow> createState() => _ColorPickerRowState();
}

class _ColorPickerRowState extends State<_ColorPickerRow> {
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _labelColors.map((c) {
        final colorValue = c.toARGB32();
        final isUnavailable =
            widget.unavailableColorValues.contains(colorValue);
        final isSelected =
            !isUnavailable && widget.selected?.toARGB32() == colorValue;
        final checkColor =
            c.computeLuminance() > 0.5 ? Colors.black : Colors.white;

        return Tooltip(
          message: isUnavailable
              ? 'Already used in this label group'
              : 'Select color',
          child: Material(
            key: ValueKey('label-color-$colorValue'),
            color: Colors.transparent,
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: isUnavailable ? null : () => widget.onChanged(c),
              child: SizedBox(
                width: 32,
                height: 32,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Opacity(
                      opacity: isUnavailable ? 0.32 : 1,
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: c,
                          shape: BoxShape.circle,
                          border: Border.all(
                            width: isSelected ? 3 : 1,
                            color: isSelected
                                ? colorScheme.primary
                                : colorScheme.outlineVariant,
                          ),
                        ),
                      ),
                    ),
                    if (isUnavailable)
                      Icon(
                        Icons.block_rounded,
                        size: 18,
                        color: colorScheme.onSurfaceVariant,
                      )
                    else if (isSelected)
                      Icon(
                        Icons.check_rounded,
                        size: 18,
                        color: checkColor,
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

@Preview(name: 'LabelGroupEditorPage')
Widget labelGroupEditorPagePreview() {
  return const MaterialApp(
    home: LabelGroupEditorPage(
      initialGroup: LabelGroup(
        name: 'Sample Group',
        labels: [
          Label(name: 'Walking', color: Colors.green),
          Label(name: 'Running', color: Colors.red),
        ],
      ),
    ),
  );
}
