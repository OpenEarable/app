import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import 'package:provider/provider.dart';

import '../../../../models/labels/label.dart';
import '../../../../models/labels/label_group.dart';
import '../../../../view_models/label_group_provider.dart';

class LabelGroupDropdown extends StatelessWidget {
  const LabelGroupDropdown({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<LabelGroupProvider>(
      builder: (context, provider, _) {
        final groups = provider.labelGroups;
        final selectedGroup = provider.selectedLabelGroup;

        return DropdownButtonFormField<LabelGroup?>(
          key: ValueKey(selectedGroup?.name ?? 'no-label-group'),
          initialValue: selectedGroup,
          decoration: const InputDecoration(
            hintText: 'Label group',
            border: OutlineInputBorder(),
          ),
          items: [
            const DropdownMenuItem(
              value: null,
              child: Text('No Labels'),
            ),
            ...groups.map(
              (group) => DropdownMenuItem(
                value: group,
                child: Text(group.name),
              ),
            ),
          ],
          onChanged: (value) async {
            provider.selectLabelGroup(value);
          },
        );
      },
    );
  }
}

@Preview(name: 'LabelGroupDropdown')
Widget labelGroupDropdownPreview() {
  final labelGroup1 = LabelGroup(
    name: 'Activities',
    labels: [
      Label(name: 'Walking', color: Colors.green),
      Label(name: 'Running', color: Colors.red),
    ],
  );

  final labelGroup2 = LabelGroup(
    name: 'Postures',
    labels: [
      Label(name: 'Sitting', color: Colors.blue),
      Label(name: 'Standing', color: Colors.orange),
    ],
  );

  return ChangeNotifierProvider(
    create: (_) => LabelGroupProvider()
      ..addOrUpdateGroup(labelGroup1)
      ..addOrUpdateGroup(labelGroup2),
    child: MaterialApp(
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: LabelGroupDropdown(),
        ),
      ),
    ),
  );
}
