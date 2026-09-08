import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import 'package:provider/provider.dart';

import '../../../../models/labels/label.dart';
import '../../../../models/labels/label_group.dart';
import '../../../../view_models/label_provider.dart';

/// A bar displaying the active label and allowing selection.
class ActiveLabelBar extends StatelessWidget {
  const ActiveLabelBar({
    super.key,
    required this.labelGroup,
    required this.selectionEnabled,
    this.showNoLabelOption = false,
  });

  final LabelGroup labelGroup;
  final bool selectionEnabled;
  final bool showNoLabelOption;

  @override
  Widget build(BuildContext context) {
    final labelProvider = context.watch<LabelProvider>();

    return LayoutBuilder(
      builder: (context, constraints) {
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (showNoLabelOption)
              _LabelChip(
                name: 'No Label',
                color: null,
                selected: selectionEnabled && labelProvider.activeLabel == null,
                enabled: selectionEnabled,
                onTap: () => labelProvider.setActiveLabel(null),
              ),
            ...labelGroup.labels.map((label) {
              final bool isActive = label == labelProvider.activeLabel;
              return _LabelChip(
                name: label.name,
                color: label.color,
                selected: selectionEnabled && isActive,
                enabled: selectionEnabled,
                onTap: () => labelProvider.setActiveLabel(
                  isActive ? null : label,
                ),
              );
            }),
          ],
        );
      },
    );
  }
}

class _LabelChip extends StatelessWidget {
  const _LabelChip({
    required this.name,
    required this.color,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final String name;
  final Color? color;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final labelColor = color;
    final contrastColor = labelColor == null
        ? colorScheme.onSecondaryContainer
        : labelColor.computeLuminance() > 0.5
            ? Colors.black
            : Colors.white;
    final backgroundColor = selected
        ? labelColor ?? colorScheme.secondaryContainer
        : labelColor?.withValues(alpha: 0.14) ??
            colorScheme.surfaceContainerHighest;
    final foregroundColor = selected ? contrastColor : colorScheme.onSurface;
    final borderColor = selected
        ? labelColor ?? colorScheme.secondary
        : labelColor?.withValues(alpha: 0.72) ?? colorScheme.outlineVariant;

    return Material(
      color: Colors.transparent,
      shape: const StadiumBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: enabled ? onTap : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: ShapeDecoration(
            color: backgroundColor,
            shape: StadiumBorder(
              side: BorderSide(color: borderColor),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 18,
                height: 18,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 140),
                  child: selected
                      ? Icon(
                          key: const ValueKey('selected'),
                          Icons.check_rounded,
                          size: 17,
                          color: contrastColor,
                        )
                      : Center(
                          key: const ValueKey('idle'),
                          child: Container(
                            width: 9,
                            height: 9,
                            decoration: BoxDecoration(
                              color: labelColor ??
                                  colorScheme.onSurfaceVariant
                                      .withValues(alpha: 0.72),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color:
                                    colorScheme.surface.withValues(alpha: 0.8),
                              ),
                            ),
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 4),
              Text(
                name,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: foregroundColor,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

@Preview(name: "ActiveLabelBar")
Widget activeLabelBarPreview() {
  final labelGroup = LabelGroup(
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
        create: (_) =>
            LabelProvider(labelGroup)..setActiveLabel(labelGroup.labels[1]),
        child: ActiveLabelBar(
          labelGroup: labelGroup,
          selectionEnabled: true,
        ),
      ),
    ),
  );
}
