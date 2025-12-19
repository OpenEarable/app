import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:open_wearable/widgets/sensors/local_recorder/labels/label_sets_page.dart';
import 'package:open_wearable/widgets/sensors/local_recorder/labels/labelset_dropdown.dart';
import 'package:open_wearable/widgets/sensors/local_recorder/labels/labelset_editor_page.dart';
import 'package:provider/provider.dart';

import '../../../../view_models/label_set_provider.dart';


class LabelSetSelector extends StatelessWidget {
  const LabelSetSelector({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: LabelSetDropdown(),
            ),
            const SizedBox(width: 8),
            IconButton(
              tooltip: 'Create label set',
              icon: const Icon(Icons.add),
              onPressed: () {
                Navigator.push(context, platformPageRoute(context: context, builder: (context) => LabelSetEditorPage(),));
              },
            ),
            IconButton(
              tooltip: 'Manage label sets',
              icon: const Icon(Icons.edit),
              onPressed: () {
                Navigator.push(context, platformPageRoute(context: context, builder: (context) => LabelSetsPage()));
              },
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Pick a label set to enable in-recording labeling.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

@Preview(name: "LabelSetSelector")
Widget labelSetSelectorPreview() {
  return ChangeNotifierProvider<LabelSetProvider>(
    create: (_) => LabelSetProvider(),
    child: Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: LabelSetSelector(),
      ),
    ),
  );
}
