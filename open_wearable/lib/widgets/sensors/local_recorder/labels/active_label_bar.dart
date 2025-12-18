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

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Active label',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
              Text(
                labelSet.name,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: labelSet.labels.map((label) {
                final bool isActive = label == labelProvider.activeLabel;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(label.name),
                    selected: isActive,
                    selectedColor: label.color.withValues(alpha: 0.30),
                    onSelected: (_) => labelProvider.setActiveLabel(label),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
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
