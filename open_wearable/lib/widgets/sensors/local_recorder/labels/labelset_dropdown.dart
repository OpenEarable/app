import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import 'package:provider/provider.dart';

import '../../../../models/labels/label.dart';
import '../../../../models/labels/label_set.dart';
import '../../../../view_models/label_set_provider.dart';

class LabelSetDropdown extends StatelessWidget {
  const LabelSetDropdown({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<LabelSetProvider>(
      builder: (context, provider, _) {
        final sets = provider.labelSets;

        return DropdownButtonFormField<LabelSet?>(
          initialValue: provider.selectedLabelSet,
          decoration: const InputDecoration(
            labelText: 'Label set',
            border: OutlineInputBorder(),
          ),
          items: [
            const DropdownMenuItem(
              value: null,
              child: Text('None'),
            ),
            ...sets.map(
              (set) => DropdownMenuItem(
                value: set,
                child: Text(set.name),
              ),
            ),
          ],
          onChanged: (value) async {
            provider.selectLabelSet(value);
          },
        );
      },
    );
  }
}

@Preview(name: 'LabelSetDropdown')
Widget labelSetDropdownPreview() {
  final labelSet1 = LabelSet(
    name: 'Activities',
    labels: [
      Label(name: 'Walking', color: Colors.green),
      Label(name: 'Running', color: Colors.red),
    ],
  );

  final labelSet2 = LabelSet(
    name: 'Postures',
    labels: [
      Label(name: 'Sitting', color: Colors.blue),
      Label(name: 'Standing', color: Colors.orange),
    ],
  );

  return ChangeNotifierProvider(
    create: (_) => LabelSetProvider()
      ..addOrUpdateSet(labelSet1)
      ..addOrUpdateSet(labelSet2),
    child: MaterialApp(
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: LabelSetDropdown(),
        ),
      ),
    ),
  );
}
