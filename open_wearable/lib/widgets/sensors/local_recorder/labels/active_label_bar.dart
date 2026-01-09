import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import 'package:provider/provider.dart';

import '../../../../models/labels/label.dart';
import '../../../../models/labels/label_set.dart';
import '../../../../view_models/label_provider.dart';

/// A bar displaying the active label and allowing selection.
class ActiveLabelBar extends StatelessWidget {
  const ActiveLabelBar({
    super.key, 
    required this.labelSet,
  });

  final LabelSet labelSet;

  @override
  Widget build(BuildContext context) {
    final labelProvider = context.watch<LabelProvider>();

    return LayoutBuilder(
      builder: (context, constraints) {
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: labelSet.labels.map((label) {
            final bool isActive = label == labelProvider.activeLabel;
            return ChoiceChip(
              label: Text(label.name),
              selected: isActive,
              selectedColor: label.color.withAlpha(77),
              onSelected: (_) =>
                  labelProvider.setActiveLabel(isActive ? null : label),
            );
          }).toList(),
        );
      },
    );
  }
}

@Preview(name: "ActiveLabelBar")
Widget activeLabelBarPreview() {
  final labelSet = LabelSet(
    name: 'Activity Labels',
    labels: [
      Label(name: 'Walking', color: Colors.green),
      Label(name: 'Running', color: Colors.red),
      Label(name: 'Sitting', color: Colors.blue),
      Label(name: 'Standing', color: Colors.orange),
      Label(name: 'Lying Down', color: Colors.purple),
      Label(name: 'Cycling', color: Colors.cyan),
      
    ],
  );

  return Scaffold(
    body: Center(
      child: ChangeNotifierProvider(
        create: (_) => LabelProvider(labelSet)..setActiveLabel(labelSet.labels[1]),
        child: ActiveLabelBar(labelSet: labelSet),
      ),
    ),
  );
}
