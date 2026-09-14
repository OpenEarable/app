import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:open_wearable/widgets/sensors/local_recorder/labels/label_groups_page.dart';
import 'package:open_wearable/widgets/sensors/local_recorder/labels/label_group_dropdown.dart';
import 'package:provider/provider.dart';

import '../../../../view_models/label_group_provider.dart';

class LabelGroupSelector extends StatelessWidget {
  const LabelGroupSelector({
    super.key,
    this.showHelperText = true,
  });

  final bool showHelperText;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: LabelGroupDropdown(),
            ),
            const SizedBox(width: 8),
            IconButton(
              tooltip: 'Manage label groups',
              icon: Icon(
                Icons.edit_outlined,
                color: colorScheme.primary,
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  platformPageRoute(
                    context: context,
                    builder: (context) => LabelGroupsPage(),
                  ),
                );
              },
            ),
          ],
        ),
        if (showHelperText) ...[
          const SizedBox(height: 6),
          Text(
            'Pick a label group to add labels while recording.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ],
    );
  }
}

@Preview(name: "LabelGroupSelector")
Widget labelGroupSelectorPreview() {
  return ChangeNotifierProvider<LabelGroupProvider>(
    create: (_) => LabelGroupProvider(),
    child: Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: LabelGroupSelector(),
      ),
    ),
  );
}
